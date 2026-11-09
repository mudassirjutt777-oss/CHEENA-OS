#!/usr/bin/env bash
# Read-only capability probe for the build runner. Prints facts to stdout.
# Usage: build/scripts/probe-runner.sh [label]
set -uo pipefail
echo "=== CHEENA runner probe: ${1:-} ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ==="
echo "--- os";      grep -E '^(PRETTY_NAME|VERSION_ID)=' /etc/os-release
echo "--- kernel";  uname -r
echo "--- cpu";     nproc; grep -m1 'model name' /proc/cpuinfo
echo "--- virt flags"; grep -o -m1 -E '\b(vmx|svm)\b' /proc/cpuinfo || echo "none visible"
echo "--- memory";  free -h
echo "--- disk";    df -h / /mnt 2>/dev/null
echo "--- kvm";     ls -l /dev/kvm 2>&1; [[ -w /dev/kvm ]] && echo "kvm: writable" || echo "kvm: not writable"
echo "--- loop";    ls /dev/loop-control 2>&1
echo "--- sudo";    sudo -n true 2>/dev/null && echo "passwordless sudo: yes" || echo "passwordless sudo: no"
