#!/bin/sh

MDI_BOOT_PIDS=""
MDI_BOOT_PID_FILE="/opt/mdi/state/boot-animation-pids"
MDI_CLEANED=0

mdi_pid_register() {
  pid="$1"
  case "$pid" in ''|*[!0-9]*) return 0 ;; esac
  MDI_BOOT_PIDS="${MDI_BOOT_PIDS:+$MDI_BOOT_PIDS }$pid"
  printf '%s\n' "$pid" >> "$MDI_BOOT_PID_FILE" 2>/dev/null || true
}

mdi_stop_effects() {
  if [ -f "$MDI_BOOT_PID_FILE" ]; then
    while IFS= read -r pid; do
      case "$pid" in ''|*[!0-9]*) ;; *) kill "$pid" 2>/dev/null || true ;; esac
    done < "$MDI_BOOT_PID_FILE"
  fi
  for pid in $MDI_BOOT_PIDS; do
    case "$pid" in ''|*[!0-9]*) ;; *) kill "$pid" 2>/dev/null || true ;; esac
  done
  for pid in $MDI_BOOT_PIDS; do
    case "$pid" in ''|*[!0-9]*) ;; *) wait "$pid" 2>/dev/null || true ;; esac
  done
  : > "$MDI_BOOT_PID_FILE" 2>/dev/null || true
  MDI_BOOT_PIDS=""
}

mdi_cleanup() {
  [ "$MDI_CLEANED" -eq 1 ] && return 0
  MDI_CLEANED=1
  mdi_stop_effects
  mdi_reset_terminal
  mdi_show_cursor
}

mdi_cleanup_rearm() {
  MDI_CLEANED=0
}
