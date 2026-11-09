#!/usr/bin/env bash
# CHEENA OS Phase 1b: storage proof of concept (ADR-003 / ADR-004).
#
# Exercises the proposed vault design on DISPOSABLE IMAGE FILES attached as loop
# devices: LUKS2 (Argon2id) -> Btrfs subvolumes. It never touches a real disk.
# Every block device it opens is a loop device it created itself under $WORK.
#
# What it checks is listed in README.md next to this file. It does NOT test
# booting, GRUB, Secure Boot or the kernel-vs-snapshot match: those need a VM.
#
# Must run as root (loop devices, dm-crypt, mount). Intended for a throwaway CI VM.
set -u

WORK="${WORK:-/tmp/cheena-storage-poc}"
IMG="$WORK/vault.img"
DECOY="$WORK/decoy.img"
MAP="cheena-poc-vault"
MNT="$WORK/mnt"
LOG="$WORK/poc.log"
VAULT_LABEL="CHEENA-VAULT"
POOL_LABEL="cheena-pool"
IMG_SIZE_MB=3072
# Argon2id with a fixed, small cost so CI is quick. Real installs use the
# cryptsetup benchmark defaults; this only proves the KDF type works end to end.
PBKDF_OPTS=(--pbkdf argon2id --pbkdf-memory 262144 --pbkdf-force-iterations 4 --pbkdf-parallel 2)

if [ "$(id -u)" -ne 0 ]; then echo "must run as root" >&2; exit 2; fi

rnd() { od -An -tx1 -N"$1" /dev/urandom | tr -d ' \n'; }
# Distinctive secrets so the leak scan cannot match by accident. Never echoed.
PASS="cheenaPASS-$(rnd 12)"
REC="cheenaREC-$(rnd 16)"
WRONG="cheenaWRONG-$(rnd 12)"
DECOY_PASS="cheenaDECOY-$(rnd 12)"

mkdir -p "$WORK" "$MNT"
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1
START_TS="$(date '+%Y-%m-%d %H:%M:%S')"

LOOP=""; LOOP2=""
RESULTS=()   # "ID|STATUS|what|detail"
FAILS=0

record() { RESULTS+=("$1|$2|$3|$4"); echo "== $1 $2: $3 ${4:+($4)}"; [ "$2" = FAIL ] && FAILS=$((FAILS+1)); return 0; }

cleanup() {
  mountpoint -q "$MNT" && umount "$MNT"
  [ -e "/dev/mapper/$MAP" ] && cryptsetup close "$MAP"
  [ -n "$LOOP" ] && losetup -d "$LOOP" 2>/dev/null
  [ -n "$LOOP2" ] && losetup -d "$LOOP2" 2>/dev/null
  return 0
}
trap cleanup EXIT

# --- helpers: secrets go through stdin / process substitution, never argv -----
test_key()  { printf '%s' "$1" | cryptsetup open --test-passphrase --key-file - "$LOOP" >/dev/null 2>&1; }
open_with() { printf '%s' "$1" | cryptsetup open --type luks2 --key-file - "$LOOP" "$MAP"; }
mount_top() { mount -o subvolid=5 "/dev/mapper/$MAP" "$MNT"; }
close_all() { mountpoint -q "$MNT" && umount "$MNT"; [ -e "/dev/mapper/$MAP" ] && cryptsetup close "$MAP"; return 0; }
home_sums() { (cd "$MNT/@home" && find . -type f ! -name 'fill.bin' -print0 | sort -z | xargs -0 sha256sum); }

