#!/bin/sh

mdi_cmd() {
  command -v "$1" >/dev/null 2>&1
}

mdi_term_cols_detect() {
  c=""
  if mdi_cmd tput; then
    c="$(tput cols 2>/dev/null || true)"
  fi
  case "$c" in ''|*[!0-9]*)
    c="$(stty size 2>/dev/null | awk '{print $2}' 2>/dev/null || true)"
    ;;
  esac
  case "$c" in ''|*[!0-9]*) c=80 ;; esac
  printf '%s' "$c"
}

mdi_term_rows_detect() {
  r=""
  if mdi_cmd tput; then
    r="$(tput lines 2>/dev/null || true)"
  fi
  case "$r" in ''|*[!0-9]*)
    r="$(stty size 2>/dev/null | awk '{print $1}' 2>/dev/null || true)"
    ;;
  esac
  case "$r" in ''|*[!0-9]*) r=24 ;; esac
  printf '%s' "$r"
}

mdi_terminal_detect() {
  MDI_COLS="$(mdi_term_cols_detect)"
  MDI_ROWS="$(mdi_term_rows_detect)"
  case "$MDI_COLS" in ''|*[!0-9]*) MDI_COLS=80 ;; esac
  case "$MDI_ROWS" in ''|*[!0-9]*) MDI_ROWS=24 ;; esac

  MDI_TPUT=0
  mdi_cmd tput && MDI_TPUT=1

  MDI_COLOR=0
  if [ "$MDI_TPUT" -eq 1 ]; then
    tc="$(tput colors 2>/dev/null || printf '0')"
    case "$tc" in ''|*[!0-9]*) tc=0 ;; esac
    [ "$tc" -ge 8 ] && MDI_COLOR=1
  else
    case "${TERM:-}" in *color*|xterm*|screen*|tmux*) MDI_COLOR=1 ;; esac
  fi
  [ -n "${NO_COLOR:-}" ] && MDI_COLOR=0

  MDI_CURSOR=1
  if [ "$MDI_TPUT" -eq 1 ]; then
    tput civis >/dev/null 2>&1 || MDI_CURSOR=0
    tput cnorm >/dev/null 2>&1 || MDI_CURSOR=0
  fi

  MDI_ANIMATION_EFFECTIVE="${MDI_ANIMATION_EFFECTIVE:-on}"
  [ "${MDI_NO_ANIMATION:-0}" -eq 1 ] && MDI_ANIMATION_EFFECTIVE=off
  [ "${MDI_ANIMATION:-on}" = "off" ] && MDI_ANIMATION_EFFECTIVE=off
  [ ! -t 1 ] && MDI_ANIMATION_EFFECTIVE=off

  if [ -n "${MDI_FORCE_PROFILE:-}" ]; then
    MDI_PROFILE="$MDI_FORCE_PROFILE"
  elif [ "$MDI_COLS" -lt 50 ] || [ "$MDI_ROWS" -lt 18 ]; then
    MDI_PROFILE="ultra-compact"
  elif [ "$MDI_COLS" -ge 100 ] && [ "$MDI_ROWS" -ge 30 ]; then
    MDI_PROFILE="desktop"
  elif [ "$MDI_COLS" -ge 80 ] && [ "$MDI_ROWS" -ge 24 ]; then
    MDI_PROFILE="tablet"
  else
    MDI_PROFILE="phone"
  fi
}

mdi_apply_theme_default() {
  ESC="$(printf '\033')"
  RST=""
  BOLD=""
  DIM=""
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  MAGENTA=""
  CYAN=""
  WHITE=""
  if [ "${MDI_COLOR:-0}" -eq 1 ]; then
    RST="${ESC}[0m"
    BOLD="${ESC}[1m"
    DIM="${ESC}[2m"
    RED="${ESC}[1;31m"
    GREEN="${ESC}[1;32m"
    YELLOW="${ESC}[1;33m"
    BLUE="${ESC}[1;34m"
    MAGENTA="${ESC}[1;35m"
    CYAN="${ESC}[1;36m"
    WHITE="${ESC}[1;37m"
  fi
}

mdi_move() {
  r="$1"
  c="$2"
  case "$r" in ''|*[!0-9]*) r=1 ;; esac
  case "$c" in ''|*[!0-9]*) c=1 ;; esac
  [ "$r" -lt 1 ] && r=1
  [ "$c" -lt 1 ] && c=1
  printf '\033[%s;%sH' "$r" "$c"
}

mdi_clear_screen() {
  printf '\033[2J\033[H'
}

mdi_reset_terminal() {
  printf '\033[0m\033[?7h'
}

mdi_hide_cursor() {
  [ "${MDI_CURSOR:-1}" -eq 1 ] && printf '\033[?25l'
}

mdi_show_cursor() {
  [ "${MDI_CURSOR:-1}" -eq 1 ] && printf '\033[?25h'
}

mdi_wrap_off() {
  printf '\033[?7l'
}

mdi_wrap_on() {
  printf '\033[?7h'
}
