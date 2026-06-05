```bash
cat > /root/mdi-v1-full.sh <<'EOF'
#!/bin/sh
set -eu

TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/opt/mdi/backups"
BACKUP_TAR="$BACKUP_DIR/opt-mdi-before-v1-$TS.tar.gz"

mkdir -p \
  "$BACKUP_DIR" \
  /opt/mdi/bin \
  /opt/mdi/boot \
  /opt/mdi/tui \
  /opt/mdi/state \
  /opt/mdi/log \
  /opt/mdi/art

tar -czf "$BACKUP_TAR" /opt/mdi 2>/dev/null || {
  echo "Backup failed. Refusing to continue."
  exit 1
}

cat > /opt/mdi/state/ui-settings.env <<'SETTINGS'
MDI_THEME=cyan
MDI_SPEED=normal
MDI_BOOT_STYLE=security
MDI_VERBOSITY=compact
MDI_WARN_PROCEED=yes
MDI_ANIMATION=on
SETTINGS

cat > /opt/mdi/tui/theme.sh <<'THEME'
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
THEME

cat > /opt/mdi/tui/anim.sh <<'ANIM'
#!/bin/sh
. /opt/mdi/tui/theme.sh

trap 'mdi_reset; mdi_show_cursor; mdi_clear; exit 130' INT TERM
trap 'mdi_reset; mdi_show_cursor' EXIT

SESSION_ID=""
SESSION_PREV_HASH=""

mdi_hash() {
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | awk '{print $1}'
  elif command -v sha1sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha1sum | awk '{print $1}'
  else
    printf '%s' "$1" | cksum | awk '{print $1}'
  fi
}

mdi_event_chain() {
  LEVEL="$1"
  AREA="$2"
  MSG="$3"
  TS_NOW="$(date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || date)"
  ROW="$TS_NOW|$LEVEL|$AREA|$MSG|$SESSION_PREV_HASH"
  H="$(mdi_hash "$ROW")"
  SESSION_PREV_HASH="$H"
  printf '%s|%s|%s|%s|%s\n' "$TS_NOW" "$LEVEL" "$AREA" "$MSG" "$H" >> /opt/mdi/log/boot-integrity.log
}

mdi_stage_log_line() {
  TXT="$1"
  mdi_clear
  printf '%b%s%b\n' "$BOLD$WHITE" "$TXT" "$RST"
  mdi_event_chain INFO stage "$TXT"
  mdi_sleep 0.35
  mdi_clear
}

mdi_stage_seal() {
  STAGE="$1"
  DATA="$2"
  H="$(mdi_hash "$SESSION_ID|$STAGE|$DATA|$SESSION_PREV_HASH")"
  printf '%s=%s\n' "$STAGE" "$H" >> /opt/mdi/state/boot-seals.env
  mdi_event_chain INFO "seal_$STAGE" "$H"
}

mdi_stage_verify() {
  STAGE="$1"
  grep -q "^${STAGE}=" /opt/mdi/state/boot-seals.env 2>/dev/null
}

mdi_boot_session_init() {
  : > /opt/mdi/log/startup.log
  : > /opt/mdi/log/boot-events.log
  : > /opt/mdi/log/boot-integrity.log
  : > /opt/mdi/state/boot-seals.env
  CNT_FILE="/opt/mdi/state/boot-counter"
  CNT=0
  [ -f "$CNT_FILE" ] && CNT="$(cat "$CNT_FILE" 2>/dev/null || printf '0')"
  CNT=$((CNT+1))
  printf '%s\n' "$CNT" > "$CNT_FILE"
  C="$(mdi_term_cols)"
  R="$(mdi_term_rows)"
  SESSION_ID="$(date +%Y%m%d%H%M%S)-$CNT-$$"
  SESSION_PREV_HASH="$(mdi_hash "$SESSION_ID|$C|$R|$(hostname 2>/dev/null || printf 'host')")"
  mdi_event_chain INFO session "session_init id=$SESSION_ID cols=$C rows=$R count=$CNT"
}

mdi_mdi_logo_gold() {
  GOLD="$(printf '\033[1;38;5;220m')"
  printf '%b' "$GOLD"
  cat <<'MDI'
    __  __  ____   ___
   |  \/  ||  _ \ |_ _|
   | |\/| || | | | | |
   | |  | || |_| | | |
   |_|  |_||____/ |___|
  M D I   T E   W H E K E
MDI
  printf '%b' "$RST"
}

mdi_kaihaumaru_lock() {
  printf '\033[1;31m'
  cat <<'LOCK'
        .------------.
       /  .--------.  \
      /  /  ____    \  \
      |  | | __ |   |  |
      |  | ||  ||   |  |
      |  | ||__||   |  |
      |  |  ____    |  |
      |  | |____|   |  |
      |  '----------'  |
      '----------------'
LOCK
  printf '%b' "$RST"
}

mdi_wheke_logo() {
  printf '%b' "$CYAN"
  cat <<'WHEKE'
            (o_^_o)
         .--/( 8 )\--.
       _/   /_/ \_\   \_
      /_   /  ___  \   _\
        \_/  /___\  \_/
         /___/   \___\
          T E  W H E K E
WHEKE
  printf '%b' "$RST"
}

mdi_wm_bounds() {
  C="$(mdi_term_cols)"
  R="$(mdi_term_rows)"
  [ "$C" -lt 80 ] && return 1
  [ "$R" -lt 24 ] && return 1
  WM_COL=2
  WM_ROW=$((R-5))
  return 0
}

mdi_wm_clear() {
  mdi_wm_bounds || return 0
  i=0
  while [ "$i" -lt 4 ]; do
    mdi_move $((WM_ROW+i)) "$WM_COL"
    printf '              '
    i=$((i+1))
  done
}

mdi_wm_tick() {
  FRAME="$1"
  mdi_wm_bounds || return 0
  mdi_wm_clear
  mdi_move "$WM_ROW" "$WM_COL"
  case "$FRAME" in
    0) printf '%b<(o_v )>%b' "$CYAN" "$RST" ;;
    1) printf '%b<(-_o)>%b' "$CYAN" "$RST" ;;
    *) printf '%b(o_^_o)%b' "$CYAN" "$RST" ;;
  esac
  mdi_move $((WM_ROW+1)) "$WM_COL"; printf '%bWHEKEOS LOADER%b' "$DIM" "$RST"
}

mdi_matrix_bounds() {
  COLS="$(mdi_term_cols)"
  ROWS="$(mdi_term_rows)"
  [ "$COLS" -lt 90 ] && return 1
  [ "$ROWS" -lt 22 ] && return 1
  MATRIX_COL_1=$((COLS - 10))
  MATRIX_COL_2=$((COLS - 7))
  MATRIX_COL_3=$((COLS - 4))
  MATRIX_ROW_START=2
  MATRIX_ROW_END=$((ROWS - 3))
  return 0
}

mdi_matrix_clear_layer() {
  mdi_matrix_bounds || return 0
  row="$MATRIX_ROW_START"
  while [ "$row" -le "$MATRIX_ROW_END" ]; do
    mdi_move "$row" "$MATRIX_COL_1"; printf ' '
    mdi_move "$row" "$MATRIX_COL_2"; printf ' '
    mdi_move "$row" "$MATRIX_COL_3"; printf ' '
    row=$((row + 1))
  done
}

mdi_fx_matrix_sidefall() {
  mdi_matrix_bounds || return 0
  CHARS='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ@#$%*+=-'
  LEN=44
  frame=1
  while [ "$frame" -le 16 ]; do
    row="$MATRIX_ROW_START"
    while [ "$row" -le "$MATRIX_ROW_END" ]; do
      i1=$(( (frame + row) % LEN + 1 ))
      i2=$(( (frame + row + 9) % LEN + 1 ))
      i3=$(( (frame + row + 17) % LEN + 1 ))
      c1="$(printf '%s' "$CHARS" | cut -c "$i1")"
      c2="$(printf '%s' "$CHARS" | cut -c "$i2")"
      c3="$(printf '%s' "$CHARS" | cut -c "$i3")"
      mdi_move "$row" "$MATRIX_COL_1"; printf '\033[38;5;52m%s%b' "$c1" "$RST"
      if [ "$row" -gt "$((MATRIX_ROW_START + 2))" ]; then
        mdi_move "$row" "$MATRIX_COL_2"; printf '\033[38;5;196m%s%b' "$c2" "$RST"
      fi
      if [ "$row" -gt "$((MATRIX_ROW_START + 5))" ]; then
        mdi_move "$row" "$MATRIX_COL_3"; printf '\033[38;5;88m%s%b' "$c3" "$RST"
      fi
      row=$((row + 1))
    done
    mdi_sleep 0.05
    mdi_matrix_clear_layer
    frame=$((frame + 1))
  done
  mdi_matrix_clear_layer
}

mdi_phase_mdi_boot() {
  mdi_clear
  mdi_phase_rule "STAGE 1 / MDI"
  mdi_mdi_logo_gold
  mdi_sleep 0.35
  mdi_stage_log_line "[MDI] identity authority detected"
  mdi_stage_log_line "[MDI] startup attestation initialised"
  mdi_stage_log_line "[MDI] handoff approved: Kaihaumaru"
  mdi_stage_seal "stage1" "mdi_ok"
}

mdi_phase_kaihaumaru_boot() {
  mdi_clear
  mdi_phase_rule "STAGE 2 / KAIHAUMARU"
  mdi_kaihaumaru_lock
  mdi_sleep 0.30
  mdi_stage_log_line "[KAIHAUMARU] perimeter seal initialised"
  mdi_kaihaumaru_lock
  mdi_sleep 0.25
  mdi_stage_log_line "[KAIHAUMARU] runtime hardening active"
  mdi_kaihaumaru_lock
  mdi_sleep 0.25
  mdi_stage_log_line "[KAIHAUMARU] policy gate passed"
  mdi_stage_log_line "[KAIHAUMARU] handoff approved: WhekeOS"
  mdi_stage_seal "stage2" "kaihaumaru_ok"
}

mdi_phase_whekeos_boot() {
  mdi_stage_verify "stage2" || mdi_stage_log_line "[WHEKEOS] stage2 verification failed"
  mdi_clear
  mdi_phase_rule "STAGE 3 / WHEKEOS"
  mdi_wheke_logo
  n=0
  while [ "$n" -lt 6 ]; do
    mdi_wm_tick $((n % 3))
    mdi_sleep 0.12
    n=$((n+1))
  done
  mdi_stage_log_line "[WHEKEOS] local runtime path verified"
  mdi_stage_log_line "[WHEKEOS] local mesh loader passed"
  mdi_safe_call mdi_fx_matrix_sidefall
  mdi_wm_clear
  mdi_stage_log_line "[WHEKEOS] handoff approved: interface"
  mdi_stage_seal "stage3" "whekeos_ok"
}

mdi_phase_interface_handoff() {
  mdi_reset
  mdi_show_cursor
  mdi_clear
  printf '%b%s%b\n' "$BOLD$WHITE" "[SYSTEM] terminal handoff ready" "$RST"
  printf '%brangatira%b%b@%b%bmaori_dev%b%b~$ %b\n' "$GREEN" "$RST" "$MAGENTA" "$RST" "$CYAN" "$RST" "$WHITE" "$RST"
  mdi_boot_log INFO interface "interface handoff complete"
}

mdi_intro_sequence() {
  mdi_hide_cursor
  mdi_boot_session_init
  case "$MDI_BOOT_STYLE" in
    minimal)
      mdi_phase_mdi_boot
      mdi_phase_interface_handoff
      ;;
    fast)
      mdi_phase_mdi_boot
      mdi_phase_kaihaumaru_boot
      mdi_phase_interface_handoff
      ;;
    cinematic|security|*)
      mdi_phase_mdi_boot
      mdi_phase_kaihaumaru_boot
      mdi_phase_whekeos_boot
      mdi_phase_interface_handoff
      ;;
  esac
}

mdi_transition() {
  LABEL="$1"
  printf '\n'
  mdi_orbit "$LABEL" 8
  printf '\n'
}
ANIM

cat > /opt/mdi/boot/01-logo.sh <<'LOGO'
#!/bin/sh
. /opt/mdi/tui/anim.sh

mdi_intro_sequence
mdi_boot_log INFO boot "visual boot sequence complete"
LOGO

cat > /opt/mdi/boot/02-checks.sh <<'CHECKS'
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
CHECKS

cat > /opt/mdi/boot/03-login.sh <<'LOGIN'
#!/bin/sh
. /opt/mdi/tui/theme.sh

mdi_transition "booting MDI user interface"

mdi_panel \
  "MDI USER INTERFACE" \
  "User       rangatira" \
  "Prompt     rangatira@maori_dev~$" \
  "Input      green" \
  "Output     severity/theme coloured" \
  "Menus      help / settings / themes / boot"

printf '\n'
mdi_type "binding coloured operator prompt" 0.006
mdi_type "loading command surface and response channels" 0.006
printf '\n'
LOGIN

cat > /opt/mdi/bin/mdi-status <<'STATUS'
#!/bin/sh
. /opt/mdi/tui/theme.sh

mdi_title "MDI STATUS"

if [ -f /opt/mdi/state/status.env ]; then
  sed 's/^/  /' /opt/mdi/state/status.env
else
  printf '  no status file\n'
fi

printf '\n'
mdi_title "DEVICE"

if [ -f /opt/mdi/state/device-info.txt ]; then
  sed 's/^/  /' /opt/mdi/state/device-info.txt
else
  printf '  no device file\n'
fi

printf '\n'
mdi_title "UI SETTINGS"

if [ -f /opt/mdi/state/ui-settings.env ]; then
  sed 's/^/  /' /opt/mdi/state/ui-settings.env
else
  printf '  no ui settings file\n'
fi
STATUS

cat > /opt/mdi/bin/mdi-session <<'SESSION'
#!/bin/sh
. /opt/mdi/tui/theme.sh

save_setting() {
  KEY="$1"
  VALUE="$2"
  TMP="/opt/mdi/state/ui-settings.env.tmp"

  grep -v "^${KEY}=" /opt/mdi/state/ui-settings.env 2>/dev/null > "$TMP" || true
  printf '%s=%s\n' "$KEY" "$VALUE" >> "$TMP"
  mv "$TMP" /opt/mdi/state/ui-settings.env

  mdi_session_log "setting $KEY=$VALUE"
  mdi_out_ok "Saved: $KEY=$VALUE"
  mdi_out_info "Run redraw to apply the visual change."
}

show_help() {
  mdi_out_menu "COMMANDS"
  printf '  %bhelp%b       command menu\n' "$GREEN" "$RST"
  printf '  %bstatus%b     current status\n' "$GREEN" "$RST"
  printf '  %blogs%b       compact boot log\n' "$GREEN" "$RST"
  printf '  %bevents%b     structured boot events\n' "$GREEN" "$RST"
  printf '  %bsettings%b   settings submenu\n' "$GREEN" "$RST"
  printf '  %bthemes%b     colour theme menu\n' "$GREEN" "$RST"
  printf '  %bboot%b       boot phase/style menu\n' "$GREEN" "$RST"
  printf '  %bredraw%b     redraw full boot surface\n' "$GREEN" "$RST"
  printf '  %bshell%b      raw Alpine shell\n' "$GREEN" "$RST"
  printf '  %bexit%b       leave MDI\n' "$GREEN" "$RST"
}

show_logs() {
  mdi_out_menu "BOOT LOG"
  mdi_hr
  [ -f /opt/mdi/log/boot-checks.log ] && cat /opt/mdi/log/boot-checks.log || mdi_out_warn "No boot log found."
}

show_events() {
  mdi_out_menu "BOOT EVENTS"
  mdi_hr
  [ -f /opt/mdi/log/boot-events.log ] && tail -n 80 /opt/mdi/log/boot-events.log || mdi_out_warn "No event log found."
}

show_themes() {
  mdi_out_menu "COLOUR THEMES"
  mdi_hr
  printf '%-10s %s\n' "cyan" "professional blue/cyan"
  printf '%-10s %s\n' "green" "legacy profile"
  printf '%-10s %s\n' "amber" "classic command terminal"
  printf '%-10s %s\n' "red" "sentinel alert surface"
  printf '%-10s %s\n' "violet" "purple high-contrast"
  printf '%-10s %s\n' "ice" "white/blue cold console"
  printf '%-10s %s\n' "mono" "minimal monochrome"
  printf '%-10s %s\n' "stealth" "dim covert green"
  printf '\n'
  mdi_out_info "Use: set theme <name>"
}

show_boot_styles() {
  mdi_out_menu "BOOT PHASES"
  mdi_hr
  printf '%b1. MDI%b\n' "$GREEN" "$RST"
  printf '   Identity authority and startup attestation.\n\n'
  printf '%b2. KAIHAUMARU%b\n' "$RED" "$RST"
  printf '   Isolated security authority and hardening seal.\n\n'
  printf '%b3. WHEKEOS%b\n' "$CYAN" "$RST"
  printf '   Local runtime mesh, watermark loader, matrix sidefall.\n\n'
  printf '%b4. INTERFACE HANDOFF%b\n' "$WHITE" "$RST"
  printf '   Clean terminal handoff and operator prompt.\n\n'

  mdi_out_menu "BOOT STYLES"
  mdi_hr
  printf '%-12s %s\n' "security" "full four-stage boot"
  printf '%-12s %s\n' "cinematic" "full four-stage boot"
  printf '%-12s %s\n' "fast" "MDI + Kaihaumaru + handoff"
  printf '%-12s %s\n' "minimal" "MDI + handoff"
  printf '\n'
  mdi_out_info "Use: set boot <style>"
}

show_settings() {
  mdi_out_menu "SETTINGS"
  mdi_hr
  printf '%-14s %s\n' "theme" "$MDI_THEME"
  printf '%-14s %s\n' "speed" "$MDI_SPEED"
  printf '%-14s %s\n' "boot" "$MDI_BOOT_STYLE"
  printf '%-14s %s\n' "verbosity" "$MDI_VERBOSITY"
  printf '%-14s %s\n' "warn-proceed" "$MDI_WARN_PROCEED"
  printf '%-14s %s\n' "animation" "$MDI_ANIMATION"
  printf '\n'

  mdi_out_menu "SET COMMANDS"
  printf '  set theme cyan|green|amber|red|violet|ice|mono|stealth\n'
  printf '  set speed fast|normal|slow|cinematic\n'
  printf '  set boot security|cinematic|fast|minimal\n'
  printf '  set verbosity quiet|compact|debug\n'
  printf '  set warn yes|no\n'
  printf '  set animation on|off\n'
}

draw_session() {
  mdi_out_menu "MDI USER INTERFACE"
  mdi_hr

  mdi_panel \
    "MDI CONTROL SURFACE" \
    "prompt     rangatira@maori_dev~$" \
    "input      green" \
    "output     severity/theme coloured" \
    "help       command menu" \
    "settings   UI settings" \
    "themes     colour schemes" \
    "boot       phase/style menu" \
    "shell      raw Alpine shell"

  printf '\n'
}

draw_session

while true; do
  mdi_prompt
  IFS= read -r CMD || {
    mdi_reset_line
    exit 0
  }
  mdi_reset_line

  mdi_session_log "cmd=$CMD"

  case "$CMD" in
    "" )
      ;;
    help|-h|--help )
      show_help
      ;;
    status )
      /opt/mdi/bin/mdi-status
      ;;
    logs|log )
      show_logs
      ;;
    events|event )
      show_events
      ;;
    settings|config )
      show_settings
      ;;
    themes|theme )
      show_themes
      ;;
    boot|bootstyle )
      show_boot_styles
      ;;
    redraw|clear )
      mdi_clear
      /opt/mdi/boot/01-logo.sh
      /opt/mdi/boot/02-checks.sh
      /opt/mdi/boot/03-login.sh
      draw_session
      ;;
    shell|sh )
      mdi_out_shell "Entering raw Alpine shell. Type exit to return."
      /bin/sh
      draw_session
      ;;
    exit|quit )
      mdi_out_info "Leaving MDI user interface."
      exit 0
      ;;
    set\ theme\ * )
      V="$(printf '%s' "$CMD" | awk '{print $3}')"
      case "$V" in cyan|green|amber|red|violet|ice|mono|stealth) save_setting MDI_THEME "$V" ;; *) mdi_out_error "Invalid theme." ;; esac
      ;;
    set\ speed\ * )
      V="$(printf '%s' "$CMD" | awk '{print $3}')"
      case "$V" in fast|normal|slow|cinematic) save_setting MDI_SPEED "$V" ;; *) mdi_out_error "Invalid speed." ;; esac
      ;;
    set\ boot\ * )
      V="$(printf '%s' "$CMD" | awk '{print $3}')"
      case "$V" in security|cinematic|fast|minimal) save_setting MDI_BOOT_STYLE "$V" ;; *) mdi_out_error "Invalid boot style." ;; esac
      ;;
    set\ verbosity\ * )
      V="$(printf '%s' "$CMD" | awk '{print $3}')"
      case "$V" in quiet|compact|debug) save_setting MDI_VERBOSITY "$V" ;; *) mdi_out_error "Invalid verbosity." ;; esac
      ;;
    set\ warn\ * )
      V="$(printf '%s' "$CMD" | awk '{print $3}')"
      case "$V" in yes|no) save_setting MDI_WARN_PROCEED "$V" ;; *) mdi_out_error "Invalid warn setting." ;; esac
      ;;
    set\ animation\ * )
      V="$(printf '%s' "$CMD" | awk '{print $3}')"
      case "$V" in on|off) save_setting MDI_ANIMATION "$V" ;; *) mdi_out_error "Invalid animation setting." ;; esac
      ;;
    * )
      mdi_out_warn "Unknown MDI command. Run: help"
      ;;
  esac
done
SESSION

cat > /opt/mdi/bin/mdi-boot <<'BOOT'
#!/bin/sh
set -eu

/opt/mdi/boot/01-logo.sh
/opt/mdi/boot/02-checks.sh
/opt/mdi/boot/03-login.sh
exec /opt/mdi/bin/mdi-session
BOOT

cat > /opt/mdi/tui/main.sh <<'MAIN'
#!/bin/sh
exec /opt/mdi/bin/mdi-session
MAIN

cat > /opt/mdi/tui/mdi-start <<'START'
#!/bin/sh
exec /opt/mdi/bin/mdi-boot
START

cat > /opt/mdi/backups/RESTORE-LAST-BEFORE-MDI-V1.sh <<RESTORE
#!/bin/sh
set -eu
tar -xzf "$BACKUP_TAR" -C /
chmod +x /opt/mdi/bin/* /opt/mdi/boot/*.sh /opt/mdi/tui/*.sh 2>/dev/null || true
echo "Restored from $BACKUP_TAR"
RESTORE

chmod +x /opt/mdi/tui/theme.sh
chmod +x /opt/mdi/tui/anim.sh
chmod +x /opt/mdi/boot/01-logo.sh
chmod +x /opt/mdi/boot/02-checks.sh
chmod +x /opt/mdi/boot/03-login.sh
chmod +x /opt/mdi/bin/mdi-boot
chmod +x /opt/mdi/bin/mdi-session
chmod +x /opt/mdi/bin/mdi-status
chmod +x /opt/mdi/tui/main.sh
chmod +x /opt/mdi/tui/mdi-start
chmod +x /opt/mdi/backups/RESTORE-LAST-BEFORE-MDI-V1.sh

sh -n /opt/mdi/tui/theme.sh
sh -n /opt/mdi/tui/anim.sh
sh -n /opt/mdi/boot/01-logo.sh
sh -n /opt/mdi/boot/02-checks.sh
sh -n /opt/mdi/boot/03-login.sh
sh -n /opt/mdi/bin/mdi-boot
sh -n /opt/mdi/bin/mdi-session
sh -n /opt/mdi/bin/mdi-status
sh -n /opt/mdi/tui/main.sh
sh -n /opt/mdi/tui/mdi-start

echo
echo "MDI v1 installed."
echo "Backup:"
echo "$BACKUP_TAR"
echo
echo "Rollback:"
echo "/opt/mdi/backups/RESTORE-LAST-BEFORE-MDI-V1.sh"
echo
echo "Run:"
echo "/opt/mdi/bin/mdi-boot"
EOF

chmod +x /root/mdi-v1-full.sh
/root/mdi-v1-full.sh

```