# Vault discovery as Safe Reinstall would do it: every block device, probed directly.
vault_candidates() {
  local d
  for d in $(lsblk -rnpo NAME); do
    [ "$(blkid -p -s TYPE -o value "$d" 2>/dev/null)" = "crypto_LUKS" ] || continue
    [ "$(blkid -p -s LABEL -o value "$d" 2>/dev/null)" = "$VAULT_LABEL" ] || continue
    echo "$d"
  done
}
# Fail-closed identity check. Prints a reason and returns non-zero to refuse.
verify_identity() {
  local n; n="$(vault_candidates | wc -l)"
  [ "$n" -eq 1 ] || { echo "refuse: $n vault candidates"; return 1; }
  local marker="$MNT/@cheena-data/identity.json"
  [ -f "$marker" ] || { echo "refuse: marker missing"; return 1; }
  grep -q "\"luks_uuid\": \"$(cryptsetup luksUUID "$LOOP")\"" "$marker" || { echo "refuse: LUKS UUID mismatch"; return 1; }
  grep -q "\"btrfs_uuid\": \"$(blkid -p -s UUID -o value "/dev/mapper/$MAP")\"" "$marker" || { echo "refuse: Btrfs UUID mismatch"; return 1; }
  [ "$(blkid -p -s LABEL -o value "/dev/mapper/$MAP")" = "$POOL_LABEL" ] || { echo "refuse: pool label mismatch"; return 1; }
  grep -q '"layout_version": 1' "$marker" || { echo "refuse: unknown layout version"; return 1; }
  echo "ok"; return 0
}

echo "### environment"
uname -r; cryptsetup --version; btrfs --version | head -1

# ------------------------------------------------------------------------------
echo "### setup: vault image, LUKS2 Argon2id, two key slots"
truncate -s "${IMG_SIZE_MB}M" "$IMG"
LOOP="$(losetup --find --show "$IMG")"
case "$LOOP" in /dev/loop*) ;; *) echo "refusing: '$LOOP' is not a loop device"; exit 2;; esac

if printf '%s' "$PASS" | cryptsetup luksFormat --type luks2 --batch-mode --label "$VAULT_LABEL" \
      "${PBKDF_OPTS[@]}" --key-file - "$LOOP" \
   && cryptsetup luksAddKey --batch-mode "${PBKDF_OPTS[@]}" \
      --key-file <(printf '%s' "$PASS") "$LOOP" <(printf '%s' "$REC"); then
  kdfs="$(cryptsetup luksDump "$LOOP" | grep -c 'PBKDF: *argon2id')"
  if [ "$kdfs" -eq 2 ]; then record ENC-01 PASS "LUKS2 vault created with passphrase and recovery-key slots, both Argon2id" "$kdfs slots"
  else record ENC-01 FAIL "expected 2 Argon2id key slots" "found $kdfs"; fi
else
  record ENC-01 FAIL "luksFormat / luksAddKey failed" ""
  echo "cannot continue without a vault"; FATAL=1
fi

