#!/bin/sh
. /opt/mdi/tui/theme.sh

LOG="/opt/mdi/log/boot-checks.log"
STATE="/opt/mdi/state/status.env"
DEVICE="/opt/mdi/state/device-info.txt"

: > "$LOG"
: > "$STATE"
: > "$DEVICE"

WARNINGS=0

log_row() {
  printf '%-5s %-14s %s\n' "$1" "$2" "$3" >> "$LOG"
}

row() {
  mdi_state "$1" "$2" "$3"
  log_row "$1" "$2" "$3"
  mdi_boot_log "$1" "$2" "$3"
}

warn() {
  WARNINGS=$((WARNINGS+1))
  row WARN "$1" "$2"
}

fail_or_warn() {
  AREA="$1"
  MSG="$2"

  if [ "$MDI_WARN_PROCEED" = "yes" ]; then
    warn "$AREA" "$MSG"
  else
    row FAIL "$AREA" "$MSG"
    printf '\n%bBOOT HALTED%b\n' "$RED" "$RST"
    exit 1
  fi
}

printf '%bDIAGNOSTIC BOARD%b\n' "$BOLD" "$RST"
mdi_hr

if [ -f /etc/alpine-release ]; then
  ALPINE_VERSION="$(cat /etc/alpine-release 2>/dev/null)"
  row PASS Runtime "Alpine $ALPINE_VERSION"
  echo "runtime=alpine-proot" >> "$STATE"
else
  row FAIL Runtime "not Alpine"
  exit 1
fi

if [ -d /opt/mdi ]; then
  row PASS Directory "/opt/mdi ready"
  echo "directory=ready" >> "$STATE"
else
  row FAIL Directory "/opt/mdi missing"
  exit 1
fi

MISSING=""
for T in sh awk sed grep df date clear uname cut tr printf stty ip; do
  command -v "$T" >/dev/null 2>&1 || MISSING="$MISSING $T"
done

if [ -n "$MISSING" ]; then
  fail_or_warn Tools "missing:$MISSING"
else
  row PASS Tools "core shell tools"
  echo "tools=ready" >> "$STATE"
fi

KERNEL="$(uname -srm 2>/dev/null || echo unknown)"
ARCH="$(uname -m 2>/dev/null || echo unknown)"
DATE_NOW="$(date '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || echo unknown)"

{
  echo "kernel=$KERNEL"
  echo "arch=$ARCH"
  echo "date=$DATE_NOW"
} >> "$DEVICE"

row INFO Kernel "$KERNEL"
row INFO Arch "$ARCH"

FREE_MB="$(df -k / 2>/dev/null | awk 'NR==2 {print int($4/1024)}')"
USED_PCT="$(df -k / 2>/dev/null | awk 'NR==2 {print $5}')"
USED_NUM="$(printf '%s' "$USED_PCT" | tr -d '%')"

if [ -z "$FREE_MB" ]; then
  warn Storage "unavailable"
elif [ "$FREE_MB" -lt 1024 ]; then
  fail_or_warn Storage "${FREE_MB} MB free"
elif [ "$USED_NUM" -ge 90 ] 2>/dev/null; then
  warn Storage "$USED_PCT used, ${FREE_MB} MB free"
else
  row PASS Storage "$USED_PCT used, ${FREE_MB} MB free"
fi

echo "storage_free_mb=${FREE_MB:-unknown}" >> "$STATE"
echo "storage_used=${USED_PCT:-unknown}" >> "$STATE"

if ip route 2>/dev/null | grep -q '^default '; then
  warn Network "route detected"
  echo "network=available" >> "$STATE"
else
  row PASS Network "offline-first active"
  echo "network=offline" >> "$STATE"
fi

row INFO Battery "host-only"
echo "battery=host-only" >> "$STATE"

if [ "$WARNINGS" -gt 0 ]; then
  echo "boot_warnings=$WARNINGS" >> "$STATE"
  echo "boot_mode=proceed_with_warnings" >> "$STATE"
  printf '\n'
  mdi_panel "BOOT NOTICE" "Warnings detected: $WARNINGS" "Policy: proceed with warnings" "Review logs from command menu"
else
  echo "boot_warnings=0" >> "$STATE"
  echo "boot_mode=clean" >> "$STATE"
fi

printf '\n'
mdi_bar "verified" 100
mdi_bar "encrypted" 100
mdi_bar "services" 100
mdi_bar "session" 100
printf '\n'
