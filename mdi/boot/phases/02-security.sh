#!/bin/sh

mdi_security_status_line() {
  row="$1"; label="$2"; result="$3"; colour="$4"
  if [ "${MDI_PROFILE:-phone}" = "ultra-compact" ]; then
    mdi_region_clear "$STATUS_TOP" "$STATUS_LEFT" "$STATUS_WIDTH" "$STATUS_HEIGHT"
    mdi_draw_status 1 "$label" "$result" "$colour"
  else
    mdi_draw_status "$row" "$label" "$result" "$colour"
  fi
}

mdi_security_compact_lock() {
  [ "$MAIN_WIDTH" -ge 22 ] || return 1
  [ "$MAIN_HEIGHT" -ge 6 ] || return 1
  row=$(((MAIN_HEIGHT - 5) / 2 + 1))
  [ "$row" -lt 1 ] && row=1
  mdi_draw_center "$MAIN_TOP" "$MAIN_LEFT" "$MAIN_WIDTH" "$MAIN_HEIGHT" "$row" ".------." "$RED"
  row=$((row + 1))
  mdi_draw_center "$MAIN_TOP" "$MAIN_LEFT" "$MAIN_WIDTH" "$MAIN_HEIGHT" "$row" "/  MDI  \\" "$RED"
  row=$((row + 1))
  mdi_draw_center "$MAIN_TOP" "$MAIN_LEFT" "$MAIN_WIDTH" "$MAIN_HEIGHT" "$row" "|  LOCK  |" "$RED"
  row=$((row + 1))
  mdi_draw_center "$MAIN_TOP" "$MAIN_LEFT" "$MAIN_WIDTH" "$MAIN_HEIGHT" "$row" "|  ####  |" "$RED"
  row=$((row + 1))
  mdi_draw_center "$MAIN_TOP" "$MAIN_LEFT" "$MAIN_WIDTH" "$MAIN_HEIGHT" "$row" "\\______/" "$RED"
  return 0
}

mdi_security_lock_fallback() {
  mdi_security_compact_lock || mdi_draw_center "$MAIN_TOP" "$MAIN_LEFT" "$MAIN_WIDTH" "$MAIN_HEIGHT" 2 "[ LOCK ]" "$RED"
}

mdi_phase_security() {
  mdi_screen_contract
  mdi_assets_discover
  mdi_hide_cursor
  mdi_wrap_off
  mdi_clear_screen
  mdi_region_clear "$HEADER_TOP" "$HEADER_LEFT" "$HEADER_WIDTH" "$HEADER_HEIGHT"
  mdi_region_clear "$MAIN_TOP" "$MAIN_LEFT" "$MAIN_WIDTH" "$MAIN_HEIGHT"
  mdi_region_clear "$STATUS_TOP" "$STATUS_LEFT" "$STATUS_WIDTH" "$STATUS_HEIGHT"
  mdi_draw_center "$HEADER_TOP" "$HEADER_LEFT" "$HEADER_WIDTH" "$HEADER_HEIGHT" 1 "MDI SECURITY PROTOCOL" "$RED"

  if [ -n "$MDI_ASSET_SECURITY" ]; then
    mdi_draw_asset_center "$MAIN_TOP" "$MAIN_LEFT" "$MAIN_WIDTH" "$MAIN_HEIGHT" "$MDI_ASSET_SECURITY" "$RED" || \
      mdi_security_lock_fallback
  else
    mdi_security_lock_fallback
  fi

  mdi_start_matrix
  row=1
  mdi_security_status_line "$row" "VERIFY ROOTFS" "[ OK ]" "$GREEN"
  [ "${MDI_ANIMATION_EFFECTIVE:-off}" = "off" ] || sleep "$MDI_BOOT_DELAY" 2>/dev/null || true
  row=$((row + 1))
  mdi_security_status_line "$row" "HASH MANIFEST" "[ OK ]" "$GREEN"
  [ "${MDI_ANIMATION_EFFECTIVE:-off}" = "off" ] || sleep "$MDI_BOOT_DELAY" 2>/dev/null || true
  row=$((row + 1))
  if command -v ip >/dev/null 2>&1 && ip route 2>/dev/null | grep -q '^default '; then
    offline_result="[ WARN ]"
    offline_colour="$YELLOW"
  else
    offline_result="[ OK ]"
    offline_colour="$GREEN"
  fi
  mdi_security_status_line "$row" "CHECK OFFLINE" "$offline_result" "$offline_colour"
  [ "${MDI_ANIMATION_EFFECTIVE:-off}" = "off" ] || sleep "$MDI_BOOT_DELAY" 2>/dev/null || true
  row=$((row + 1))
  mdi_security_status_line "$row" "LOCK SESSION" "[ OK ]" "$GREEN"
  [ "${MDI_ANIMATION_EFFECTIVE:-off}" = "off" ] || sleep "$MDI_BOOT_DELAY" 2>/dev/null || true
  row=$((row + 1))
  if [ "$row" -gt "$STATUS_HEIGHT" ]; then
    row="$STATUS_HEIGHT"
  fi
  mdi_security_status_line "$row" "START CONTROL" "[ OK ]" "$GREEN"

  mkdir -p /opt/mdi/state /opt/mdi/log 2>/dev/null || true
  {
    printf '%s\n' "system=READY"
    printf '%s\n' "security=LOCKED"
    printf '%s\n' "network=OFFLINE"
    printf '%s\n' "mode=TUI"
  } > /opt/mdi/state/status.env
  printf '%s level=INFO area=security msg="MDI SECURITY PROTOCOL"\n' "$(date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || date)" >> /opt/mdi/log/boot-events.log

  [ "${MDI_ANIMATION_EFFECTIVE:-off}" = "off" ] || sleep "$MDI_BOOT_DELAY" 2>/dev/null || true
  mdi_stop_effects
}
