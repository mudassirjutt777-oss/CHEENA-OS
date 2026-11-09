#!/usr/bin/env python3
"""Boot a disk image in QEMU/OVMF, answer the disk-unlock prompt on the serial
console, and wait for the CHEENA boot marker.

Prints exactly one line starting with "RESULT ". The passphrase is read from a
file and written only to the VM's serial input, never to argv or the log.
"""
import argparse
import os
import re
import select
import subprocess
import sys
import time

PROMPT = b"Please unlock disk"
MARKER = re.compile(rb"CHEENA-BOOT-OK[^\r\n]*")
BAD = [
    (b"emergency mode", "emergency"),
    (b"root account is locked", "emergency"),
    (b"Give root password for maintenance", "emergency"),
    (b"Kernel panic", "panic"),
    (b"ALERT!", "initramfs-alert"),
    (b"(initramfs)", "initramfs-shell"),
    (b"grub> ", "grub-prompt"),
    (b"grub rescue>", "grub-rescue"),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--disk", required=True)
    ap.add_argument("--vars", required=True)
    ap.add_argument("--code", default="/usr/share/OVMF/OVMF_CODE_4M.fd")
    ap.add_argument("--passfile", required=True)
    ap.add_argument("--wrongfile")
    ap.add_argument("--log", required=True)
    ap.add_argument("--timeout", type=int, default=300)
    a = ap.parse_args()

    good = open(a.passfile, "rb").read().strip()
    wrong = open(a.wrongfile, "rb").read().strip() if a.wrongfile else None

    kvm = os.access("/dev/kvm", os.R_OK | os.W_OK)
    cmd = [
        "qemu-system-x86_64",
        "-machine", "q35,accel=" + ("kvm" if kvm else "tcg"),
        "-cpu", "host" if kvm else "max",
        "-m", "2048", "-smp", "2",
        "-display", "none", "-monitor", "none", "-serial", "stdio",
        "-net", "none", "-no-reboot",
        "-drive", f"if=pflash,format=raw,readonly=on,file={a.code}",
        "-drive", f"if=pflash,format=raw,file={a.vars}",
        "-drive", f"file={a.disk},format=raw,if=virtio",
    ]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    fd = p.stdout.fileno()
    buf = b""
    sent = 0
    status = "timeout"
    marker = ""
    start = time.time()
    with open(a.log, "wb") as log:
        while time.time() - start < a.timeout:
            r, _, _ = select.select([fd], [], [], 1.0)
            if r:
                chunk = os.read(fd, 65536)
                if not chunk:
                    status = "qemu-exit" if not marker else status
                    break
                buf += chunk
                log.write(chunk)
                log.flush()
            elif p.poll() is not None:
                if not marker:
                    status = "qemu-exit"
                break

            prompts = buf.count(PROMPT)
            if prompts > sent and sent < 4:
                key = wrong if (wrong and sent == 0) else good
                time.sleep(0.5)
                p.stdin.write(key + b"\n")
                p.stdin.flush()
                sent += 1

            m = MARKER.search(buf)
            if m and not marker:
                marker = m.group(0).decode("ascii", "replace")
                status = "ok"
                # give the guest time to power off by itself
                try:
                    p.wait(timeout=60)
                except subprocess.TimeoutExpired:
                    pass
                break

            hit = next((name for pat, name in BAD if pat in buf), None)
            if hit and not marker:
                status = hit
                break

    if p.poll() is None:
        p.kill()
        p.wait()

    wrong_rejected = "n/a"
    if wrong:
        wrong_rejected = "yes" if buf.count(PROMPT) >= 2 else "no"
    took = int(time.time() - start)
    print(f"RESULT status={status} accel={'kvm' if kvm else 'tcg'} seconds={took} "
          f"prompts={buf.count(PROMPT)} wrong_rejected={wrong_rejected} marker={marker}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