if [ -z "${FATAL:-}" ]; then
  # ----------------------------------------------------------------------------
  if test_key "$WRONG"; then record ENC-02 FAIL "wrong passphrase was ACCEPTED" ""
  else record ENC-02 PASS "wrong passphrase refused" ""; fi

  if test_key "$PASS" && test_key "$REC"; then record ENC-03 PASS "passphrase and recovery key each unlock the vault" ""
  else record ENC-03 FAIL "a valid key did not unlock" ""; fi

  # ----------------------------------------------------------------------------
  echo "### setup: Btrfs pool and subvolumes, test data"
  open_with "$PASS" && mkfs.btrfs -q -L "$POOL_LABEL" "/dev/mapper/$MAP" && mount_top
  for sv in @ @home @cheena-data @snapshots; do btrfs subvolume create "$MNT/$sv" >/dev/null; done
  LUKS_UUID_0="$(cryptsetup luksUUID "$LOOP")"
  FS_UUID_0="$(blkid -p -s UUID -o value "/dev/mapper/$MAP")"
  mkdir -p "$MNT/@/etc" "$MNT/@home/user/Documents" "$MNT/@home/user/.mozilla/firefox/abc.default"
  echo "system-v1" > "$MNT/@/etc/cheena-version"
  echo "hello CHEENA" > "$MNT/@home/user/Documents/note.txt"
  head -c 1048576 /dev/urandom > "$MNT/@home/user/.mozilla/firefox/abc.default/places.sqlite"
  head -c 209715200 /dev/urandom > "$MNT/@home/user/Documents/large.bin"
  printf '{\n  "layout_version": 1,\n  "luks_uuid": "%s",\n  "btrfs_uuid": "%s"\n}\n' "$LUKS_UUID_0" "$FS_UUID_0" > "$MNT/@cheena-data/identity.json"
  sync
  home_sums > "$WORK/home.before"
  nfiles="$(wc -l < "$WORK/home.before")"

  # ----------------------------------------------------------------------------
  echo "### identity checks (fail closed)"
  r="$(verify_identity)"; if [ "$r" = ok ]; then record ID-01 PASS "single genuine vault is identified" ""
  else record ID-01 FAIL "genuine vault not identified" "$r"; fi

  mv "$MNT/@cheena-data/identity.json" "$WORK/identity.keep"
  r="$(verify_identity)"; rc=$?
  mv "$WORK/identity.keep" "$MNT/@cheena-data/identity.json"
  if [ $rc -ne 0 ]; then record ID-02 PASS "refuses when the identity marker is missing" "$r"
  else record ID-02 FAIL "did NOT refuse with marker missing" ""; fi

  truncate -s 64M "$DECOY"; LOOP2="$(losetup --find --show "$DECOY")"
  printf '%s' "$DECOY_PASS" | cryptsetup luksFormat --type luks2 --batch-mode --label "$VAULT_LABEL" "${PBKDF_OPTS[@]}" --key-file - "$LOOP2"
  r="$(verify_identity)"; rc=$?
  losetup -d "$LOOP2"; LOOP2=""; rm -f "$DECOY"
  if [ $rc -ne 0 ]; then record ID-03 PASS "refuses when two devices carry the vault label" "$r"
  else record ID-03 FAIL "did NOT refuse with two candidates" ""; fi

  # ----------------------------------------------------------------------------
  echo "### keep-data reinstall: replace @ without mkfs, then reopen as after a reboot"
  btrfs subvolume create "$MNT/@new" >/dev/null
  mkdir -p "$MNT/@new/etc"; echo "system-v2" > "$MNT/@new/etc/cheena-version"
  mv "$MNT/@" "$MNT/@old" && mv "$MNT/@new" "$MNT/@"
  sync; close_all
  open_with "$REC" && mount_top
  home_sums > "$WORK/home.after-reinstall"
  if cmp -s "$WORK/home.before" "$WORK/home.after-reinstall" \
     && [ "$(cat "$MNT/@/etc/cheena-version")" = "system-v2" ] \
     && [ "$(cryptsetup luksUUID "$LOOP")" = "$LUKS_UUID_0" ] \
     && [ "$(blkid -p -s UUID -o value "/dev/mapper/$MAP")" = "$FS_UUID_0" ]; then
    record RI-01 PASS "system subvolume replaced; @home byte-identical; LUKS and Btrfs UUIDs unchanged" "$nfiles files, SHA-256"
  else record RI-01 FAIL "reinstall changed user data or identifiers" ""; fi
  btrfs subvolume delete "$MNT/@old" >/dev/null

  # ----------------------------------------------------------------------------
  echo "### snapshot and rollback of the system subvolume"
  btrfs subvolume snapshot -r "$MNT/@" "$MNT/@snapshots/pre-update" >/dev/null
  echo "system-v3-broken" > "$MNT/@/etc/cheena-version"; echo "junk" > "$MNT/@/etc/bad-update"
  echo "written after the snapshot" > "$MNT/@home/user/Documents/after-snapshot.txt"
  home_sums > "$WORK/home.pre-rollback"
  mv "$MNT/@" "$MNT/@broken" && btrfs subvolume snapshot "$MNT/@snapshots/pre-update" "$MNT/@" >/dev/null
  home_sums > "$WORK/home.post-rollback"
  if [ "$(cat "$MNT/@/etc/cheena-version")" = "system-v2" ] && [ ! -e "$MNT/@/etc/bad-update" ] \
     && cmp -s "$WORK/home.pre-rollback" "$WORK/home.post-rollback"; then
    record RB-01 PASS "rollback restores the system subvolume and leaves @home (incl. newer files) untouched" ""
  else record RB-01 FAIL "rollback did not restore the system or altered @home" ""; fi
  btrfs subvolume delete "$MNT/@broken" >/dev/null

  # ----------------------------------------------------------------------------
  echo "### disk full"
  dd if=/dev/urandom of="$MNT/@home/fill.bin" bs=1M status=none 2>"$WORK/dd.err"; ddrc=$?
  full_pct="$(df --output=pcent "$MNT" | tail -1 | tr -d ' %')"
  ok=1
  [ $ddrc -ne 0 ] || ok=0                                   # must have hit ENOSPC
  btrfs subvolume delete "$MNT/@snapshots/pre-update" >/dev/null 2>&1 || ok=0   # can still free space
  rm -f "$MNT/@home/fill.bin" || ok=0
  sync; btrfs filesystem sync "$MNT"
  echo "still writable" > "$MNT/@home/user/Documents/after-full.txt" || ok=0
  umount "$MNT" && mount_top || ok=0                         # remounts cleanly
  home_sums > "$WORK/home.after-full"
  # only after-full.txt may differ from the pre-rollback set
  grep -v 'after-full.txt' "$WORK/home.after-full" | cmp -s - "$WORK/home.pre-rollback" || ok=0
  if [ $ok -eq 1 ]; then record DF-01 PASS "after filling the pool: snapshot delete, file delete, new write and remount all work; data intact" "peak use ${full_pct}%"
  else record DF-01 FAIL "pool did not recover cleanly from disk-full" "dd rc=$ddrc, peak ${full_pct}%"; fi
  home_sums > "$WORK/home.final"

  # ----------------------------------------------------------------------------
  echo "### LUKS header destroyed, then restored from backup"
  rm -f "$WORK/header.bak"
  cryptsetup luksHeaderBackup "$LOOP" --header-backup-file "$WORK/header.bak"
  close_all
  dd if=/dev/zero of="$LOOP" bs=1M count=8 conv=notrunc status=none; sync
  if test_key "$PASS"; then record HD-01 FAIL "vault still opens after header was zeroed (test invalid)" ""
  else
    cryptsetup luksHeaderRestore --batch-mode "$LOOP" --header-backup-file "$WORK/header.bak"
    if open_with "$PASS" && mount_top && home_sums > "$WORK/home.after-header" && cmp -s "$WORK/home.final" "$WORK/home.after-header"; then
      record HD-01 PASS "zeroed header makes the vault unopenable; restoring the backup recovers all data" ""
    else record HD-01 FAIL "data not recovered after header restore" ""; fi
  fi
  close_all
