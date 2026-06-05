#!/bin/sh

SETTINGS="/opt/mdi/state/ui-settings.env"
[ -f "$SETTINGS" ] && . "$SETTINGS"

MDI_THEME="${MDI_THEME:-cyan}"
MDI_SPEED="${MDI_SPEED:-normal}"
MDI_BOOT_STYLE="${MDI_BOOT_STYLE:-security}"
MDI_VERBOSITY="${MDI_VERBOSITY:-compact}"
MDI_WARN_PROCEED="${MDI_WARN_PROCEED:-yes}"
MDI_ANIMATION="${MDI_ANIMATION:-on}"

ESC="$(printf '\033')"
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

case "$MDI_THEME" in
  green|matrix)
    PRIMARY="$GREEN"
    SECONDARY="${ESC}[0;32m"
    ACCENT="$CYAN"
    SOFT="${ESC}[0;32m"
    ;;
  amber|terminal)
    PRIMARY="$YELLOW"
    SECONDARY="${ESC}[0;33m"
    ACCENT="$WHITE"
    SOFT="${ESC}[0;33m"
    ;;
  red|sentinel)
    PRIMARY="$RED"
    SECONDARY="${ESC}[0;31m"
    ACCENT="$YELLOW"
    SOFT="${ESC}[0;31m"
    ;;
  violet|purple)
    PRIMARY="$MAGENTA"
    SECONDARY="${ESC}[0;35m"
    ACCENT="$CYAN"
    SOFT="${ESC}[0;35m"
    ;;
  ice)
    PRIMARY="$WHITE"
    SECONDARY="$CYAN"
    ACCENT="$BLUE"
    SOFT="${ESC}[0;37m"
    ;;
  mono)
    PRIMARY="$WHITE"
    SECONDARY="$DIM"
    ACCENT="$WHITE"
    SOFT="$DIM"
    ;;
  stealth)
    PRIMARY="${ESC}[0;32m"
    SECONDARY="$DIM"
    ACCENT="$GREEN"
    SOFT="$DIM"
    ;;
  cyan|blue|*)
    PRIMARY="$CYAN"
    SECONDARY="${ESC}[0;36m"
    ACCENT="$BLUE"
    SOFT="${ESC}[0;34m"
    ;;
esac

mdi_delay() {
  case "$MDI_SPEED" in
    fast) printf '0.010' ;;
    slow) printf '0.070' ;;
    cinematic) printf '0.100' ;;
    *) printf '0.035' ;;
  esac
}

mdi_sleep() {
  sleep "${1:-$(mdi_delay)}" 2>/dev/null || true
}

mdi_clear() {
  printf '\033[2J\033[H'
}

mdi_reset() {
  printf '\033[0m'
}

mdi_hide_cursor() {
  printf '\033[?25l'
}

mdi_show_cursor() {
  printf '\033[?25h'
}

mdi_move() {
  printf '\033[%s;%sH' "$1" "$2"
}

mdi_clear_line() {
  printf '\033[2K'
}

mdi_term_cols() {
  tput cols 2>/dev/null || printf '80'
}

mdi_term_rows() {
  tput lines 2>/dev/null || printf '24'
}

mdi_safe_call() {
  "$@" 2>/dev/null || true
}

mdi_width() {
  C="$(stty size 2>/dev/null | awk '{print $2}')"
  case "$C" in ''|*[!0-9]*) C=42 ;; esac
  [ "$C" -gt 76 ] && C=76
  [ "$C" -lt 38 ] && C=38
  printf '%s' "$C"
}

mdi_hr() {
  W="$(mdi_width)"
  i=0
  printf '%b' "$SECONDARY"
  while [ "$i" -lt "$W" ]; do
    printf '─'
    i=$((i+1))
  done
  printf '%b\n' "$RST"
}

mdi_title() {
  TEXT="$1"
  printf '%b%s%b\n' "$BOLD$PRIMARY" "$TEXT" "$RST"
  mdi_hr
}

