#!/bin/sh
# CHEENA OS boot-test marker.
# Runs only inside a virtual machine (see cheena-boot-marker.service). It
# writes one machine-readable line to the first serial port, which the CI
# boot test reads. It contains no user data and no secrets.
sleep 15
system_state=$(systemctl is-system-running 2>/dev/null || true)
sddm_state=$(systemctl is-active sddm 2>/dev/null || true)
failed_units=$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}' | tr '\n' ',')
kernel=$(uname -r)
printf 'CHEENA-BOOT-OK system=%s sddm=%s kernel=%s failed=%s\n' \
    "$system_state" "$sddm_state" "$kernel" "${failed_units:-none}" > /dev/ttyS0