fi

# ------------------------------------------------------------------------------
echo "### secret leak scan (this log, kernel log, journal since start)"
sync; sleep 1
leak=0
for s in "$PASS" "$REC" "$WRONG" "$DECOY_PASS"; do
  grep -qF -- "$s" "$LOG" && leak=1
  dmesg 2>/dev/null | grep -qF -- "$s" && leak=1
  journalctl --since "$START_TS" --no-pager 2>/dev/null | grep -qF -- "$s" && leak=1
done
if [ $leak -eq 0 ]; then record SEC-01 PASS "no passphrase or recovery key in the script log, dmesg or journal" "PoC script only"
else record SEC-01 FAIL "a secret appeared in a log" ""; fi

record PWR-01 "NOT RUN" "power cut during write" "needs a VM that can be killed mid-write"
record BOOT-01 "NOT RUN" "boot with Secure Boot on/off; kernel vs snapshot match after rollback" "needs a bootable image in QEMU"

# ------------------------------------------------------------------------------
echo
echo "### results"
{
  echo "## CHEENA storage proof of concept"
  echo
  echo "Loop-device test on $(uname -r), $(cryptsetup --version | head -1), $(btrfs --version | head -1)."
  echo
  echo "| ID | Result | Check | Detail |"
  echo "|---|---|---|---|"
  for r in "${RESULTS[@]}"; do IFS='|' read -r id st what detail <<<"$r"; echo "| $id | $st | $what | $detail |"; done
} | tee "$WORK/results.md"
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && cat "$WORK/results.md" >> "$GITHUB_STEP_SUMMARY"

# One annotation with every result, readable through the public API without a login.
summary=""
for r in "${RESULTS[@]}"; do IFS='|' read -r id st what detail <<<"$r"; summary+="$id=$st; "; done
if [ $FAILS -eq 0 ]; then echo "::notice title=storage-poc results::$summary"
else echo "::error title=storage-poc results ($FAILS failed)::$summary"; fi
for r in "${RESULTS[@]}"; do
  IFS='|' read -r id st what detail <<<"$r"
  [ "$st" = FAIL ] && echo "::error title=$id FAIL::$what ${detail}"
done

exit $(( FAILS > 0 ? 1 : 0 ))
