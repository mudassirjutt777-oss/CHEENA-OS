#!/usr/bin/env bash
# CHEENA OS Phase 1b: boot-chain and rollback proof of concept (ADR-003 / ADR-004, risk R-03).
#
# Builds a minimal Ubuntu 26.04 system directly into a DISPOSABLE DISK IMAGE with
# the proposed layout (ESP, unencrypted /boot, LUKS2 Argon2id -> Btrfs subvolumes),
# boots it in QEMU/OVMF through shim and the signed GRUB, then performs a real
# kernel update and a snapshot rollback to see what happens to the boot.
#
# It never touches a real disk: the only block devices it writes are loop
# partitions of an image file it created under $WORK. There is no installer and
# no desktop here. Secure Boot enforcement is not tested (OVMF runs without keys).
#
# Must run as root on a throwaway CI VM.
set -u

WORK="${WORK:-/tmp/cheena-boot-poc}"
IMG="$WORK/disk.img"
MNT="$WORK/root"
TOP="$WORK/top"
MAP="cheena-vault"          # same name as in the guest's crypttab, so the initramfs hook resolves it
LOG="$WORK/poc.log"
SUITE="resolute"
MIRROR="http://archive.ubuntu.com/ubuntu"
HERE="$(cd "$(dirname "$0")" && pwd)"
PBKDF_OPTS=(--pbkdf argon2id --pbkdf-memory 262144 --pbkdf-force-iterations 4 --pbkdf-parallel 2)

if [ "$(id -u)" -ne 0 ]; then echo "must run as root" >&2; exit 2; fi
mkdir -p "$WORK" "$MNT" "$TOP"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

rnd() { od -An -tx1 -N"$1" /dev/urandom | tr -d ' \n'; }
PASS="cheenaPASS-$(rnd 12)"
WRONG="cheenaWRONG-$(rnd 12)"
HOME_TOKEN="home-$(rnd 8)"
( umask 077; printf '%s' "$PASS" > "$WORK/pass"; printf '%s' "$WRONG" > "$WORK/wrong" )

P1=""; P2=""; P3=""
RESULTS=()
FAILS=0
ABORT=""
record() { RESULTS+=("$1|$2|$3|$4"); echo "== $1 $2: $3 ${4:+($4)}"; [ "$2" = FAIL ] && FAILS=$((FAILS+1)); return 0; }
log()  { echo; echo "### $*"; }
try()  { local what="$1"; shift; echo "+ $what"; if "$@"; then return 0; fi; ABORT="$what"; echo "!! failed: $what"; return 1; }

in_chroot() { chroot "$MNT" /usr/bin/env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin HOME=/root LC_ALL=C.UTF-8 DEBIAN_FRONTEND=noninteractive "$@"; }

# Each partition gets its own loop device (offset + size limit). This avoids
# relying on kernel partition scanning of loop devices, which was not available
# on the CI runner.
# Fixed layout of the 10 GiB image, in 512-byte sectors: start and size per partition.
PART_START=(0 2048 1050624 3147776)
PART_SIZE=(0 1048576 2097152 17821696)
part_loop() {
  local n="$1"
  losetup --find --show --offset $((PART_START[n]*512)) --sizelimit $((PART_SIZE[n]*512)) "$IMG"
}
img_open() {
  P1="$(part_loop 1)" && P2="$(part_loop 2)" && P3="$(part_loop 3)" || { echo "attach failed: P1=$P1 P2=$P2 P3=$P3"; return 1; }
  local d; for d in "$P1" "$P2" "$P3"; do case "$d" in /dev/loop*) ;; *) echo "refusing: '$d' is not a loop device"; return 1;; esac; done
  if cryptsetup isLuks "$P3" 2>/dev/null; then printf '%s' "$PASS" | cryptsetup open --type luks2 --key-file - "$P3" "$MAP" || return 1; fi
  return 0
}
img_close() {
  local i d
  mountpoint -q "$TOP" && umount "$TOP"
  if mountpoint -q "$MNT"; then umount -R "$MNT" 2>/dev/null || { sleep 2; umount -R "$MNT" 2>/dev/null || umount -Rl "$MNT"; }; fi
  for i in 1 2 3 4 5 6; do [ -e "/dev/mapper/$MAP" ] || break; cryptsetup close "$MAP" 2>/dev/null && break; sleep 2; done
  [ -e "/dev/mapper/$MAP" ] && { echo "could not close $MAP"; return 1; }
  for d in "$P1" "$P2" "$P3"; do [ -n "$d" ] && losetup -d "$d" 2>/dev/null; done
  P1=""; P2=""; P3=""
  sync; return 0
}
trap 'img_close >/dev/null 2>&1' EXIT

