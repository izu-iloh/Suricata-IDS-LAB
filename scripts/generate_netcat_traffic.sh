#!/usr/bin/env bash
# Authorized lab traffic generator.
# Usage: ./generate_netcat_traffic.sh <SURICATA_IP>
set -u
TARGET="${1:-<SURICATA_IP>}"
PORT=4444
echo "[+] Testing TCP connection to ${TARGET}:${PORT}"
nc -vz "$TARGET" "$PORT"
echo "[+] Test complete. Check Suricata fast.log/eve.json."
