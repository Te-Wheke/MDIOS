#!/bin/sh

mdi_screen_contract() {
  mdi_terminal_detect
  mdi_apply_theme_default

  HEADER_TOP=1
  HEADER_LEFT=1
  HEADER_WIDTH="$MDI_COLS"
  HEADER_HEIGHT=2
  [ "$MDI_PROFILE" = "ultra-compact" ] && HEADER_HEIGHT=1

  FOOTER_HEIGHT=1
  STATUS_HEIGHT=4
  [ "$MDI_PROFILE" = "ultra-compact" ] && STATUS_HEIGHT=2
  [ "$MDI_PROFILE" = "desktop" ] && STATUS_HEIGHT=5

  FOOTER_TOP="$MDI_ROWS"
  STATUS_TOP=$((MDI_ROWS - FOOTER_HEIGHT - STATUS_HEIGHT + 1))
  [ "$STATUS_TOP" -lt $((HEADER_TOP + HEADER_HEIGHT + 4)) ] && STATUS_TOP=$((MDI_ROWS - STATUS_HEIGHT))
  [ "$STATUS_TOP" -lt 3 ] && STATUS_TOP=3

  MAIN_TOP=$((HEADER_TOP + HEADER_HEIGHT))
  MAIN_LEFT=1
  MAIN_HEIGHT=$((STATUS_TOP - MAIN_TOP))
  [ "$MAIN_HEIGHT" -lt 1 ] && MAIN_HEIGHT=1

  EFFECT_WIDTH=0
  case "$MDI_PROFILE" in
    tablet|desktop)
      EFFECT_WIDTH=$((MDI_COLS / 5))
      [ "$EFFECT_WIDTH" -lt 14 ] && EFFECT_WIDTH=14
      [ "$EFFECT_WIDTH" -gt 24 ] && EFFECT_WIDTH=24
      ;;
    phone)
      if [ "$MDI_COLS" -ge 70 ] && [ "$MDI_ROWS" -ge 20 ]; then
        EFFECT_WIDTH=12
      fi
      ;;
  esac
  [ "$MDI_ANIMATION_EFFECTIVE" = "off" ] && EFFECT_WIDTH=0

  EFFECT_TOP="$MAIN_TOP"
  EFFECT_HEIGHT="$MAIN_HEIGHT"
  EFFECT_LEFT=$((MDI_COLS - EFFECT_WIDTH + 1))
  [ "$EFFECT_WIDTH" -lt 8 ] && EFFECT_WIDTH=0
  if [ "$EFFECT_WIDTH" -eq 0 ]; then
    EFFECT_LEFT=0
  fi

  MAIN_WIDTH="$MDI_COLS"
  if [ "$EFFECT_WIDTH" -gt 0 ]; then
    MAIN_WIDTH=$((MDI_COLS - EFFECT_WIDTH))
  fi
  [ "$MAIN_WIDTH" -lt 1 ] && MAIN_WIDTH=1

  STATUS_LEFT=1
  STATUS_WIDTH="$MDI_COLS"
  FOOTER_LEFT=1
  FOOTER_WIDTH="$MDI_COLS"
}
