#!/usr/bin/env bash
# CHEENA OS: build a minimal live ISO from the pinned Ubuntu archive.
#
# Method: debootstrap -> chroot package install -> CHEENA overlay
#         -> squashfs (casper layout) -> GRUB hybrid ISO (UEFI + BIOS).
#
# SAFETY:
#  - Intended for disposable CI runners (GitHub Actions). Requires root.
#  - Writes only inside $WORK_DIR and $OUT_DIR. Never touches block devices.
#  - Refuses to run unless CHEENA_CI_BUILD=1 is set, so a developer
#    can't run it on their own machine by accident.
#
# Usage: sudo CHEENA_CI_BUILD=1 build/scripts/build-iso.sh <work_dir> <out_dir>
set -euo pipefail

if [[ "${CHEENA_CI_BUILD:-0}" != "1" ]]; then
    echo "Refusing to run: set CHEENA_CI_BUILD=1 (intended for disposable CI runners only)." >&2
    exit 2
fi
if [[ $EUID -ne 0 ]]; then
    echo "Must run as root (debootstrap/chroot)." >&2
    exit 2
fi
if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <work_dir> <out_dir>" >&2
    exit 2
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE_DIR="$REPO_ROOT/build/image"
WORK_DIR="$(realpath -m "$1")"
OUT_DIR="$(realpath -m "$2")"
ROOTFS="$WORK_DIR/rootfs"
ISO_ROOT="$WORK_DIR/iso"

# Guard against dangerous paths.
for d in "$WORK_DIR" "$OUT_DIR"; do
    case "$d" in
        /|/bin|/boot|/dev|/etc|/home|/lib*|/proc|/root|/run|/sbin|/sys|/usr|/var)
            echo "Refusing unsafe directory: $d" >&2; exit 2 ;;
    esac
done

# shellcheck source=../image/config.env
source "$IMAGE_DIR/config.env"
export SOURCE_DATE_EPOCH
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C.UTF-8

log() { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }

MOUNTS=()
cleanup() {
    local i
    for (( i=${#MOUNTS[@]}-1; i>=0; i-- )); do
        umount -l "${MOUNTS[$i]}" 2>/dev/null || true
    done
}
trap cleanup EXIT

bind_mounts() {
    local m
    for m in dev dev/pts proc sys run; do
        mkdir -p "$ROOTFS/$m"
        mount --bind "/$m" "$ROOTFS/$m"
        MOUNTS+=("$ROOTFS/$m")
    done
}

in_chroot() { chroot "$ROOTFS" /usr/bin/env -i \
    PATH=/usr/sbin:/usr/bin:/sbin:/bin HOME=/root LC_ALL=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive "$@"; }

mkdir -p "$WORK_DIR" "$OUT_DIR"
if [[ -e "$ROOTFS" ]]; then
    echo "Work dir already contains a rootfs: $ROOTFS. Use a fresh directory." >&2
    exit 2
fi

# ---------------------------------------------------------------- 1. bootstrap
log "debootstrap $UBUNTU_RELEASE from $ARCHIVE_URL"
# Ubuntu releases all share the 'gutsy' debootstrap script. Passing it
# explicitly lets an older host debootstrap build a newer release.
# ca-certificates: apt inside the chroot fetches the HTTPS snapshot URL.
# ubuntu-keyring: provides the Signed-By key used in ubuntu.sources below.
# Retry: CI run 5 failed once fetching the Release file from snapshot.ubuntu.com,
# and the archive answered normally minutes later.
for attempt in 1 2 3; do
    if debootstrap --arch="$ARCH" --variant=minbase --components="$COMPONENTS" \
        --include=ca-certificates,ubuntu-keyring \
        "$UBUNTU_RELEASE" "$ROOTFS" "$ARCHIVE_URL" /usr/share/debootstrap/scripts/gutsy; then
        break
    fi
    if (( attempt == 3 )); then echo "debootstrap failed 3 times" >&2; exit 1; fi
    log "debootstrap attempt $attempt failed; retrying in 60 s"
    rm -rf "$ROOTFS"
    sleep 60
done

bind_mounts

# Don't start services inside the chroot during package installation.
printf '#!/bin/sh\nexit 101\n' > "$ROOTFS/usr/sbin/policy-rc.d"
chmod 0755 "$ROOTFS/usr/sbin/policy-rc.d"

# Pinned sources, deb822 format.
rm -f "$ROOTFS/etc/apt/sources.list"
mkdir -p "$ROOTFS/etc/apt/sources.list.d"
cat > "$ROOTFS/etc/apt/sources.list.d/ubuntu.sources" <<EOF
Types: deb
URIs: $ARCHIVE_URL
Suites: $UBUNTU_RELEASE $UBUNTU_RELEASE-updates $UBUNTU_RELEASE-security
Components: ${COMPONENTS//,/ }
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

# ---------------------------------------------------------------- 2. packages
mapfile -t PKGS < <(sed -e 's/#.*//' -e 's/[[:space:]]//g' "$IMAGE_DIR/packages.txt" | grep -v '^$')
log "installing ${#PKGS[@]} packages (no recommends)"
in_chroot apt-get -o Acquire::Retries=5 update
in_chroot apt-get -o Acquire::Retries=5 install -y --no-install-recommends "${PKGS[@]}"

# ---------------------------------------------------------------- 3. CHEENA overlay
log "applying CHEENA overlay"
cp -a "$IMAGE_DIR/overlay/." "$ROOTFS/"
chmod 0755 "$ROOTFS/usr/lib/cheena/boot-marker.sh"

# os-release: divert the base-files copy so package upgrades don't overwrite it.
# --no-rename: base-files is Essential, so its file must never go missing even briefly.
in_chroot dpkg-divert --local --no-rename --add /usr/lib/os-release
sed -e "s/@VERSION@/$CHEENA_VERSION/g" -e "s/@CODENAME@/$CHEENA_CODENAME/g" \
    -e "s/@UBUNTU_RELEASE@/$UBUNTU_RELEASE/g" \
    "$IMAGE_DIR/os-release.in" > "$ROOTFS/usr/lib/os-release"
ln -sf ../usr/lib/os-release "$ROOTFS/etc/os-release"

echo "cheena-live" > "$ROOTFS/etc/hostname"
echo "en_US.UTF-8 UTF-8" > "$ROOTFS/etc/locale.gen"
in_chroot locale-gen
echo 'LANG=en_US.UTF-8' > "$ROOTFS/etc/default/locale"

in_chroot systemctl set-default graphical.target
in_chroot systemctl enable cheena-boot-marker.service
in_chroot update-initramfs -u -k all

# ---------------------------------------------------------------- 4. record manifest
log "recording package manifest"
in_chroot dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\t${source:Package}\n' \
    | LC_ALL=C sort > "$OUT_DIR/package-manifest.tsv"

# ---------------------------------------------------------------- 5. clean rootfs
log "cleaning rootfs"
rm -f "$ROOTFS/usr/sbin/policy-rc.d"
in_chroot apt-get clean
rm -rf "$ROOTFS"/var/lib/apt/lists/* "$ROOTFS"/var/log/*.log \
       "$ROOTFS"/var/cache/debconf/*-old "$ROOTFS"/tmp/* "$ROOTFS"/root/.bash_history
: > "$ROOTFS/etc/machine-id"
rm -f "$ROOTFS/var/lib/dbus/machine-id"

cleanup
MOUNTS=()

# ---------------------------------------------------------------- 6. ISO tree
log "assembling ISO tree"
mkdir -p "$ISO_ROOT/casper" "$ISO_ROOT/boot/grub" "$ISO_ROOT/.disk"
KVER="$(basename "$(ls -1 "$ROOTFS"/boot/vmlinuz-* | LC_ALL=C sort -V | tail -n1)" | sed 's/^vmlinuz-//')"
cp "$ROOTFS/boot/vmlinuz-$KVER" "$ISO_ROOT/casper/vmlinuz"
cp "$ROOTFS/boot/initrd.img-$KVER" "$ISO_ROOT/casper/initrd"
cp "$OUT_DIR/package-manifest.tsv" "$ISO_ROOT/casper/filesystem.manifest"
du -sx --block-size=1 "$ROOTFS" | cut -f1 > "$ISO_ROOT/casper/filesystem.size"
echo "CHEENA OS $CHEENA_VERSION ($CHEENA_CODENAME) - based on Ubuntu $UBUNTU_RELEASE $ARCH" > "$ISO_ROOT/.disk/info"

log "mksquashfs ($SQUASHFS_COMP level $SQUASHFS_LEVEL)"
# squashfs-tools refuses SOURCE_DATE_EPOCH together with explicit time options,
# so drop the variable for this one command and pass the times explicitly.
env -u SOURCE_DATE_EPOCH mksquashfs "$ROOTFS" "$ISO_ROOT/casper/filesystem.squashfs" \
    -noappend -comp "$SQUASHFS_COMP" -Xcompression-level "$SQUASHFS_LEVEL" \
    -mkfs-time "$SOURCE_DATE_EPOCH" -all-time "$SOURCE_DATE_EPOCH" -no-progress

cat > "$ISO_ROOT/boot/grub/grub.cfg" <<'EOF'
serial --unit=0 --speed=115200
terminal_input console serial
terminal_output console serial
set timeout=3
set default=0

menuentry "CHEENA OS (live)" {
    linux /casper/vmlinuz boot=casper console=tty0 console=ttyS0,115200n8 ---
    initrd /casper/initrd
}
menuentry "CHEENA OS (live, safe graphics)" {
    linux /casper/vmlinuz boot=casper nomodeset console=tty0 console=ttyS0,115200n8 ---
    initrd /casper/initrd
}
EOF

# casper-md5check verifies the medium against md5sum.txt and fails without it
# (CI run 3). List every file in the tree; grub-mkrescue's own files are not listed.
( cd "$ISO_ROOT" && find . -type f ! -name md5sum.txt -print0 | LC_ALL=C sort -z \
    | xargs -0 md5sum > md5sum.txt )

# ---------------------------------------------------------------- 7. ISO
ISO_NAME="cheena-os-${CHEENA_VERSION}-${ARCH}.iso"
log "building $ISO_NAME"
grub-mkrescue -o "$OUT_DIR/$ISO_NAME" "$ISO_ROOT" -- -volid "$ISO_VOLUME_ID"

( cd "$OUT_DIR" && sha256sum "$ISO_NAME" > SHA256SUMS )

# ---------------------------------------------------------------- 8. build info
cat > "$OUT_DIR/build-info.json" <<EOF
{
  "cheena_version": "$CHEENA_VERSION",
  "cheena_codename": "$CHEENA_CODENAME",
  "git_commit": "${CHEENA_GIT_COMMIT:-$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo unknown)}",
  "ubuntu_release": "$UBUNTU_RELEASE",
  "archive_url": "$ARCHIVE_URL",
  "source_date_epoch": $SOURCE_DATE_EPOCH,
  "kernel": "$KVER",
  "package_count": $(wc -l < "$OUT_DIR/package-manifest.tsv"),
  "iso_name": "$ISO_NAME",
  "iso_bytes": $(stat -c %s "$OUT_DIR/$ISO_NAME"),
  "iso_sha256": "$(cut -d' ' -f1 "$OUT_DIR/SHA256SUMS")",
  "squashfs_bytes": $(stat -c %s "$ISO_ROOT/casper/filesystem.squashfs"),
  "host_tools": {
    "debootstrap": "$(dpkg-query -W -f='${Version}' debootstrap)",
    "squashfs-tools": "$(dpkg-query -W -f='${Version}' squashfs-tools)",
    "grub-efi-amd64-bin": "$(dpkg-query -W -f='${Version}' grub-efi-amd64-bin)",
    "xorriso": "$(dpkg-query -W -f='${Version}' xorriso)"
  },
  "built_at_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
log "done: $OUT_DIR/$ISO_NAME"