mdi_phase_rule() {
  TEXT="$1"
  printf '\n'
  mdi_hr
  printf '%b%s%b\n' "$BOLD$PRIMARY" "$TEXT" "$RST"
  mdi_hr
}

mdi_type() {
  TEXT="$1"
  DELAY="${2:-0.004}"

  if [ "$MDI_ANIMATION" = "off" ]; then
    printf '%s\n' "$TEXT"
    return
  fi

  i=1
  LEN=${#TEXT}

  while [ "$i" -le "$LEN" ]; do
    printf '%s' "$(printf '%s' "$TEXT" | cut -c "$i")"
    sleep "$DELAY" 2>/dev/null || true
    i=$((i+1))
  done

  printf '\n'
}

mdi_panel_top() {
  W="$(mdi_width)"
  INNER=$((W-2))
  printf '%b╭' "$SECONDARY"

  i=0
  while [ "$i" -lt "$INNER" ]; do
    printf '─'
    i=$((i+1))
  done

  printf '╮%b\n' "$RST"
}

mdi_panel_bottom() {
  W="$(mdi_width)"
  INNER=$((W-2))
  printf '%b╰' "$SECONDARY"

  i=0
  while [ "$i" -lt "$INNER" ]; do
    printf '─'
    i=$((i+1))
  done

  printf '╯%b\n' "$RST"
}

mdi_panel_line() {
  TEXT="$1"
  W="$(mdi_width)"
  INNER=$((W-4))
  LEN=${#TEXT}

  if [ "$LEN" -gt "$INNER" ]; then
    TEXT="$(printf '%s' "$TEXT" | cut -c 1-"$INNER")"
    LEN="$INNER"
  fi

  PAD=$((INNER-LEN))

  printf '%b│%b %s' "$SECONDARY" "$RST" "$TEXT"

  i=0
  while [ "$i" -lt "$PAD" ]; do
    printf ' '
    i=$((i+1))
  done

  printf ' %b│%b\n' "$SECONDARY" "$RST"
}

mdi_panel() {
  TITLE="$1"
  shift

  mdi_panel_top
  mdi_panel_line "$TITLE"
  mdi_panel_line ""

  for L in "$@"; do
    mdi_panel_line "$L"
  done

  mdi_panel_bottom
}

mdi_state_colour() {
  case "$1" in
    PASS) printf '%s' "$GREEN" ;;
    WARN) printf '%s' "$YELLOW" ;;
    FAIL) printf '%s' "$RED" ;;
    INFO) printf '%s' "$CYAN" ;;
    LOAD) printf '%s' "$PRIMARY" ;;
    SKIP) printf '%s' "$MAGENTA" ;;
    *) printf '%s' "$WHITE" ;;
  esac
}

mdi_state() {
  LABEL="$1"
  NAME="$2"
  VALUE="$3"
  C="$(mdi_state_colour "$LABEL")"
  printf '%b%-5s%b %-14s %s\n' "$C" "$LABEL" "$RST" "$NAME" "$VALUE"
}

mdi_bar() {
  LABEL="$1"
  VALUE="${2:-100}"
  WIDTH=24
  FILLED=$((VALUE * WIDTH / 100))
  EMPTY=$((WIDTH - FILLED))

  printf '%-14s [' "$LABEL"

  printf '%b' "$PRIMARY"
  i=0
  while [ "$i" -lt "$FILLED" ]; do
    printf '█'
    i=$((i+1))
  done

  printf '%b' "$DIM"
  i=0
  while [ "$i" -lt "$EMPTY" ]; do
    printf '░'
    i=$((i+1))
  done

  printf '%b] %3s%%\n' "$RST" "$VALUE"
}