tree_mount() {
  mount -o subvol=@ "/dev/mapper/$MAP" "$MNT" || return 1
  mkdir -p "$MNT/home" "$MNT/boot"
  mount -o subvol=@home "/dev/mapper/$MAP" "$MNT/home" || return 1
  mount "$P2" "$MNT/boot" || return 1
  mkdir -p "$MNT/boot/efi"; mount "$P1" "$MNT/boot/efi" || return 1
}
bind_mounts() {
  mkdir -p "$MNT/dev" "$MNT/proc" "$MNT/sys"
  mount --bind /dev "$MNT/dev" && mount --bind /dev/pts "$MNT/dev/pts" && mount -t proc proc "$MNT/proc" && mount -t sysfs sysfs "$MNT/sys"
}

kernels() { ls -1 "$MNT"/boot/vmlinuz-* 2>/dev/null | sed 's#.*/vmlinuz-##' | LC_ALL=C sort -V; }

# write_grub_cfg <default kernel> [other kernels...]  -> first argument boots by default
write_grub_cfg() {
  local boot_uuid k; boot_uuid="$(blkid -p -s UUID -o value "$P2")"
  {
    echo 'serial --unit=0 --speed=115200'
    echo 'terminal_input serial console'
    echo 'terminal_output serial console'
    echo 'set timeout=1'
    echo 'set default=0'
    echo "search --no-floppy --fs-uuid --set=root $boot_uuid"
    for k in "$@"; do
      echo "menuentry \"CHEENA PoC $k\" {"
      echo "    linux /vmlinuz-$k root=/dev/mapper/$MAP rootflags=subvol=@ ro console=ttyS0,115200n8"
      echo "    initrd /initrd.img-$k"
      echo "}"
    done
  } > "$MNT/boot/grub/grub.cfg"
  echo "grub.cfg default: $1 (entries: $*)"
}

# boot <name> <timeout> [wrong-first]  -> sets BOOT_LINE
boot() {
  local name="$1" t="$2" extra=()
  [ "${3:-}" = wrong-first ] && extra=(--wrongfile "$WORK/wrong")
  img_close || { BOOT_LINE="RESULT status=host-close-failed"; return 1; }
  BOOT_LINE="$(python3 "$HERE/vm.py" --disk "$IMG" --vars "$WORK/vars.fd" --passfile "$WORK/pass" \
      --log "$WORK/serial-$name.log" --timeout "$t" "${extra[@]}" | grep '^RESULT ' | tail -1)"
  echo "boot[$name]: $BOOT_LINE"
  img_open
}
field() { echo "$BOOT_LINE" | tr ' ' '\n' | sed -n "s/^$1=//p" | head -1; }

