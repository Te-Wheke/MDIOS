#!/bin/sh

mdi_prompt_print() {
  if [ "${MDI_COLOR:-0}" -eq 1 ]; then
    printf '%srangatira%s' "$GREEN" "$RST"
    printf '%s@%s' "$MAGENTA" "$RST"
    printf '%smaori_dev%s' "$BLUE" "$RST"
    printf '%s~$ %s' "$WHITE" "$RST"
  else
    printf 'rangatira@maori_dev~$ '
  fi
}

mdi_control_draw() {
  mdi_screen_contract
  mdi_assets_discover
  mdi_stop_effects
  mdi_show_cursor
  mdi_wrap_off
  mdi_clear_screen
  mdi_region_clear "$HEADER_TOP" "$HEADER_LEFT" "$HEADER_WIDTH" "$HEADER_HEIGHT"
  mdi_region_clear "$MAIN_TOP" "$MAIN_LEFT" "$MDI_COLS" "$MAIN_HEIGHT"
  mdi_region_clear "$STATUS_TOP" "$STATUS_LEFT" "$STATUS_WIDTH" "$STATUS_HEIGHT"
  mdi_draw_center "$HEADER_TOP" "$HEADER_LEFT" "$HEADER_WIDTH" "$HEADER_HEIGHT" 1 "MDI CONTROL SURFACE" "$CYAN"

  base=1
  mdi_draw_center "$MAIN_TOP" "$MAIN_LEFT" "$MDI_COLS" "$MAIN_HEIGHT" "$base" "-------------------" "$DIM"
  base=$((base + 2))
  mdi_draw_text "$MAIN_TOP" "$MAIN_LEFT" "$MDI_COLS" "$MAIN_HEIGHT" "$base" 2 "SYSTEM    READY" "$WHITE"
  base=$((base + 1))
  mdi_draw_text "$MAIN_TOP" "$MAIN_LEFT" "$MDI_COLS" "$MAIN_HEIGHT" "$base" 2 "SECURITY  LOCKED" "$WHITE"
  base=$((base + 1))
  mdi_draw_text "$MAIN_TOP" "$MAIN_LEFT" "$MDI_COLS" "$MAIN_HEIGHT" "$base" 2 "NETWORK   OFFLINE" "$WHITE"
  base=$((base + 1))
  mdi_draw_text "$MAIN_TOP" "$MAIN_LEFT" "$MDI_COLS" "$MAIN_HEIGHT" "$base" 2 "MODE      TUI" "$WHITE"
  base=$((base + 2))
  mdi_draw_text "$MAIN_TOP" "$MAIN_LEFT" "$MDI_COLS" "$MAIN_HEIGHT" "$base" 2 "COMMANDS" "$CYAN"
  base=$((base + 1))
  mdi_draw_text "$MAIN_TOP" "$MAIN_LEFT" "$MDI_COLS" "$MAIN_HEIGHT" "$base" 2 "help   status   theme   shell   exit" "$WHITE"
  mdi_move "$FOOTER_TOP" 1
}

mdi_control_help() {
  printf 'help   status   theme   shell   exit\n'
}

mdi_control_status() {
  if [ -x /opt/mdi/bin/mdi-status ]; then
    /opt/mdi/bin/mdi-status
  else
    printf 'SYSTEM    READY\n'
    printf 'SECURITY  LOCKED\n'
    printf 'NETWORK   OFFLINE\n'
    printf 'MODE      TUI\n'
  fi
}

mdi_control_theme() {
  printf 'theme %s\n' "${MDI_THEME:-cyan}"
}

mdi_control_shell() {
  mdi_stop_effects
  mdi_reset_terminal
  mdi_show_cursor
  if [ -t 0 ] && [ -t 1 ]; then
    printf '/bin/sh\n'
    /bin/sh
    mdi_control_draw
  else
    printf '/bin/sh\n'
  fi
}

mdi_phase_control() {
  mdi_control_draw
  while :; do
    mdi_prompt_print
    IFS= read -r cmd || {
      mdi_reset_terminal
      mdi_show_cursor
      return 0
    }
    printf '%s' "$RST"
    case "$cmd" in
      "" ) ;;
      help|-h|--help) mdi_control_help ;;
      status) mdi_control_status ;;
      theme|themes) mdi_control_theme ;;
      shell|sh) mdi_control_shell ;;
      exit|quit) mdi_reset_terminal; mdi_show_cursor; return 0 ;;
      *) printf 'WARN  help\n' ;;
    esac
  done
}