mdi_orbit() {
  LABEL="$1"
  CYCLES="${2:-10}"

  if [ "$MDI_ANIMATION" = "off" ]; then
    printf '%bLOAD%b  %s\n' "$PRIMARY" "$RST" "$LABEL"
    return
  fi

  FRAMES='|/-\'
  i=0

  while [ "$i" -lt "$CYCLES" ]; do
    POS=$((i % 4 + 1))
    F="$(printf '%s' "$FRAMES" | cut -c "$POS")"
    printf '\r%b[%s]%b %s' "$PRIMARY" "$F" "$RST" "$LABEL"
    mdi_sleep
    i=$((i+1))
  done

  printf '\r%bPASS%b  %s\n' "$GREEN" "$RST" "$LABEL"
}

mdi_boot_log() {
  LEVEL="$1"
  AREA="$2"
  MSG="$3"
  TS_NOW="$(date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || date)"
  printf '%s level=%s area=%s msg="%s"\n' "$TS_NOW" "$LEVEL" "$AREA" "$MSG" >> /opt/mdi/log/boot-events.log
}

mdi_session_log() {
  MSG="$1"
  TS_NOW="$(date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || date)"
  printf '%s %s\n' "$TS_NOW" "$MSG" >> /opt/mdi/log/session.log
}

mdi_os_logo() {
  printf '%b' "$PRIMARY"
  cat <<'LOGO'
        __  __ ____  ___
       |  \/  |  _ \|_ _|
       | |\/| | | | || |
       | |  | | |_| || |
       |_|  |_|____/|___|
LOGO
  printf '%b' "$RST"
}

mdi_logo_small_a() {
  printf '%b       [ MDI ]  local-first security console%b\n' "$PRIMARY" "$RST"
}

mdi_logo_small_b() {
  printf '%b       [ M ]──[ D ]──[ I ]%b\n' "$ACCENT" "$RST"
}

mdi_logo_small_c() {
  printf '%b       MDI://BOOT/SURFACE/READY%b\n' "$PRIMARY" "$RST"
}

mdi_logo_rotate_inline() {
  if [ "$MDI_ANIMATION" = "off" ]; then
    mdi_logo_small_a
    return
  fi

  mdi_logo_small_a
  mdi_sleep 0.12
  printf '\033[1A\033[2K'
  mdi_logo_small_b
  mdi_sleep 0.12
  printf '\033[1A\033[2K'
  mdi_logo_small_c
  mdi_sleep 0.12
  printf '\033[1A\033[2K'
  mdi_logo_small_a
}

mdi_terminal_fill() {
  TITLE="$1"
  A="$2"
  B="$3"
  C="$4"

  mdi_panel "$TITLE" "$A" "$B" "$C"

  W="$(mdi_width)"
  LINE=""
  i=0

  while [ "$i" -lt "$W" ]; do
    case $((i % 6)) in
      0) LINE="${LINE}░" ;;
      1) LINE="${LINE}▒" ;;
      2) LINE="${LINE}▓" ;;
      3) LINE="${LINE}▒" ;;
      4) LINE="${LINE}░" ;;
      *) LINE="${LINE}·" ;;
    esac
    i=$((i+1))
  done

  printf '%b%s%b\n' "$DIM" "$LINE" "$RST"
}

mdi_surface_map() {
  printf '%bLOCAL SURFACE MAP%b\n' "$BOLD" "$RST"
  mdi_hr
  printf '  os-core       ◉──────── starting\n'
  printf '  programmes    ◉──────── preparing\n'
  printf '  security      ○──────── delegated\n'
  printf '  terminal      ○──────── pending\n'
  printf '  logging       ◉──────── compact\n'
  printf '\n'
}

mdi_signal_grid() {
  printf '%bSIGNAL GRID%b\n' "$BOLD" "$RST"
  mdi_hr
  printf '%b' "$DIM"
  printf '  101101  010011  111000  001101  110010\n'
  printf '  011010  111100  000111  101001  010110\n'
  printf '  110001  001011  100101  011100  111001\n'
  printf '  001111  100010  111101  010010  101100\n'
  printf '%b\n' "$RST"
}

