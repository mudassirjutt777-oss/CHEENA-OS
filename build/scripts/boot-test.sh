#!/usr/bin/env bash
# CHEENA OS: boot an ISO in QEMU with UEFI (OVMF, Secure Boot OFF) and check
# that it reaches graphical.target with SDDM running.
#
# Pass criteria (all required):
#   - The serial log contains the marker line from cheena-boot-marker.service
#   - The marker reports sddm=active
#   - No kernel panic in the serial log
# Evidence written to <evidence_dir>: serial.log, boot-result.json, screen.png (if captured)
#
# This is a VIRTUAL MACHINE test only. It says nothing about physical hardware.
#
# Usage: build/scripts/boot-test.sh <iso> <evidence_dir> [timeout_seconds]
set -euo pipefail

ISO="$(realpath "$1")"
EVID="$(realpath -m "$2")"
TIMEOUT="${3:-}"
mkdir -p "$EVID"

OVMF_CODE=/usr/share/OVMF/OVMF_CODE_4M.fd
OVMF_VARS_SRC=/usr/share/OVMF/OVMF_VARS_4M.fd
[[ -r "$OVMF_CODE" && -r "$OVMF_VARS_SRC" ]] || { echo "OVMF firmware not found" >&2; exit 2; }

if [[ -w /dev/kvm ]]; then
    ACCEL=kvm; CPU=host; TIMEOUT="${TIMEOUT:-600}"
else
    ACCEL=tcg; CPU=max; TIMEOUT="${TIMEOUT:-2400}"
fi
echo "Boot test: accel=$ACCEL timeout=${TIMEOUT}s"

RUN="$(mktemp -d)"
cp "$OVMF_VARS_SRC" "$RUN/vars.fd"
SERIAL="$EVID/serial.log"
MON="$RUN/monitor.sock"
: > "$SERIAL"

qemu-system-x86_64 \
    -machine q35,accel="$ACCEL" -cpu "$CPU" -smp 2 -m 3072 \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,file="$RUN/vars.fd" \
    -cdrom "$ISO" -boot d \
    -device virtio-net-pci,netdev=n0 -netdev user,id=n0 \
    -vga std -display none \
    -serial file:"$SERIAL" \
    -monitor unix:"$MON",server,nowait \
    -no-reboot &
QEMU_PID=$!

mon() { printf '%s\n' "$1" | socat - UNIX-CONNECT:"$MON" >/dev/null 2>&1 || true; }

start=$(date +%s)
result=timeout
while kill -0 "$QEMU_PID" 2>/dev/null; do
    if grep -q 'CHEENA-BOOT-OK' "$SERIAL"; then result=marker; break; fi
    if grep -qi 'Kernel panic' "$SERIAL"; then result=panic; break; fi
    if (( $(date +%s) - start > TIMEOUT )); then result=timeout; break; fi
    sleep 5
done
kill -0 "$QEMU_PID" 2>/dev/null || [[ "$result" != timeout ]] || result=qemu-exited
elapsed=$(( $(date +%s) - start ))

# Screenshot of whatever is on screen now (desktop, login screen or error).
if kill -0 "$QEMU_PID" 2>/dev/null; then
    [[ "$result" == marker ]] && sleep 20
    mon "screendump $RUN/screen.ppm"
    sleep 2
    if [[ -s "$RUN/screen.ppm" ]] && command -v pnmtopng >/dev/null; then
        pnmtopng "$RUN/screen.ppm" > "$EVID/screen.png" || true
    fi
    mon "quit"
fi
wait "$QEMU_PID" 2>/dev/null || true

marker_line="$(grep -m1 'CHEENA-BOOT-OK' "$SERIAL" | tr -d '\r' || true)"
sddm_state="$(sed -n 's/.*sddm=\([^ ]*\).*/\1/p' <<<"$marker_line")"
pass=false
if [[ "$result" == marker && "$sddm_state" == active ]]; then pass=true; fi

cat > "$EVID/boot-result.json" <<EOF
{
  "test": "TS-boot-live-uefi-sb-off",
  "environment": "QEMU q35, OVMF (Secure Boot off), 2 vCPU, 3 GB RAM, accel=$ACCEL",
  "iso_sha256": "$(sha256sum "$ISO" | cut -d' ' -f1)",
  "outcome": "$result",
  "seconds": $elapsed,
  "marker": "$(sed 's/"/\\"/g' <<<"$marker_line")",
  "sddm": "${sddm_state:-unknown}",
  "pass": $pass,
  "note": "Virtual machine result only; not evidence of physical hardware support."
}
EOF
cat "$EVID/boot-result.json"
rm -rf "$RUN"
$pass
