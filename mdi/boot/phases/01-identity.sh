#!/bin/sh

mdi_identity_compact_mark() {
  if [ "$MAIN_WIDTH" -ge 28 ] && [ "$MAIN_HEIGHT" -ge 8 ]; then
    row=$(((MAIN_HEIGHT - 7) / 2 + 1))
    [ "$row" -lt 1 ] && row=1
    mdi_draw_center "$MAIN_TOP" "$MAIN_LEFT" "$MAIN_WIDTH" "$MAIN_HEIGHT" "$row"     "  __  __  ____   ___" "$WHITE"
    row=$((row + 1))
    mdi_draw_center "$MAIN_TOP" "$MAIN_LEFT" "$MAIN_WIDTH" "$MAIN_HEIGHT" "$row"     " |  \/  ||  _ \ |_ _|" "$WHITE"
    row=$((row + 1))
    mdi_draw_center "$MAIN_TOP" "$MAIN_LEFT" "$MAIN_WIDTH" "$MAIN_HEIGHT" "$row"     " | |\/| || | | | | |" "$WHITE"
    row=$((row + 1))
    mdi_draw_center "$MAIN_TOP" "$MAIN_LEFT" "$MAIN_WIDTH" "$MAIN_HEIGHT" "$row"     " | |  | || |_| | | |" "$WHITE"
    row=$((row + 1))
    mdi_draw_center "$MAIN_TOP" "$MAIN_LEFT" "$MAIN_WIDTH" "$MAIN_HEIGHT" "$row"     " |_|  |_||____/ |___|" "$WHITE"
    row=$((row + 2))
    mdi_draw_center "$MAIN_TOP" "$MAIN_LEFT" "$MAIN_WIDTH" "$MAIN_HEIGHT" "$row"     "MAORI DIGITAL INDEPENDANCE" "$CYAN"
    return 0
  fi

  if [ "$MAIN_HEIGHT" -ge 3 ]; then
    row=$(((MAIN_HEIGHT - 2) / 2 + 1))
    [ "$row" -lt 1 ] && row=1
    mdi_draw_center "$MAIN_TOP" "$MAIN_LEFT" "$MAIN_WIDTH" "$MAIN_HEIGHT" "$row" "MDI" "$WHITE"
    row=$((row + 1))
    mdi_draw_center "$MAIN_TOP" "$MAIN_LEFT" "$MAIN_WIDTH" "$MAIN_HEIGHT" "$row" "MAORI DIGITAL INDEPENDANCE" "$CYAN"
    return 0
  fi

  mdi_draw_center "$MAIN_TOP" "$MAIN_LEFT" "$MAIN_WIDTH" "$MAIN_HEIGHT" 1 "MDI" "$WHITE"
}

mdi_phase_identity() {
  mdi_screen_contract
  mdi_assets_discover
  mdi_hide_cursor
  mdi_wrap_off
  mdi_clear_screen
  mdi_region_clear "$HEADER_TOP" "$HEADER_LEFT" "$HEADER_WIDTH" "$HEADER_HEIGHT"
  mdi_region_clear "$MAIN_TOP" "$MAIN_LEFT" "$MAIN_WIDTH" "$MAIN_HEIGHT"
  mdi_region_clear "$STATUS_TOP" "$STATUS_LEFT" "$STATUS_WIDTH" "$STATUS_HEIGHT"
  mdi_draw_center "$HEADER_TOP" "$HEADER_LEFT" "$HEADER_WIDTH" "$HEADER_HEIGHT" 1 "MDI" "$CYAN"
  mdi_identity_compact_mark
  mdi_draw_status 1 "SYSTEM" "[ OK ]" "$GREEN"
  if [ "${MDI_ANIMATION_EFFECTIVE:-off}" != "off" ]; then
    sleep "$MDI_BOOT_DELAY" 2>/dev/null || true
    mdi_draw_status 2 "START CONTROL" "[ OK ]" "$GREEN"
    sleep "$MDI_BOOT_DELAY" 2>/dev/null || true
  else
    mdi_draw_status 2 "START CONTROL" "[ OK ]" "$GREEN"
  fi
  mdi_stop_effects
}