mdi_prompt() {
  printf '%brangatira%b' "$GREEN" "$RST"
  printf '%b@%b' "$MAGENTA" "$RST"
  printf '%bmaori_dev%b' "$BLUE" "$RST"
  printf '%b~$ %b' "$WHITE" "$RST"
}

mdi_reset_line() {
  printf '%b' "$RST"
}

mdi_out_info() {
  printf '%bINFO%b  %s\n' "$CYAN" "$RST" "$1"
}

mdi_out_ok() {
  printf '%bPASS%b  %s\n' "$GREEN" "$RST" "$1"
}

mdi_out_warn() {
  printf '%bWARN%b  %s\n' "$YELLOW" "$RST" "$1"
}

mdi_out_error() {
  printf '%bFAIL%b  %s\n' "$RED" "$RST" "$1"
}

mdi_out_shell() {
  printf '%bSHELL%b %s\n' "$MAGENTA" "$RST" "$1"
}

mdi_out_menu() {
  printf '%b%s%b\n' "$PRIMARY" "$1" "$RST"
}

mdi_sec_clear() {
  printf '\033[2J\033[H'
}

mdi_sec_hr() {
  W="$(mdi_width)"
  i=0
  printf '\033[0;31m'
  while [ "$i" -lt "$W" ]; do
    printf '═'
    i=$((i+1))
  done
  printf '\033[0m\n'
}

mdi_sec_header() {
  mdi_sec_clear
  printf '\033[1;31m'
  cat <<'SEC'
      ███╗   ███╗██████╗ ██╗
      ████╗ ████║██╔══██╗██║
      ██╔████╔██║██║  ██║██║
      ██║╚██╔╝██║██║  ██║██║
      ██║ ╚═╝ ██║██████╔╝██║
      ╚═╝     ╚═╝╚═════╝ ╚═╝
SEC
  printf '\033[0m'
  mdi_sec_hr
  printf '\033[1;31m%s\033[0m\n' "ISOLATED SECURITY BOOTLOADER"
  printf '\033[0;31m%s\033[0m\n' "red-zone terminal / hardened startup sequence"
  mdi_sec_hr
  printf '\n'
}

mdi_sec_warning_panel() {
  printf '\n'
  printf '\033[1;31m╔════════════════════════════════════╗\033[0m\n'
  printf '\033[1;31m║ SECURITY BOOT ISOLATION ACTIVE     ║\033[0m\n'
  printf '\033[1;31m╚════════════════════════════════════╝\033[0m\n'
  printf '\033[0;31m%s\033[0m\n' "This phase uses its own visual mode."
  printf '\033[0;31m%s\033[0m\n' "It does not follow the standard OS theme."
  printf '\n'
}

mdi_sec_noise() {
  printf '\033[2m'
  printf '  9f:2a:71  00:ff:13  e4:19:aa  7b:04:91  c0:de:31\n'
  printf '  SIG:LOCK  MEM:SCAN  KEY:SEAL  NET:NULL  ROOT:CHECK\n'
  printf '  11001010  00110111  11100001  01011100  10010011\n'
  printf '\033[0m'
}

mdi_sec_gate() {
  TITLE="$1"
  printf '\n'
  mdi_sec_hr
  printf '\033[1;37m%s\033[0m\n' "$TITLE"
  mdi_sec_hr
}

mdi_sec_scan() {
  LABEL="$1"
  RESULT="${2:-SECURED}"
  CYCLES="${3:-18}"

  i=0
  FRAMES='|/-\'

  while [ "$i" -lt "$CYCLES" ]; do
    POS=$((i % 4 + 1))
    F="$(printf '%s' "$FRAMES" | cut -c "$POS")"

    case $((i % 5)) in
      0) BAR='[■□□□□□□□□□□□□□□]' ;;
      1) BAR='[■■■□□□□□□□□□□□□]' ;;
      2) BAR='[■■■■■■□□□□□□□□□]' ;;
      3) BAR='[■■■■■■■■■■□□□□□]' ;;
      *) BAR='[■■■■■■■■■■■■■■■]' ;;
    esac

    printf '\r\033[1;31m[%s]\033[0m %-24s \033[0;31m%s\033[0m' "$F" "$LABEL" "$BAR"
    mdi_sleep 0.055
    i=$((i+1))
  done

  printf '\r\033[1;37mLOCK\033[0m %-24s \033[1;31m%s\033[0m\n' "$LABEL" "$RESULT"
}