main_flow() {
  log "environment"
  uname -r; cryptsetup --version; qemu-system-x86_64 --version | head -1; debootstrap --version
  [ -w /dev/kvm ] && echo "kvm: available" || echo "kvm: NOT available (software emulation, slow)"
  cp /usr/share/OVMF/OVMF_VARS_4M.fd "$WORK/vars.fd" || { ABORT="OVMF vars missing"; return 1; }

  log "disk image and partitions"
  truncate -s 10G "$IMG"
  try "partition image" sgdisk       -n 1:${PART_START[1]}:$((PART_START[1]+PART_SIZE[1]-1)) -t 1:ef00 -c 1:ESP       -n 2:${PART_START[2]}:$((PART_START[2]+PART_SIZE[2]-1)) -t 2:8300 -c 2:CHEENA-BOOT       -n 3:${PART_START[3]}:$((PART_START[3]+PART_SIZE[3]-1)) -t 3:8309 -c 3:CHEENA-VAULT "$IMG" || return 1
  sgdisk -p "$IMG" | tail -5
  try "attach image" img_open || return 1
  try "mkfs ESP" mkfs.vfat -F32 -n ESP "$P1" || return 1
  try "mkfs boot" mkfs.ext4 -q -L CHEENA-BOOT "$P2" || return 1
  echo "+ luksFormat vault (Argon2id)"
  printf '%s' "$PASS" | cryptsetup luksFormat --type luks2 --batch-mode --label CHEENA-VAULT "${PBKDF_OPTS[@]}" --key-file - "$P3" || { ABORT="luksFormat"; return 1; }
  printf '%s' "$PASS" | cryptsetup open --type luks2 --key-file - "$P3" "$MAP" || { ABORT="luks open"; return 1; }
  try "mkfs btrfs" mkfs.btrfs -q -L cheena-pool "/dev/mapper/$MAP" || return 1
  mount -o subvolid=5 "/dev/mapper/$MAP" "$TOP" || { ABORT="mount top"; return 1; }
  for sv in @ @home @snapshots; do btrfs subvolume create "$TOP/$sv" >/dev/null; done
  umount "$TOP"
  LUKS_UUID="$(cryptsetup luksUUID "$P3")"
  BOOT_UUID="$(blkid -p -s UUID -o value "$P2")"
  ESP_UUID="$(blkid -p -s UUID -o value "$P1")"

  log "debootstrap $SUITE (minbase, release pocket only)"
  mount -o subvol=@ "/dev/mapper/$MAP" "$MNT" || { ABORT="mount @"; return 1; }
  try "debootstrap" debootstrap --arch=amd64 --variant=minbase --components=main --include=ca-certificates,ubuntu-keyring \
      "$SUITE" "$MNT" "$MIRROR" /usr/share/debootstrap/scripts/gutsy >"$WORK/debootstrap.log" 2>&1 || { tail -20 "$WORK/debootstrap.log"; return 1; }
  umount "$MNT"
  try "mount tree" tree_mount || return 1
  try "bind mounts" bind_mounts || return 1

  log "configure guest"
  printf '#!/bin/sh\nexit 101\n' > "$MNT/usr/sbin/policy-rc.d"; chmod +x "$MNT/usr/sbin/policy-rc.d"
  rm -f "$MNT/etc/apt/sources.list"
  cat > "$MNT/etc/apt/sources.list.d/ubuntu.sources" <<EOF
Types: deb
URIs: $MIRROR
Suites: $SUITE
Components: main
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
  echo "cheena-poc" > "$MNT/etc/hostname"
  echo "v1" > "$MNT/etc/cheena-version"
  echo "$HOME_TOKEN" > "$MNT/home/poc-marker"
  echo "$MAP UUID=$LUKS_UUID none luks" > "$MNT/etc/crypttab"
  cat > "$MNT/etc/fstab" <<EOF
/dev/mapper/$MAP  /          btrfs  subvol=@,noatime      0 0
/dev/mapper/$MAP  /home      btrfs  subvol=@home,noatime  0 0
UUID=$BOOT_UUID   /boot      ext4   defaults              0 0
UUID=$ESP_UUID    /boot/efi  vfat   umask=0077            0 0
EOF
  mkdir -p "$MNT/usr/local/sbin"
  cat > "$MNT/usr/local/sbin/cheena-poc-marker" <<'EOF'
#!/bin/sh
k="$(uname -r)"; m=no; [ -d "/lib/modules/$k" ] && m=yes
efi=no; mountpoint -q /boot/efi && efi=yes
echo "CHEENA-BOOT-OK version=$(cat /etc/cheena-version 2>/dev/null) kernel=$k modules=$m efi=$efi home=$(cat /home/poc-marker 2>/dev/null)" > /dev/ttyS0
sleep 1
systemctl poweroff
EOF
  chmod 0755 "$MNT/usr/local/sbin/cheena-poc-marker"
  cat > "$MNT/etc/systemd/system/cheena-poc-marker.service" <<'EOF'
[Unit]
Description=CHEENA PoC boot marker
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/cheena-poc-marker

[Install]
WantedBy=multi-user.target
EOF

  log "install kernel, initramfs tools, shim and signed GRUB"
  try "apt update" in_chroot apt-get -q update || return 1
  try "apt install" in_chroot apt-get -q install -y --no-install-recommends \
      systemd-sysv udev kmod zstd initramfs-tools cryptsetup cryptsetup-initramfs btrfs-progs \
      linux-image-virtual grub-efi-amd64-signed shim-signed >"$WORK/apt-install.log" 2>&1 || { tail -30 "$WORK/apt-install.log"; return 1; }
  tail -3 "$WORK/apt-install.log"
  in_chroot systemctl enable cheena-poc-marker.service
  in_chroot systemctl set-default multi-user.target
  chmod -x "$MNT"/etc/kernel/postinst.d/zz-update-grub "$MNT"/etc/kernel/postrm.d/zz-update-grub 2>/dev/null
  try "update-initramfs" in_chroot update-initramfs -u -k all || return 1
  K1="$(kernels | tail -1)"
  echo "kernel K1: $K1"
  echo "grub: $(in_chroot dpkg-query -W -f='${Version}' grub-efi-amd64-signed), shim: $(in_chroot dpkg-query -W -f='${Version}' shim-signed)"
  if in_chroot lsinitramfs "/boot/initrd.img-$K1" | grep -q 'sbin/cryptsetup$'; then
    record INIT-01 PASS "initramfs contains cryptsetup for the vault" "$K1"
  else record INIT-01 FAIL "initramfs has no cryptsetup; the vault cannot be unlocked at boot" "$K1"; fi

  log "install boot loader to the image ESP (removable path, no NVRAM)"
  try "grub-install" in_chroot grub-install --target=x86_64-efi --efi-directory=/boot/efi --boot-directory=/boot \
      --removable --no-nvram --uefi-secure-boot || return 1
  # With --removable, Ubuntu installs the CD-style GRUB image, which looks for
  # /.disk/info and /boot/grub and ignores a grub.cfg next to itself (seen in CI:
  # it dropped to a grub> prompt). Use the normal signed image instead; it reads
  # EFI/ubuntu/grub.cfg on the ESP, as on an installed system.
  try "install signed grubx64.efi" cp "$MNT/usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed" "$MNT/boot/efi/EFI/BOOT/grubx64.efi" || return 1
  for d in BOOT ubuntu; do
    mkdir -p "$MNT/boot/efi/EFI/$d"
    printf 'search.fs_uuid %s root\nset prefix=($root)/grub\nconfigfile $prefix/grub.cfg\n' "$BOOT_UUID" > "$MNT/boot/efi/EFI/$d/grub.cfg"
  done
  ls -1 "$MNT/boot/efi/EFI/BOOT/"
  write_grub_cfg "$K1"

  # --------------------------------------------------------------------------
  log "BOOT 1: fresh system, wrong passphrase first"
  boot b1 400 wrong-first
  if [ "$(field status)" = ok ] && [ "$(field kernel)" = "$K1" ] && [ "$(field modules)" = yes ] && [ "$(field version)" = v1 ] && [ "$(field efi)" = yes ]; then
    record BOOT-01 PASS "boots through shim and signed GRUB, unlocks the Argon2id vault from the initramfs, mounts Btrfs subvolumes" "kernel $K1, $(field accel), $(field seconds)s"
  else record BOOT-01 FAIL "fresh system did not boot to the marker" "$BOOT_LINE"; return 1; fi
  if [ "$(field wrong_rejected)" = yes ]; then record BOOT-02 PASS "wrong passphrase at the boot prompt is rejected and the prompt repeats" "$(field prompts) prompts"
  else record BOOT-02 FAIL "wrong passphrase was not rejected at boot" "$BOOT_LINE"; fi
  [ "$(field home)" = "$HOME_TOKEN" ] || record HOME-01 FAIL "home marker wrong after boot 1" "$BOOT_LINE"

  # --------------------------------------------------------------------------
  log "snapshot, then a real kernel update from $SUITE-updates"
  mount -o subvolid=5 "/dev/mapper/$MAP" "$TOP" && btrfs subvolume snapshot -r "$TOP/@" "$TOP/@snapshots/pre-update" >/dev/null && umount "$TOP" || { ABORT="snapshot"; return 1; }
  try "mount tree" tree_mount || return 1
  try "bind mounts" bind_mounts || return 1
  sed -i "s/^Suites: .*/Suites: $SUITE $SUITE-updates/" "$MNT/etc/apt/sources.list.d/ubuntu.sources"
  try "apt update (updates)" in_chroot apt-get -q update || return 1
  try "kernel upgrade" in_chroot apt-get -q install -y --no-install-recommends linux-image-virtual >"$WORK/apt-upgrade.log" 2>&1 || { tail -30 "$WORK/apt-upgrade.log"; return 1; }
  echo "v2" > "$MNT/etc/cheena-version"
  K2="$(kernels | tail -1)"
  echo "kernels in /boot: $(kernels | tr '\n' ' ')"
  if [ "$K2" = "$K1" ] || [ ! -e "$MNT/boot/initrd.img-$K2" ]; then ABORT="no second kernel installed (K1=$K1 K2=$K2)"; return 1; fi
  write_grub_cfg "$K2" "$K1"

  log "BOOT 2: updated system"
  boot b2 300
  if [ "$(field status)" = ok ] && [ "$(field kernel)" = "$K2" ] && [ "$(field modules)" = yes ] && [ "$(field version)" = v2 ]; then
    record UPD-01 PASS "after a real kernel update the system boots the new kernel" "$K1 -> $K2"
  else record UPD-01 FAIL "updated system did not boot" "$BOOT_LINE"; return 1; fi
  [ "$(field home)" = "$HOME_TOKEN" ] || record HOME-01 FAIL "home marker wrong after boot 2" "$BOOT_LINE"

  # --------------------------------------------------------------------------
  log "naive rollback: restore @ from the snapshot, leave /boot and grub.cfg alone"
  mount -o subvolid=5 "/dev/mapper/$MAP" "$TOP" && mv "$TOP/@" "$TOP/@broken" \
    && btrfs subvolume snapshot "$TOP/@snapshots/pre-update" "$TOP/@" >/dev/null && umount "$TOP" || { ABORT="rollback"; return 1; }

  log "BOOT 3: rolled-back system still booting the NEW kernel (risk R-03)"
  boot b3 180
  if [ "$(field status)" = ok ] && [ "$(field modules)" = yes ] && [ "$(field efi)" = yes ]; then
    record RB-02 OBSERVED "naive rollback booted cleanly with the new kernel" "$BOOT_LINE"
  else
    record RB-02 OBSERVED "naive rollback is broken: new kernel $K2 with a system that has only $K1 modules" "status=$(field status) modules=$(field modules) efi=$(field efi)"
  fi

  # --------------------------------------------------------------------------
  log "mitigation: boot entry pinned to the kernel that matches the snapshot"
  try "mount tree" tree_mount || return 1
  write_grub_cfg "$K1" "$K2"
  log "BOOT 4: rolled-back system with its matching kernel"
  boot b4 300
  if [ "$(field status)" = ok ] && [ "$(field kernel)" = "$K1" ] && [ "$(field modules)" = yes ] && [ "$(field version)" = v1 ] && [ "$(field efi)" = yes ]; then
    record RB-03 PASS "rollback boots correctly when the boot entry uses the snapshot's own kernel, which was kept in /boot" "kernel $K1, version v1"
  else record RB-03 FAIL "rollback with matching kernel did not boot" "$BOOT_LINE"; fi
  if [ "$(field home)" = "$HOME_TOKEN" ]; then record HOME-01 PASS "/home content identical across install, update and rollback boots" ""
  else record HOME-01 FAIL "home marker changed" "$BOOT_LINE"; fi
  return 0
}