mdi_sec_lock_frame_0() {
  printf '\033[1;31m'
  cat <<'LOCK'
          .--------.
         /  .--.   \
        /  /    \   \
        |  |    |   |
        |  '----'   |
        |  .----.   |
        |  | ██ |   |
        |  '----'   |
        '----------'
LOCK
  printf '\033[0m'
}

mdi_sec_lock_frame_1() {
  printf '\033[1;31m'
  cat <<'LOCK'
          .--------.
        _/  .--.   \_
       /   /    \    \
       |   |    |    |
       |   '----'    |
       |    .--.     |
       |   | ██ |    |
       '---'----'----'
LOCK
  printf '\033[0m'
}

mdi_sec_lock_frame_2() {
  printf '\033[1;37m'
  cat <<'LOCK'
          .--------.
         /  .--.   \
        /  /    \   \
        |  |    |   |
        |  '----'   |
        |   [██]    |
        |   [██]    |
        '----------'
LOCK
  printf '\033[0m'
}

mdi_sec_lock_frame_3() {
  printf '\033[0;31m'
  cat <<'LOCK'
          .--------.
       __/  .--.   \__
      /    /    \     \
      |    |    |     |
      |    '----'     |
      |     <██>      |
      |     <██>      |
      '--------------'
LOCK
  printf '\033[0m'
}

mdi_sec_lock_spin() {
  TITLE="${1:-hardening security core}"
  CYCLES="${2:-2}"

  if [ "$MDI_ANIMATION" = "off" ]; then
    mdi_sec_lock_frame_0
    printf '\033[1;31m%s\033[0m\n' "$TITLE"
    return
  fi

  n=0

  while [ "$n" -lt "$CYCLES" ]; do
    mdi_sec_clear
    mdi_sec_header
    printf '\033[1;37m%s\033[0m\n\n' "$TITLE"
    mdi_sec_lock_frame_0
    printf '\n\033[0;31m%s\033[0m\n' "seal rotation: 000deg | boundary locking"
    mdi_sleep 0.22

    mdi_sec_clear
    mdi_sec_header
    printf '\033[1;37m%s\033[0m\n\n' "$TITLE"
    mdi_sec_lock_frame_1
    printf '\n\033[0;31m%s\033[0m\n' "seal rotation: 090deg | policy binding"
    mdi_sleep 0.22

    mdi_sec_clear
    mdi_sec_header
    printf '\033[1;37m%s\033[0m\n\n' "$TITLE"
    mdi_sec_lock_frame_2
    printf '\n\033[0;31m%s\033[0m\n' "seal rotation: 180deg | state sealing"
    mdi_sleep 0.22

    mdi_sec_clear
    mdi_sec_header
    printf '\033[1;37m%s\033[0m\n\n' "$TITLE"
    mdi_sec_lock_frame_3
    printf '\n\033[0;31m%s\033[0m\n' "seal rotation: 270deg | handoff guarding"
    mdi_sleep 0.22

    n=$((n+1))
  done
}

mdi_sec_lock_pulse() {
  LABEL="$1"
  VALUE="$2"

  mdi_sec_lock_spin "$LABEL" 1
  printf '\n'
  printf '\033[1;37mLOCK\033[0m %-24s \033[1;31m%s\033[0m\n' "$LABEL" "$VALUE"
  mdi_boot_log INFO security_lock "$LABEL $VALUE"
}