main_flow; rc=$?
[ $rc -ne 0 ] && [ -n "$ABORT" ] && record SETUP FAIL "aborted" "$ABORT"
img_close >/dev/null 2>&1

log "secret leak scan"
leak=0
for s in "$PASS" "$WRONG"; do
  grep -aqF -- "$s" "$LOG" "$WORK"/serial-*.log "$WORK"/*.log 2>/dev/null && leak=1
done
if [ $leak -eq 0 ]; then record SEC-02 PASS "no passphrase in the script log, package logs or VM serial logs" ""
else record SEC-02 FAIL "a passphrase appeared in a log" ""; fi
record SB-01 "NOT RUN" "Secure Boot enforcement" "OVMF ran without enrolled keys; shim and signed GRUB were used but signatures were not enforced"
record PWR-01 "NOT RUN" "power cut during update" ""

echo; echo "### results"
{
  echo "## CHEENA boot and rollback proof of concept"
  echo
  echo "| ID | Result | Check | Detail |"
  echo "|---|---|---|---|"
  for r in "${RESULTS[@]}"; do IFS='|' read -r id st what detail <<<"$r"; echo "| $id | $st | $what | $detail |"; done
} | tee "$WORK/results.md"
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && cat "$WORK/results.md" >> "$GITHUB_STEP_SUMMARY"

clean() { tr -d '\r' | sed -e 's/\x1b\[[0-9;?]*[A-Za-z]//g' -e 's/[^[:print:]\t]//g' -e 's/::/: :/g' | cut -c1-200; }
enc()   { sed -e 's/%/%25/g' | awk 'BEGIN{ORS="%0A"}{print}'; }

summary=""
for r in "${RESULTS[@]}"; do IFS='|' read -r id st what detail <<<"$r"; summary+="$id=$st${detail:+ [$detail]}; "; done
if [ $FAILS -eq 0 ]; then echo "::notice title=boot-poc results::$summary"
else
  echo "::error title=boot-poc results ($FAILS failed)::$summary"
  echo "::error title=boot-poc host log tail::$(tail -n 30 "$LOG" | clean | enc)"
  last="$(ls -1t "$WORK"/serial-*.log 2>/dev/null | head -1)"
  [ -n "$last" ] && echo "::error title=boot-poc serial tail $(basename "$last")::$(tail -c 6000 "$last" | clean | grep -v '^$' | tail -n 30 | enc)"
fi
# Always show what the naive-rollback boot printed last: it is the R-03 evidence.
[ -f "$WORK/serial-b3.log" ] && echo "::notice title=boot-poc naive rollback serial tail::$(tail -c 6000 "$WORK/serial-b3.log" | clean | grep -v '^$' | tail -n 18 | enc)"

exit $(( FAILS > 0 ? 1 : 0 ))
