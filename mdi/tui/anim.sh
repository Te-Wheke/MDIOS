#!/bin/sh
. /opt/mdi/tui/theme.sh

SESSION_ID=""
SESSION_PREV_HASH=""
STAGE_LAST_SEAL=""
BOOT_ANIM_PIDS=""
BOOT_CLEANED=0
BOOT_PID_FILE="/opt/mdi/state/boot-animation-pids"
LAYOUT_DEBUG_INIT=0
MDI_MATRIX_PID=""
MDI_OWL_PID=""

mdi_stop_boot_animations() {
  [ "$BOOT_CLEANED" -eq 1 ] && return 0
  BOOT_CLEANED=1

  if [ -f "$BOOT_PID_FILE" ]; then
    while IFS= read -r PID; do
      case "$PID" in
        ''|*[!0-9]*) ;;
        *) kill "$PID" 2>/dev/null || true ;;
      esac
    done < "$BOOT_PID_FILE"
  fi

  for PID in $BOOT_ANIM_PIDS; do
    case "$PID" in
      ''|*[!0-9]*) ;;
      *) kill "$PID" 2>/dev/null || true ;;
    esac
  done

  for PID in $BOOT_ANIM_PIDS; do
    case "$PID" in
      ''|*[!0-9]*) ;;
      *) wait "$PID" 2>/dev/null || true ;;
    esac
  done

  rm -f "$BOOT_PID_FILE" 2>/dev/null || true
}

mdi_stop_boot_animations_soft() {
  # Kill any known background writers without permanently disabling future cleanup.
  # Used to enforce strict stage/layer ownership at stage boundaries.
  old_clean="$BOOT_CLEANED"
  BOOT_CLEANED=0
  mdi_stop_boot_animations
  BOOT_CLEANED="$old_clean"
  # Reset registries for the next stage.
  BOOT_ANIM_PIDS=""
  MDI_MATRIX_PID=""
  MDI_OWL_PID=""
  LOOKOWL_ACTIVE=0
  : > "$BOOT_PID_FILE" 2>/dev/null || true
}

mdi_cleanup_boot() {
  mdi_stop_boot_animations
  mdi_term_wrap_on
  mdi_reset
  mdi_show_cursor
}

trap 'mdi_cleanup_boot; exit 130' INT TERM
trap 'mdi_cleanup_boot' EXIT

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

mdi_short_hash() {
  printf '%s' "$1" | cut -c 1-12
}

mdi_chain_pair() {
  PREV="$(mdi_short_hash "$SESSION_PREV_HASH")"
  NEXT="$(mdi_hash "$SESSION_ID|$1|$SESSION_PREV_HASH")"
  printf 'prev=%s next=%s' "$PREV" "$(mdi_short_hash "$NEXT")"
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
  STAGE_LAST_SEAL="$H"
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

mdi_anim_register() {
  PID="$1"
  case "$PID" in
    ''|*[!0-9]*) return 0 ;;
  esac
  BOOT_ANIM_PIDS="${BOOT_ANIM_PIDS:+$BOOT_ANIM_PIDS }$PID"
  printf '%s\n' "$PID" >> "$BOOT_PID_FILE" 2>/dev/null || true
}

mdi_boot_pause() {
  KIND="${1:-normal}"
  [ "$MDI_ANIMATION" = "off" ] && return 0

  case "$MDI_SPEED:$KIND" in
    fast:short) sleep 0.15 ;;
    fast:normal) sleep 0.30 ;;
    fast:long) sleep 0.45 ;;
    slow:short) sleep 0.55 ;;
    slow:normal) sleep 0.95 ;;
    slow:long) sleep 1.35 ;;
    cinematic:short) sleep 0.65 ;;
    cinematic:normal) sleep 1.05 ;;
    cinematic:long) sleep 1.50 ;;
    *:short) sleep 0.35 ;;
    *:long) sleep 1.05 ;;
    *) sleep 0.75 ;;
  esac 2>/dev/null || true
}

mdi_boot_layout() {
  BOOT_COLS="$(mdi_term_cols)"
  BOOT_ROWS="$(mdi_term_rows)"
  case "$BOOT_COLS" in ''|*[!0-9]*) BOOT_COLS=80 ;; esac
  case "$BOOT_ROWS" in ''|*[!0-9]*) BOOT_ROWS=24 ;; esac

  BOOT_LOG_TOP=$((BOOT_ROWS * 3 / 4 + 1))
  [ "$BOOT_LOG_TOP" -lt 16 ] && BOOT_LOG_TOP=16
  [ "$BOOT_LOG_TOP" -gt $((BOOT_ROWS - 5)) ] && BOOT_LOG_TOP=$((BOOT_ROWS - 5))
  [ "$BOOT_LOG_TOP" -lt 8 ] && BOOT_LOG_TOP=8

  BOOT_MAIN_TOP=1
  BOOT_MAIN_BOTTOM=$((BOOT_LOG_TOP - 2))
  BOOT_LOG_FIRST=$((BOOT_LOG_TOP + 1))
  BOOT_LOG_LAST=$((BOOT_ROWS - 1))
  BOOT_LOG_BOTTOM="$BOOT_ROWS"
  BOOT_LOG_ROW="$BOOT_LOG_FIRST"
}

mdi_term_wrap_off() { printf '\033[?7l' 2>/dev/null || true; }
mdi_term_wrap_on() { printf '\033[?7h' 2>/dev/null || true; }

mdi_rule_line() {
  # row colour
  r="$1"; colr="${2:-$WHITE}"
  mdi_move "$r" 1
  printf '%b' "$colr"
  i=1
  while [ "$i" -le "$BOOT_COLS" ]; do
    printf '━'
    i=$((i + 1))
  done
  printf '%b' "$RST"
}

mdi_fill_row_sgr() {
  # row sgr
  r="$1"; sgr="$2"
  mdi_move "$r" 1
  mdi_clear_line
  printf '%b%*s%b' "$sgr" "$BOOT_COLS" ' ' "$RST"
}

mdi_center_text() {
  # row colour text
  r="$1"; colr="$2"; txt="$3"
  col=$(( (BOOT_COLS - ${#txt}) / 2 + 1 ))
  [ "$col" -lt 1 ] && col=1
  mdi_move "$r" 1
  mdi_clear_line
  mdi_move "$r" "$col"
  printf '%b%s%b' "$colr" "$txt" "$RST"
}

mdi_layout_debug() {
  [ "${MDI_LAYOUT_DEBUG:-0}" = "1" ] || return 0
  mkdir -p /opt/mdi/log 2>/dev/null || true
  if [ "$LAYOUT_DEBUG_INIT" -eq 0 ]; then
    : > /opt/mdi/log/layout-debug.log 2>/dev/null || true
    LAYOUT_DEBUG_INIT=1
  fi
  {
    printf '%s %s\n' "stage" "${1:-unknown}"
    shift || true
    for kv in "$@"; do
      printf '%s\n' "$kv"
    done
    printf '%s\n\n' "--"
  } >> /opt/mdi/log/layout-debug.log 2>/dev/null || true
}

mdi_clear_region() {
  FROM="$1"
  TO="$2"
  row="$FROM"
  while [ "$row" -le "$TO" ]; do
    mdi_move "$row" 1
    mdi_clear_line
    row=$((row + 1))
  done
}

mdi_boot_rule() {
  ROW="$1"
  COLOUR="$2"
  mdi_move "$ROW" 1
  printf '%b' "$COLOUR"
  i=1
  while [ "$i" -le "$BOOT_COLS" ]; do
    printf '─'
    i=$((i + 1))
  done
  printf '%b' "$RST"
}

mdi_boot_log_panel() {
  TITLE="$1"
  COLOUR="$2"
  mdi_clear_region "$BOOT_LOG_TOP" "${BOOT_LOG_BOTTOM:-$BOOT_ROWS}"
  mdi_boot_rule "$BOOT_LOG_TOP" "$COLOUR"
  mdi_move "$BOOT_LOG_TOP" 2
  printf '%b %s %b' "$BOLD$COLOUR" "$TITLE" "$RST"
  BOOT_LOG_ROW="$BOOT_LOG_FIRST"
}

mdi_box() {
  # row col height width colour title
  r="$1"; c="$2"; h="$3"; w="$4"; colr="$5"; title="${6:-}"
  [ "$h" -lt 3 ] && return 1
  [ "$w" -lt 10 ] && return 1
  # top
  mdi_move "$r" "$c"; printf '%b+' "$colr"
  i=1; while [ "$i" -le $((w-2)) ]; do printf '-'; i=$((i+1)); done
  printf '+%b' "$RST"
  # sides
  i=1
  while [ "$i" -le $((h-2)) ]; do
    mdi_move $((r+i)) "$c"; printf '%b|%b' "$colr" "$RST"
    mdi_move $((r+i)) $((c+w-1)); printf '%b|%b' "$colr" "$RST"
    i=$((i+1))
  done
  # bottom
  mdi_move $((r+h-1)) "$c"; printf '%b+' "$colr"
  i=1; while [ "$i" -le $((w-2)) ]; do printf '-'; i=$((i+1)); done
  printf '+%b' "$RST"
  if [ -n "$title" ]; then
    mdi_move "$r" $((c+2))
    printf '%b%s%b' "$BOLD$colr" "$title" "$RST"
  fi
}

mdi_stage2_log_layout() {
  # Split bottom into left/right panels when width allows; fall back to single.
  ST2_LOG_H="${MDI_STAGE2_LOG_H:-8}"
  [ "$ST2_LOG_H" -lt 6 ] && ST2_LOG_H=6
  ST2_RESERVED_BOTTOM="${MDI_STAGE2_RESERVED_BOTTOM:-0}"
  if [ -n "${TERMUX_VERSION:-}" ] || [ -d /data/data/com.termux/files/usr ] || [ "$BOOT_ROWS" -le 30 ]; then
    [ "$ST2_RESERVED_BOTTOM" -lt 5 ] && ST2_RESERVED_BOTTOM=5
    [ "$ST2_LOG_H" -gt 6 ] && ST2_LOG_H=6
  fi
  [ "$ST2_RESERVED_BOTTOM" -gt $((BOOT_ROWS / 3)) ] && ST2_RESERVED_BOTTOM=$((BOOT_ROWS / 3))
  usable_rows=$((BOOT_ROWS - ST2_RESERVED_BOTTOM))
  [ "$usable_rows" -lt 16 ] && usable_rows="$BOOT_ROWS"
  [ "$ST2_LOG_H" -gt $((usable_rows - 8)) ] && ST2_LOG_H=$((usable_rows - 8))
  [ "$ST2_LOG_H" -lt 4 ] && ST2_LOG_H=4
  ST2_LOG_TOP=$((usable_rows - ST2_LOG_H + 1))
  [ "$ST2_LOG_TOP" -lt 10 ] && ST2_LOG_TOP=10
  ST2_LOG_BOTTOM=$((ST2_LOG_TOP + ST2_LOG_H - 1))
  [ "$ST2_LOG_BOTTOM" -gt "$usable_rows" ] && ST2_LOG_BOTTOM="$usable_rows"

  ST2_SPLIT_OK=0
  ST2_SPLIT_COL=$((BOOT_COLS / 2))
  # Require reasonable widths so windows never overlap.
  if [ "$BOOT_COLS" -ge 80 ]; then
    ST2_SPLIT_OK=1
  fi
  BOOT_LOG_TOP="$ST2_LOG_TOP"
  BOOT_LOG_FIRST=$((ST2_LOG_TOP + 1))
  BOOT_LOG_LAST=$((ST2_LOG_BOTTOM - 1))
  BOOT_LOG_BOTTOM="$ST2_LOG_BOTTOM"
  BOOT_LOG_ROW="$BOOT_LOG_FIRST"
  return 0
}

mdi_stage1_layout_init() {
  # Deterministic: compute geometry and fixed regions once for Stage 1.
  mdi_boot_layout
  ST1_LOG_H="${MDI_STAGE1_LOG_H:-7}"
  [ "$ST1_LOG_H" -lt 5 ] && ST1_LOG_H=5
  [ "$ST1_LOG_H" -gt $((BOOT_ROWS / 3)) ] && ST1_LOG_H=$((BOOT_ROWS / 3))
  ST1_LOG_TOP=$((BOOT_ROWS - ST1_LOG_H + 1))
  [ "$ST1_LOG_TOP" -lt 14 ] && ST1_LOG_TOP=14
  ST1_TITLE_TOP=$((ST1_LOG_TOP - 3))
  [ "$ST1_TITLE_TOP" -lt 8 ] && ST1_TITLE_TOP=8
  # Row 1 reserved; start stage content at row 3.
  ST1_ART_TOP=3
  ST1_ART_BOTTOM=$((ST1_TITLE_TOP - 1))
  [ "$ST1_ART_BOTTOM" -lt "$ST1_ART_TOP" ] && ST1_ART_BOTTOM="$ST1_ART_TOP"

  BOOT_LOG_TOP="$ST1_LOG_TOP"
  BOOT_MAIN_BOTTOM=$((BOOT_LOG_TOP - 2))
  BOOT_LOG_FIRST=$((BOOT_LOG_TOP + 1))
  BOOT_LOG_LAST=$((BOOT_ROWS - 1))
  BOOT_LOG_BOTTOM="$BOOT_ROWS"
  BOOT_LOG_ROW="$BOOT_LOG_FIRST"

  mdi_layout_debug "stage1" \
    "rows=$BOOT_ROWS" "cols=$BOOT_COLS" \
    "st1_art_top=$ST1_ART_TOP" "st1_art_bottom=$ST1_ART_BOTTOM" \
    "st1_title_top=$ST1_TITLE_TOP" "st1_log_top=$ST1_LOG_TOP" "boot_main_bottom=$BOOT_MAIN_BOTTOM"
}

mdi_stage2_layout_init() {
  # Deterministic: compute geometry and fixed regions once for Stage 2.
  mdi_boot_layout
  mdi_stage2_log_layout
  BOOT_MAIN_BOTTOM=$((ST2_LOG_TOP - 2))
  [ "$BOOT_MAIN_BOTTOM" -lt 8 ] && BOOT_MAIN_BOTTOM=8

  # Stage 2 title occupies rows 1-5. Start all content at row 6+.
  STAGE2_TITLE_TOP=1
  STAGE2_TITLE_BOTTOM=5

  # Fixed watchowl placement (top-left): ascii-art5-small.txt
  STAGE2_OWL_ROW=$((STAGE2_TITLE_BOTTOM + 1))
  STAGE2_OWL_COL=2
  # Protected region size follows the actual watchowl asset size.
  STAGE2_OWL_W=40
  STAGE2_OWL_H=20
  OWF="/opt/mdi/assets/ascii/ascii-art5-small.txt"
  if [ -f "$OWF" ]; then
    ow_w="$(wc -L "$OWF" 2>/dev/null | awk '{print $1}' || echo 60)"
    ow_h="$(wc -l "$OWF" 2>/dev/null | awk '{print $1}' || echo 34)"
    case "$ow_w" in ''|*[!0-9]*) ow_w=60 ;; esac
    case "$ow_h" in ''|*[!0-9]*) ow_h=34 ;; esac
    [ "$ow_w" -ge 10 ] && STAGE2_OWL_W="$ow_w"
    [ "$ow_h" -ge 6 ] && STAGE2_OWL_H="$ow_h"
  fi
  STAGE2_OWL_DRAW_W="$STAGE2_OWL_W"
  STAGE2_OWL_DRAW_H="$STAGE2_OWL_H"
  avail_w=$((BOOT_COLS - STAGE2_OWL_COL))
  avail_h=$((BOOT_MAIN_BOTTOM - STAGE2_OWL_ROW + 1))
  [ "$avail_w" -lt "$STAGE2_OWL_DRAW_W" ] && STAGE2_OWL_DRAW_W="$avail_w"
  [ "$avail_h" -lt "$STAGE2_OWL_DRAW_H" ] && STAGE2_OWL_DRAW_H="$avail_h"
  [ "$STAGE2_OWL_DRAW_W" -lt 10 ] && STAGE2_OWL_DRAW_W=0
  [ "$STAGE2_OWL_DRAW_H" -lt 6 ] && STAGE2_OWL_DRAW_H=0

  LOOKOWL_SAFE_LEFT=$((STAGE2_OWL_COL + STAGE2_OWL_W + 2))

  # Fixed matrix lanes (right). Only set if it fits.
  if mdi_matrix_runtime_bounds; then
    STAGE2_MATRIX_COL_1="$MATRIX_COL_1"
    STAGE2_MATRIX_COL_2="$MATRIX_COL_2"
    STAGE2_MATRIX_COL_3="$MATRIX_COL_3"
    STAGE2_MATRIX_ROW_START="$MATRIX_ROW_START"
    STAGE2_MATRIX_ROW_END="$MATRIX_ROW_END"
  else
    STAGE2_MATRIX_COL_1=0
    STAGE2_MATRIX_COL_2=0
    STAGE2_MATRIX_COL_3=0
    STAGE2_MATRIX_ROW_START=0
    STAGE2_MATRIX_ROW_END=0
  fi

  # Fixed padlock placement (center). Never wrap; never truncate.
  PAD_FILE="/opt/mdi/assets/ascii/art5-padlock.txt"
  PAD_W=60
  PAD_H=34
  if [ -f "$PAD_FILE" ]; then
    pw="$(wc -L "$PAD_FILE" 2>/dev/null | awk '{print $1}' || echo 60)"
    ph="$(wc -l "$PAD_FILE" 2>/dev/null | awk '{print $1}' || echo 34)"
    case "$pw" in ''|*[!0-9]*) pw=60 ;; esac
    case "$ph" in ''|*[!0-9]*) ph=34 ;; esac
    [ "$pw" -ge 10 ] && PAD_W="$pw"
    [ "$ph" -ge 6 ] && PAD_H="$ph"
  fi
  # Safe area is to the right of the owl region.
  SAFE_LEFT=64
  SAFE_RIGHT=$((BOOT_COLS - 1))
  [ "$STAGE2_MATRIX_COL_1" -gt 0 ] && SAFE_RIGHT=$((STAGE2_MATRIX_COL_1 - 2))
  SAFE_W=$((SAFE_RIGHT - SAFE_LEFT + 1))
  if [ "$SAFE_W" -ge "$PAD_W" ] && [ "$BOOT_MAIN_BOTTOM" -ge 6 ]; then
    STAGE2_PADLOCK_COL=$((SAFE_LEFT + (SAFE_W - PAD_W) / 2))
    STAGE2_PADLOCK_ROW=$((2 + ((BOOT_MAIN_BOTTOM - 2) - PAD_H) / 2))
    [ "$STAGE2_PADLOCK_ROW" -lt 3 ] && STAGE2_PADLOCK_ROW=3
    [ "$STAGE2_PADLOCK_ROW" -gt "$BOOT_MAIN_BOTTOM" ] && STAGE2_PADLOCK_ROW=3
    # Avoid owl overlap deterministically: prefer moving below owl.
    if [ "$STAGE2_OWL_DRAW_W" -gt 0 ] && [ "$STAGE2_OWL_DRAW_H" -gt 0 ]; then
      owl_r2=$((STAGE2_OWL_ROW + STAGE2_OWL_DRAW_H - 1))
      owl_c2=$((STAGE2_OWL_COL + STAGE2_OWL_DRAW_W - 1))
      pad_r2=$((STAGE2_PADLOCK_ROW + PAD_H - 1))
      pad_c2=$((STAGE2_PADLOCK_COL + PAD_W - 1))
      overlap_r=0; overlap_c=0
      [ "$STAGE2_PADLOCK_ROW" -le "$owl_r2" ] && [ "$pad_r2" -ge "$STAGE2_OWL_ROW" ] && overlap_r=1
      [ "$STAGE2_PADLOCK_COL" -le "$owl_c2" ] && [ "$pad_c2" -ge "$STAGE2_OWL_COL" ] && overlap_c=1
      if [ "$overlap_r" -eq 1 ] && [ "$overlap_c" -eq 1 ]; then
        try_row=$((owl_r2 + 2))
        if [ $((try_row + PAD_H - 1)) -le "$BOOT_MAIN_BOTTOM" ]; then
          STAGE2_PADLOCK_ROW="$try_row"
        fi
      fi
    fi
    # Determine how much can be drawn without wrapping/corrupting spacing.
    STAGE2_PADLOCK_DRAW_W="$PAD_W"
    STAGE2_PADLOCK_DRAW_H="$PAD_H"
    avail_ph=$((BOOT_MAIN_BOTTOM - STAGE2_PADLOCK_ROW + 1))
    [ "$avail_ph" -lt "$STAGE2_PADLOCK_DRAW_H" ] && STAGE2_PADLOCK_DRAW_H="$avail_ph"
    [ "$STAGE2_PADLOCK_DRAW_H" -lt 6 ] && STAGE2_PADLOCK_DRAW_H=0
    [ "$STAGE2_PADLOCK_DRAW_H" -gt 0 ] && STAGE2_PADLOCK_OK=1 || STAGE2_PADLOCK_OK=0
  else
    # Try placing the padlock below the owl in the full-width safe area (excluding matrix).
    SAFE_LEFT2=2
    SAFE_RIGHT2=$((BOOT_COLS - 1))
    [ "$STAGE2_MATRIX_COL_1" -gt 0 ] && SAFE_RIGHT2=$((STAGE2_MATRIX_COL_1 - 2))
    SAFE_W2=$((SAFE_RIGHT2 - SAFE_LEFT2 + 1))
    below_row=$((STAGE2_OWL_ROW + STAGE2_OWL_DRAW_H + 1))
    if [ "$SAFE_W2" -ge "$PAD_W" ] && [ "$below_row" -ge 3 ] && [ $((below_row + 6)) -le "$BOOT_MAIN_BOTTOM" ]; then
      STAGE2_PADLOCK_COL=$((SAFE_LEFT2 + (SAFE_W2 - PAD_W) / 2))
      STAGE2_PADLOCK_ROW="$below_row"
      STAGE2_PADLOCK_DRAW_W="$PAD_W"
      STAGE2_PADLOCK_DRAW_H="$PAD_H"
      avail_ph=$((BOOT_MAIN_BOTTOM - STAGE2_PADLOCK_ROW + 1))
      [ "$avail_ph" -lt "$STAGE2_PADLOCK_DRAW_H" ] && STAGE2_PADLOCK_DRAW_H="$avail_ph"
      [ "$STAGE2_PADLOCK_DRAW_H" -lt 6 ] && STAGE2_PADLOCK_DRAW_H=0
      [ "$STAGE2_PADLOCK_DRAW_H" -gt 0 ] && STAGE2_PADLOCK_OK=1 || STAGE2_PADLOCK_OK=0
    else
      STAGE2_PADLOCK_OK=0
      STAGE2_PADLOCK_ROW=0
      STAGE2_PADLOCK_COL=0
    fi
  fi

  # Deterministic seed for any "random-looking" content inside fixed regions.
  STAGE2_SEED=$((BOOT_COLS * 1000 + BOOT_ROWS * 7 + 2026))

  mdi_layout_debug "stage2" \
    "rows=$BOOT_ROWS" "cols=$BOOT_COLS" \
    "owl_row=$STAGE2_OWL_ROW" "owl_col=$STAGE2_OWL_COL" "owl_w=$STAGE2_OWL_DRAW_W" "owl_h=$STAGE2_OWL_DRAW_H" \
    "pad_ok=$STAGE2_PADLOCK_OK" "pad_row=$STAGE2_PADLOCK_ROW" "pad_col=$STAGE2_PADLOCK_COL" \
    "m1=$STAGE2_MATRIX_COL_1" "m2=$STAGE2_MATRIX_COL_2" "m3=$STAGE2_MATRIX_COL_3" \
    "log_top=$ST2_LOG_TOP" "log_h=$ST2_LOG_H" "seed=$STAGE2_SEED"
}

mdi_stage2_log_panel() {
  # side title colour
  side="$1"; title="$2"; colr="$3"
  if [ "$ST2_SPLIT_OK" -eq 1 ]; then
    if [ "$side" = "left" ]; then
      ST2_L_R="$ST2_LOG_TOP"
      ST2_L_C=1
      ST2_L_W=$((ST2_SPLIT_COL - 1))
      mdi_box "$ST2_L_R" "$ST2_L_C" "$ST2_LOG_H" "$ST2_L_W" "$colr" "$title" || true
      ST2_LOG_L_ROW=$((ST2_LOG_TOP + 1))
      ST2_LOG_L_LAST=$((ST2_LOG_TOP + ST2_LOG_H - 2))
    else
      ST2_R_R="$ST2_LOG_TOP"
      ST2_R_C="$ST2_SPLIT_COL"
      ST2_R_W=$((BOOT_COLS - ST2_SPLIT_COL + 1))
      mdi_box "$ST2_R_R" "$ST2_R_C" "$ST2_LOG_H" "$ST2_R_W" "$colr" "$title" || true
      ST2_LOG_R_ROW=$((ST2_LOG_TOP + 1))
      ST2_LOG_R_LAST=$((ST2_LOG_TOP + ST2_LOG_H - 2))
    fi
  else
    mdi_boot_log_panel "$title" "$colr"
  fi

  # Compact padlock placement is always available as a stable fallback.
  STAGE2_PADLOCK_COMPACT_ROW=$((STAGE2_TITLE_BOTTOM + 2))
  [ "$STAGE2_PADLOCK_COMPACT_ROW" -lt 4 ] && STAGE2_PADLOCK_COMPACT_ROW=4
  STAGE2_PADLOCK_COMPACT_COL=$((BOOT_COLS / 2 - 4))
  [ "$STAGE2_PADLOCK_COMPACT_COL" -lt 2 ] && STAGE2_PADLOCK_COMPACT_COL=2
}

mdi_stage2_log_left() {
  txt="$1"; colr="${2:-$WHITE}"
  [ "${ST2_LOG_L_ROW:-0}" -eq 0 ] && { mdi_boot_log_fixed "$txt" "$colr"; return 0; }
  [ "$ST2_LOG_L_ROW" -gt "$ST2_LOG_L_LAST" ] && ST2_LOG_L_ROW=$((ST2_LOG_TOP + 1))
  mdi_move "$ST2_LOG_L_ROW" 3
  printf '%*s' $((ST2_L_W - 4)) ' '
  mdi_move "$ST2_LOG_L_ROW" 3
  printf '%b%s%b' "$colr" "$(printf '%s' "$txt" | cut -c 1-$((ST2_L_W - 4)))" "$RST"
  ST2_LOG_L_ROW=$((ST2_LOG_L_ROW + 1))
}

mdi_stage2_log_right() {
  txt="$1"; colr="${2:-$WHITE}"
  [ "${ST2_LOG_R_ROW:-0}" -eq 0 ] && { mdi_boot_log_fixed "$txt" "$colr"; return 0; }
  [ "$ST2_LOG_R_ROW" -gt "$ST2_LOG_R_LAST" ] && ST2_LOG_R_ROW=$((ST2_LOG_TOP + 1))
  mdi_move "$ST2_LOG_R_ROW" $((ST2_R_C + 2))
  printf '%*s' $((ST2_R_W - 4)) ' '
  mdi_move "$ST2_LOG_R_ROW" $((ST2_R_C + 2))
  printf '%b%s%b' "$colr" "$(printf '%s' "$txt" | cut -c 1-$((ST2_R_W - 4)))" "$RST"
  ST2_LOG_R_ROW=$((ST2_LOG_R_ROW + 1))
}

mdi_boot_log_fixed() {
  TXT="$1"
  COLOUR="${2:-$WHITE}"
  [ "$BOOT_LOG_ROW" -gt "$BOOT_LOG_LAST" ] && {
    mdi_clear_region "$BOOT_LOG_FIRST" "$BOOT_LOG_LAST"
    BOOT_LOG_ROW="$BOOT_LOG_FIRST"
  }

  MAX=$((BOOT_COLS - 2))
  [ "$MAX" -lt 20 ] && MAX=20
  LINE="$(printf '%s' "$TXT" | cut -c 1-"$MAX")"
  mdi_move "$BOOT_LOG_ROW" 2
  mdi_clear_line
  printf '%b%s%b' "$COLOUR" "$LINE" "$RST"
  BOOT_LOG_ROW=$((BOOT_LOG_ROW + 1))
  mdi_event_chain INFO boot "$TXT"
}

mdi_boot_title() {
  # Legacy helper kept for compatibility; stages should use mdi_draw_stage_header.
  TITLE="$1"
  COLOUR="$2"
  mdi_draw_stage_header "$TITLE" "$COLOUR"
}

mdi_draw_stage_header() {
  # title header_sgr [right_label]
  # header_sgr should include full SGR (including background) so the bar reads as a real header.
  title="$1"
  header_sgr="${2:-${ESC}[1;37m}"
  right="${3:-}"
  [ -z "${BOOT_COLS:-}" ] && mdi_boot_layout

  # Reserve row 1 as protected header bar.
  mdi_move 1 1
  mdi_clear_line

  # Build a full-width bar: left title, right mode label.
  # No scrolling, no wrapping.
  left_txt="$title"
  right_txt="$right"
  [ -z "$right_txt" ] && right_txt="$(printf '%s' "${MDI_THEME:-mode}" | tr '[:lower:]' '[:upper:]') MODE"

  # One-space padding on both sides.
  left_txt=" $left_txt"
  right_txt="$right_txt "

  # Compute spacing.
  l_len=${#left_txt}
  r_len=${#right_txt}
  if [ $((l_len + r_len)) -ge "$BOOT_COLS" ]; then
    # Truncate left to fit.
    max_left=$((BOOT_COLS - r_len - 1))
    [ "$max_left" -lt 1 ] && max_left=1
    left_txt="$(printf '%s' "$left_txt" | cut -c 1-"$max_left")"
    l_len=${#left_txt}
  fi
  gap=$((BOOT_COLS - l_len - r_len))
  [ "$gap" -lt 1 ] && gap=1

  printf '%b' "$header_sgr"
  printf '%s' "$left_txt"
  printf '%*s' "$gap" ' '
  printf '%s' "$right_txt"
  printf '%b' "$RST"
}

mdi_ascii_asset_render() {
  NAME="$1"
  COLOUR="$2"
  FILE="/opt/mdi/assets/ascii/$NAME"

  [ -f "$FILE" ] || return 1

  printf '%b' "$COLOUR"
  cat "$FILE"
  printf '%b' "$RST"
}

mdi_render_asset_at() {
  FILE="$1"
  ROW="$2"
  COL="$3"
  COLOUR="$4"
  MAX_ROW="$5"
  MAX_COLS="$6"

  [ -f "$FILE" ] || return 1
  [ "$MAX_COLS" -lt 10 ] && return 1

  row="$ROW"
  printf '%b' "$COLOUR"
  while IFS= read -r LINE || [ -n "$LINE" ]; do
    [ "$row" -gt "$MAX_ROW" ] && break
    mdi_move "$row" "$COL"
    if [ ${#LINE} -gt "$MAX_COLS" ] 2>/dev/null; then
      printf '%s' "$LINE" | cut -c 1-"$MAX_COLS"
    else
      printf '%s' "$LINE"
    fi
    row=$((row + 1))
  done < "$FILE"
  printf '%b' "$RST"
}

mdi_render_asset_window_at() {
  FILE="$1"
  ROW="$2"
  COL="$3"
  COLOUR="$4"
  MAX_ROW="$5"
  START_COL="$6"
  WIDTH="$7"

  [ -f "$FILE" ] || return 1
  [ "$WIDTH" -lt 10 ] && return 1
  [ "$START_COL" -lt 1 ] && START_COL=1
  END_COL=$((START_COL + WIDTH - 1))

  row="$ROW"
  printf '%b' "$COLOUR"
  while IFS= read -r LINE || [ -n "$LINE" ]; do
    [ "$row" -gt "$MAX_ROW" ] && break
    SEG="$(printf '%s' "$LINE" | cut -c "$START_COL"-"$END_COL")"
    mdi_move "$row" "$COL"
    printf '%s' "$SEG"
    row=$((row + 1))
  done < "$FILE"
  printf '%b' "$RST"
}

mdi_render_asset_exact_at() {
  # Render byte-exact spacing, one source line per terminal line, no trimming/piping.
  # Caller must ensure the asset fits the terminal; wrapping should be disabled.
  FILE="$1"
  ROW="$2"
  COL="$3"
  COLOUR="$4"
  MAX_ROW="$5"

  [ -f "$FILE" ] || return 1
  row="$ROW"
  printf '%b' "$COLOUR"
  while IFS= read -r LINE || [ -n "$LINE" ]; do
    [ "$row" -gt "$MAX_ROW" ] && break
    mdi_move "$row" "$COL"
    printf '%s' "$LINE"
    row=$((row + 1))
  done < "$FILE"
  printf '%b' "$RST"
}

mdi_matrix_write() {
  # row col text ; clipped to matrix region only
  r="$1"; c="$2"; t="$3"
  [ "${STAGE2_MATRIX_COL_1:-0}" -gt 0 ] || return 0
  [ "$r" -lt "${STAGE2_MATRIX_ROW_START:-9999}" ] && return 0
  [ "$r" -gt "${STAGE2_MATRIX_ROW_END:-0}" ] && return 0
  [ "$c" -lt "${STAGE2_MATRIX_COL_1:-9999}" ] && return 0
  [ "$c" -gt "${STAGE2_MATRIX_COL_3:-0}" ] && return 0
  # Enforce binary-only in matrix.
  case "$t" in *[!01\ ]*) t="$(printf '%s' "$t" | tr -cd '01 ')" ;; esac
  t="$(printf '%s' "$t" | cut -c 1-"${MATRIX_LANE_W:-8}")"
  mdi_move "$r" "$c"
  printf '\033[38;5;196m%s%b' "$t" "$RST"
}

mdi_matrix_clear() {
  # row col width ; clipped
  r="$1"; c="$2"; w="$3"
  [ "${STAGE2_MATRIX_COL_1:-0}" -gt 0 ] || return 0
  [ "$r" -lt "${STAGE2_MATRIX_ROW_START:-9999}" ] && return 0
  [ "$r" -gt "${STAGE2_MATRIX_ROW_END:-0}" ] && return 0
  mdi_move "$r" "$c"
  printf '%*s' "$w" ' '
}

mdi_draw_owl_watermark() {
  FILE='/opt/mdi/assets/ascii/ascii-art(5).txt'
  MAX_COLS=$((BOOT_COLS - 2))
  COL=1
  [ "$BOOT_COLS" -gt 84 ] && COL=$(((BOOT_COLS - 80) / 2))
  [ "$COL" -lt 1 ] && COL=1
  mdi_render_asset_at "$FILE" 2 "$COL" "$(printf '\033[2;37m')" "$BOOT_MAIN_BOTTOM" "$MAX_COLS" || {
    mdi_move 5 4
    printf '%b%s%b' "$DIM" "<(o_v )>" "$RST"
  }
}

mdi_matrix_runtime_bounds() {
  [ "$MDI_ANIMATION" = "off" ] && return 1
  # 3-lane right-side overlay; keep it available on typical 80-col terminals.
  # Each lane prints clustered binary groups, not single glyphs.
  MATRIX_LANE_W=8
  MATRIX_LANE_GAP=1
  MATRIX_RESERVED=$((MATRIX_LANE_W * 3 + MATRIX_LANE_GAP * 2))
  [ "$BOOT_COLS" -lt $((MATRIX_RESERVED + 10)) ] && return 1
  [ "$BOOT_MAIN_BOTTOM" -lt 12 ] && return 1
  MATRIX_COL_1=$((BOOT_COLS - MATRIX_RESERVED + 1))
  MATRIX_COL_2=$((MATRIX_COL_1 + MATRIX_LANE_W + MATRIX_LANE_GAP))
  MATRIX_COL_3=$((MATRIX_COL_2 + MATRIX_LANE_W + MATRIX_LANE_GAP))
  # Reserve the title block; start drawing below it.
  MATRIX_ROW_START=$(( ${STAGE2_TITLE_BOTTOM:-3} + 1 ))
  MATRIX_ROW_END="$BOOT_MAIN_BOTTOM"
  return 0
}

mdi_matrix_loop() {
  trap 'exit 0' INT TERM
  # Binary-only, clustered groups. Keep it narrow and right-aligned.
  frame=1
  prng="${STAGE2_SEED:-1337}"
  while :; do
    # Deterministic: bounds are calculated once at stage entry.
    [ "${STAGE2_MATRIX_COL_1:-0}" -gt 0 ] || { sleep 0.18 2>/dev/null || true; continue; }
    row="$MATRIX_ROW_START"
    while [ "$row" -le "$MATRIX_ROW_END" ]; do
      # Deterministic PRNG (no /dev/urandom). Content may vary; layout must not.
      prng=$(( (prng * 110351 + 12345) % 2147483647 ))
      pick=$((prng % 5))
      case "$pick" in
        0) n1=1 ;;
        1) n1=3 ;;
        2) n1=5 ;;
        3) n1=8 ;;
        *) n1=13 ;;
      esac
      prng=$(( (prng * 110351 + 12345) % 2147483647 ))
      pick2=$((prng % 5))
      case "$pick2" in
        0) n2=1 ;;
        1) n2=3 ;;
        2) n2=5 ;;
        3) n2=8 ;;
        *) n2=13 ;;
      esac

      bits() {
        want="$1"; seed="$2"
        s=""; i=0
        while [ "$i" -lt "$want" ]; do
          b=$(( (seed + i * 3) % 2 ))
          s="${s}${b}"
          i=$((i + 1))
        done
        printf '%s' "$s"
      }

      # Variable gaps between groups to avoid uniform spacing.
      prng=$(( (prng * 110351 + 12345) % 2147483647 ))
      gap=$((prng % 4))
      case "$gap" in
        0) sep=" " ;;
        1) sep="  " ;;
        2) sep="   " ;;
        *) sep="     " ;;
      esac

      g1="$(bits "$n1" $((prng + row + frame)))"
      g2="$(bits "$n2" $((prng + row + frame + 9)))"
      lane="$(printf '%s%s%s' "$g1" "$sep" "$g2" | cut -c 1-"$MATRIX_LANE_W")"

      # Clear each lane region, then draw the lane cluster.
      mdi_matrix_clear "$row" "$STAGE2_MATRIX_COL_1" "$MATRIX_LANE_W"
      mdi_matrix_clear "$row" "$STAGE2_MATRIX_COL_2" "$MATRIX_LANE_W"
      mdi_matrix_clear "$row" "$STAGE2_MATRIX_COL_3" "$MATRIX_LANE_W"

      # Lane 2 uses a different seed so it feels related but not mirrored.
      lane2="$(printf '%s%s%s' "$(bits "$n2" $((prng + row + frame + 17)))" "$sep" "$(bits "$n1" $((prng + row + frame + 31)))" | cut -c 1-"$MATRIX_LANE_W")"

      mdi_matrix_write "$row" "$STAGE2_MATRIX_COL_1" "$lane"
      mdi_matrix_write "$row" "$STAGE2_MATRIX_COL_2" "$lane2"
      mdi_matrix_write "$row" "$STAGE2_MATRIX_COL_3" "$lane"

      # Occasional blank a lane for a controlled "pair fall" gap.
      if [ $(( (frame + row) % 9 )) -eq 0 ]; then
        mdi_matrix_clear "$row" "$STAGE2_MATRIX_COL_2" "$MATRIX_LANE_W"
      fi
      row=$((row + 1))
    done
    frame=$((frame + 1))
    sleep 0.14 2>/dev/null || true
  done
}

mdi_start_matrix_layer() {
  # Deterministic: stage layout init computes bounds once.
  [ "${STAGE2_MATRIX_COL_1:-0}" -gt 0 ] || return 0
  if [ -n "${MDI_MATRIX_PID:-}" ] && kill -0 "$MDI_MATRIX_PID" 2>/dev/null; then
    return 0
  fi
  MATRIX_COL_1="$STAGE2_MATRIX_COL_1"
  MATRIX_COL_2="$STAGE2_MATRIX_COL_2"
  MATRIX_COL_3="$STAGE2_MATRIX_COL_3"
  MATRIX_ROW_START="$STAGE2_MATRIX_ROW_START"
  MATRIX_ROW_END="$STAGE2_MATRIX_ROW_END"
  mdi_matrix_loop &
  MDI_MATRIX_PID="$!"
  mdi_anim_register "$MDI_MATRIX_PID"
}

mdi_find_eye_script() {
  for CANDIDATE in \
    /opt/mdi/tui/animate-eyes.sh \
    /opt/mdi/boot/animate-eyes.sh \
    ./animate-eyes.sh
  do
    [ -x "$CANDIDATE" ] && { EYE_SCRIPT="$CANDIDATE"; return 0; }
  done
  return 1
}

mdi_find_eye_asset() {
  for CANDIDATE in \
    /opt/mdi/assets/ascii/ascii-art5-small.txt \
    /opt/mdi/tui/ascii-art5-small.txt \
    /opt/mdi/boot/ascii-art5-small.txt \
    ./ascii-art5-small.txt
  do
    [ -f "$CANDIDATE" ] && { EYE_ASSET="$CANDIDATE"; return 0; }
  done
  return 1
}

mdi_builtin_eye_loop() {
  trap 'exit 0' INT TERM
  FRAME=0
  while :; do
    mdi_move "$EYE_ROW" "$EYE_COL"
    case $((FRAME % 4)) in
      0) printf '%b%s%b' "$RED" '<(o_v )>' "$RST" ;;
      1) printf '%b%s%b' "$RED" '<(-_o)>' "$RST" ;;
      2) printf '%b%s%b' "$RED" '<(o_^_)>' "$RST" ;;
      *) printf '%b%s%b' "$RED" '<(-_-)>' "$RST" ;;
    esac
    FRAME=$((FRAME + 1))
    sleep 0.38 2>/dev/null || true
  done
}

mdi_external_eye_loop() {
  trap 'exit 0' INT TERM
  while :; do
    mdi_move "$EYE_ROW" "$EYE_COL"
    MDI_EYE_ROW="$EYE_ROW" MDI_EYE_COL="$EYE_COL" "$EYE_SCRIPT" "$EYE_ASSET"
    sleep 0.12 2>/dev/null || true
  done
}

mdi_start_eye_layer() {
  [ "$MDI_ANIMATION" = "off" ] && return 0
  [ "$BOOT_COLS" -lt 74 ] && return 0
  EYE_ROW=3
  EYE_COL=$((BOOT_COLS - 28))
  [ "$EYE_COL" -lt 2 ] && return 0

  if mdi_find_eye_script && mdi_find_eye_asset; then
    mdi_external_eye_loop &
  else
    mdi_builtin_eye_loop &
  fi
  mdi_anim_register "$!"
}

mdi_find_looking_owl_eyes() {
  # Detect a line containing two "oo" eye groups and record their relative columns.
  # Outputs: EYE_LINE_IDX EYE_COL1 EYE_COL2 (1-based cols within the art).
  FILE="$1"
  awk '
    {
      pos1 = index($0, "oo");
      if (pos1 > 0) {
        rest = substr($0, pos1+2);
        pos2r = index(rest, "oo");
        if (pos2r > 0) {
          pos2 = pos1 + 2 + pos2r - 1;
          print NR, pos1, pos2;
          exit 0;
        }
      }
    }
    END { exit 1 }
  ' "$FILE" 2>/dev/null
}

mdi_start_looking_owl_layer() {
  # Stage 2 watchowl render: fixed left/right frames, no body mutation.
  OWL_FILE="/opt/mdi/assets/ascii/ascii-art5-small.txt"
  [ -f "$OWL_FILE" ] || return 0

  LOOKOWL_ACTIVE=1
  # Deterministic: stage layout init sets these once per stage.
  OWL_ROW="${STAGE2_OWL_ROW:-4}"
  OWL_COL="${STAGE2_OWL_COL:-2}"
  OWL_W="${STAGE2_OWL_W:-40}"
  OWL_H="${STAGE2_OWL_H:-20}"
  OWL_DRAW_W="${STAGE2_OWL_DRAW_W:-40}"
  OWL_DRAW_H="${STAGE2_OWL_DRAW_H:-20}"
  [ "$OWL_DRAW_W" -lt 10 ] && return 0
  [ "$OWL_DRAW_H" -lt 6 ] && return 0
  LOOKOWL_SAFE_LEFT=$((OWL_COL + OWL_W + 2))

  eye_meta="$(mdi_find_looking_owl_eyes "$OWL_FILE" || true)"
  set -- $eye_meta
  EYE_LINE_IDX="${1:-}"
  EYE_C1="${2:-}"
  EYE_C2="${3:-}"

  if mdi_watchowl_frames_validate; then
    mdi_start_watchowl_frame_layer "$OWL_ROW" "$OWL_COL" "$OWL_DRAW_W" "$OWL_DRAW_H" || true
  else
    # Validation failure disables owl animation but keeps the base owl visible.
    BODY_COL="$(printf '\033[38;5;196m')"
    mdi_render_asset_at "$OWL_FILE" "$OWL_ROW" "$OWL_COL" "$BODY_COL" "$((OWL_ROW + OWL_DRAW_H - 1))" "$OWL_DRAW_W" || true
  fi
}

mdi_watchowl_frame_left() {
  cat <<'OWL_LOOK_LEFT'
z                                      z


 "}                                  }}
  i[-}                            ]-[<
    ; {[[[                    l["[ "
         I[[[]            `]_]:
     >~~-    ]??!      !-]]    ?-+l
    ~~~+  vzz   ?_    .-   <z)  ]_+~,
  < +~_   'zc  ' >_  _~    ;z    _-+ ~
  i +_?        !< `I,!-li       ^< ? <
  `~l]}{(.   }+[]?    -__i?   `(((1}?^
   +i,1(|(){{[]?- <  + ___-?[}{1)(|,?
     ~?+(1{}[]`.  ~.'?   ,_-?][}+1i
        ~)[[}      +|      ^]+1+
                   {(



z                                      z
OWL_LOOK_LEFT
}

mdi_watchowl_frame_right() {
  cat <<'OWL_LOOK_RIGHT'
z                                      z


 "}                                  }}
  i[-}                            ]-[<
    ; {[[[                    l["[ "
         I[[[]            `]_]:
     >~~-    ]??!      !-]]    ?-+l
    ~~~+  vzz   ?_    .-   <z)  ]_+~,
  < +~_   'zc  ' >_  _~    ;z    _-+ ~
  i +_?        ! >`I,!-li       ^ >? <
  `~l]}{(.   }+[]?    -__i?   `(((1}?^
   +i,1(|(){{[]?- <  + ___-?[}{1)(|,?
     ~?+(1{}[]`.  ~.'?   ,_-?][}+1i
        ~)[[}      +|      ^]+1+
                   {(



z                                      z
OWL_LOOK_RIGHT
}

mdi_watchowl_frames_validate() {
  mkdir -p /opt/mdi/state 2>/dev/null || true
  lf="/opt/mdi/state/watchowl-left.$$"
  rf="/opt/mdi/state/watchowl-right.$$"
  mdi_watchowl_frame_left > "$lf" 2>/dev/null || { rm -f "$lf" "$rf"; return 1; }
  mdi_watchowl_frame_right > "$rf" 2>/dev/null || { rm -f "$lf" "$rf"; return 1; }

  lh="$(wc -l < "$lf" 2>/dev/null || echo 0)"
  rh="$(wc -l < "$rf" 2>/dev/null || echo 1)"
  [ "$lh" = "$rh" ] || { rm -f "$lf" "$rf"; return 1; }

  awk '
    NR == FNR { len[NR] = length($0); n = NR; next }
    { if (FNR > n || length($0) != len[FNR]) bad = 1 }
    END { if (FNR != n || bad) exit 1 }
  ' "$lf" "$rf" || { rm -f "$lf" "$rf"; return 1; }

  WATCHOWL_FRAME_H="$lh"
  WATCHOWL_FRAME_W="$(wc -L "$lf" 2>/dev/null | awk '{print $1}' || echo 40)"
  case "$WATCHOWL_FRAME_W" in ''|*[!0-9]*) WATCHOWL_FRAME_W=40 ;; esac
  rm -f "$lf" "$rf"
  return 0
}

mdi_watchowl_clear_region() {
  r="$WATCHOWL_ROW"
  end=$((WATCHOWL_ROW + WATCHOWL_DRAW_H - 1))
  w="$WATCHOWL_DRAW_W"
  [ "$w" -gt "$WATCHOWL_FRAME_W" ] && w="$WATCHOWL_FRAME_W"
  [ "$w" -lt 1 ] && return 0
  while [ "$r" -le "$end" ]; do
    mdi_move "$r" "$WATCHOWL_COL"
    printf '%*s' "$w" ' '
    r=$((r + 1))
  done
}

mdi_watchowl_gold_eye() {
  r="$1"; c="$2"; ch="$3"
  [ "$r" -lt "${STAGE2_OWL_ROW:-9999}" ] && return 0
  [ "$r" -gt $((STAGE2_OWL_ROW + STAGE2_OWL_H - 1)) ] && return 0
  [ "$c" -lt "${STAGE2_OWL_COL:-9999}" ] && return 0
  end_c=$((STAGE2_OWL_COL + STAGE2_OWL_W - 1))
  [ "$c" -gt "$end_c" ] && return 0
  mdi_move "$r" "$c"
  printf '%b%s%b' "${MDI_WATCHOWL_EYE_COLOUR:-${ESC}[1;38;5;220m}" "$ch" "$RST"
}

mdi_watchowl_colour_eyes() {
  frame="$1"
  eye_r=$((WATCHOWL_ROW + 10))
  [ "$eye_r" -gt $((WATCHOWL_ROW + WATCHOWL_DRAW_H - 1)) ] && return 0
  case "$frame" in
    OWL_LOOK_RIGHT)
      mdi_watchowl_gold_eye "$eye_r" $((WATCHOWL_COL + 17)) ">"
      mdi_watchowl_gold_eye "$eye_r" $((WATCHOWL_COL + 34)) ">"
      ;;
    *)
      mdi_watchowl_gold_eye "$eye_r" $((WATCHOWL_COL + 16)) "<"
      mdi_watchowl_gold_eye "$eye_r" $((WATCHOWL_COL + 33)) "<"
      ;;
  esac
}

mdi_watchowl_draw_frame() {
  frame="$1"
  mdi_watchowl_clear_region
  row="$WATCHOWL_ROW"
  max_row=$((WATCHOWL_ROW + WATCHOWL_DRAW_H - 1))
  printf '%b' "${ESC}[38;5;196m"
  case "$frame" in
    OWL_LOOK_RIGHT)
      mdi_watchowl_frame_right | while IFS= read -r line || [ -n "$line" ]; do
        [ "$row" -gt "$max_row" ] && break
        mdi_move "$row" "$WATCHOWL_COL"
        printf '%s' "$(printf '%s' "$line" | cut -c 1-"$WATCHOWL_DRAW_W")"
        row=$((row + 1))
      done
      ;;
    *)
      mdi_watchowl_frame_left | while IFS= read -r line || [ -n "$line" ]; do
        [ "$row" -gt "$max_row" ] && break
        mdi_move "$row" "$WATCHOWL_COL"
        printf '%s' "$(printf '%s' "$line" | cut -c 1-"$WATCHOWL_DRAW_W")"
        row=$((row + 1))
      done
      ;;
  esac
  printf '%b' "$RST"
  mdi_watchowl_colour_eyes "$frame"
}

mdi_watchowl_frame_loop() {
  trap 'exit 0' INT TERM
  while :; do
    mdi_watchowl_draw_frame OWL_LOOK_LEFT
    mdi_sleep "${MDI_WATCHOWL_GAZE_STEP:-0.80}"
    mdi_watchowl_draw_frame OWL_LOOK_RIGHT
    mdi_sleep "${MDI_WATCHOWL_GAZE_STEP:-0.80}"
  done
}

mdi_start_watchowl_frame_layer() {
  # owl_row owl_col draw_w draw_h
  [ -n "${MDI_OWL_PID:-}" ] && kill -0 "$MDI_OWL_PID" 2>/dev/null && return 0
  WATCHOWL_ROW="$1"
  WATCHOWL_COL="$2"
  WATCHOWL_DRAW_W="$3"
  WATCHOWL_DRAW_H="$4"
  [ "$WATCHOWL_DRAW_W" -gt "$WATCHOWL_FRAME_W" ] && WATCHOWL_DRAW_W="$WATCHOWL_FRAME_W"
  [ "$WATCHOWL_DRAW_H" -gt "$WATCHOWL_FRAME_H" ] && WATCHOWL_DRAW_H="$WATCHOWL_FRAME_H"
  [ "$WATCHOWL_DRAW_W" -lt 10 ] && return 1
  [ "$WATCHOWL_DRAW_H" -lt 6 ] && return 1

  mdi_watchowl_draw_frame OWL_LOOK_LEFT
  [ "$MDI_ANIMATION" = "off" ] && return 0
  mdi_watchowl_frame_loop &
  MDI_OWL_PID="$!"
  mdi_anim_register "$MDI_OWL_PID"
}

mdi_lock_bounds() {
  [ "$BOOT_MAIN_BOTTOM" -lt 14 ] && return 1
  LOCK_ROW=$((BOOT_MAIN_BOTTOM - 9))
  [ "$LOCK_ROW" -lt 5 ] && LOCK_ROW=5
  LOCK_COL=4
  [ "$BOOT_COLS" -gt 100 ] && LOCK_COL=8
  return 0
}

mdi_draw_lock_stable() {
  mdi_lock_bounds || return 1
  printf '%b' "$RED"
  mdi_move "$LOCK_ROW" "$LOCK_COL";       printf '        .------------.'
  mdi_move $((LOCK_ROW+1)) "$LOCK_COL";    printf '       /  .--------.  \'
  mdi_move $((LOCK_ROW+2)) "$LOCK_COL";    printf '      /  /  ____    \  \'
  mdi_move $((LOCK_ROW+3)) "$LOCK_COL";    printf '      |  | | __ |   |  |'
  mdi_move $((LOCK_ROW+4)) "$LOCK_COL";    printf '      |  | ||  ||   |  |'
  mdi_move $((LOCK_ROW+5)) "$LOCK_COL";    printf '      |  | ||__||   |  |'
  mdi_move $((LOCK_ROW+6)) "$LOCK_COL";    printf '      |  |  ____    |  |'
  mdi_move $((LOCK_ROW+7)) "$LOCK_COL";    printf '      |  | |____|   |  |'
  mdi_move $((LOCK_ROW+8)) "$LOCK_COL";    printf "      |  '----------'  |"
  mdi_move $((LOCK_ROW+9)) "$LOCK_COL";    printf "      '----------------'"
  printf '%b' "$RST"
}

mdi_lock_glitch_loop() {
  # Disabled: any lock glitch/mutation is forbidden for the boot display.
  exit 0
}

mdi_start_lock_layer() {
  # Disabled: lock layer is not used in the current boot stages.
  return 0
}

mdi_security_padlock_bounds() {
  # Deterministic: stage layout init computes and freezes padlock placement once.
  PAD_FILE="/opt/mdi/assets/ascii/art5-padlock.txt"
  PAD_W=60
  PAD_H=34
  [ "${STAGE2_PADLOCK_OK:-0}" -eq 1 ] || return 1
  PAD_ROW="$STAGE2_PADLOCK_ROW"
  PAD_COL="$STAGE2_PADLOCK_COL"
  PAD_MAX_COLS="$PAD_W"
  PAD_DRAW_H="${STAGE2_PADLOCK_DRAW_H:-$PAD_H}"
  PAD_MAX_ROW=$((PAD_ROW + PAD_DRAW_H - 1))
  return 0
}

mdi_draw_security_padlock_stable() {
  mdi_security_padlock_bounds || return 1
  # Stable-only: no mutation, no highlights, no background writers.
  PAD_BODY="${ESC}[0;31m"

  if [ -f "$PAD_FILE" ]; then
    mdi_render_asset_exact_at "$PAD_FILE" "$PAD_ROW" "$PAD_COL" "$PAD_BODY" "$PAD_MAX_ROW" || return 1
    return 0
  fi

  # Safe compact fallback if the asset is missing.
  mdi_draw_lock_stable
}

mdi_start_security_padlock_layer() {
  if ! mdi_security_padlock_bounds; then
    # Compact stable padlock for narrow terminals.
    r="${STAGE2_PADLOCK_COMPACT_ROW:-6}"
    c="${STAGE2_PADLOCK_COMPACT_COL:-10}"
    mdi_move "$r" "$c"
    printf '%b%s%b' "${ESC}[2;31m" "[ LOCK ]" "$RST"
    return 0
  fi
  # Stable-only: draw once, no animation loop.
  mdi_draw_security_padlock_stable || true
}

mdi_stage1_render_art_panel() {
  FILE="/opt/mdi/assets/ascii/ascii-art(3).txt"
  [ -f "$FILE" ] || return 0
  ART_W="$(wc -L "$FILE" 2>/dev/null | awk '{print $1}' || echo 70)"
  case "$ART_W" in ''|*[!0-9]*) ART_W=70 ;; esac
  ART_ROW=$((ST1_ART_TOP + 1))
  ART_MAX_ROW="$ST1_ART_BOTTOM"
  AVAIL_W=$((BOOT_COLS - 4))
  [ "$AVAIL_W" -lt 10 ] && return 0

  if [ "$AVAIL_W" -ge $((ART_W * 2 + 2)) ]; then
    TOTAL_W=$((ART_W * 2 + 2))
    ART_COL=$(( (BOOT_COLS - TOTAL_W) / 2 + 1 ))
    [ "$ART_COL" -lt 2 ] && ART_COL=2
    mdi_render_asset_at "$FILE" "$ART_ROW" "$ART_COL" "$CYAN" "$ART_MAX_ROW" "$ART_W" || true
    mdi_render_asset_at "$FILE" "$ART_ROW" $((ART_COL + ART_W + 2)) "$CYAN" "$ART_MAX_ROW" "$ART_W" || true
  else
    if [ "$BOOT_COLS" -gt "$ART_W" ]; then
      ART_COL=$(( (BOOT_COLS - ART_W) / 2 + 1 ))
      ART_MAX_COLS="$ART_W"
    else
      ART_COL=2
      ART_MAX_COLS=$((BOOT_COLS - 3))
    fi
    [ "$ART_COL" -lt 1 ] && ART_COL=1
    mdi_render_asset_at "$FILE" "$ART_ROW" "$ART_COL" "$CYAN" "$ART_MAX_ROW" "$ART_MAX_COLS" || true
  fi
}

mdi_stage1_initial_boot() {
  mdi_stage1_layout_init
  mdi_hide_cursor
  mdi_term_wrap_off
  mdi_clear

  mdi_box "$ST1_ART_TOP" 1 $((ST1_ART_BOTTOM - ST1_ART_TOP + 2)) "$BOOT_COLS" "$CYAN" "" || true
  mdi_stage1_render_art_panel

  # Stage 1 visible title bar (centred) directly below the Stage 1 artwork.
  ST1_TITLE="TROS By MDI Maori Digital Independence"
  ST1_TROW="$ST1_TITLE_TOP"
  [ "$ST1_TROW" -lt 4 ] && ST1_TROW=4
  if [ $((ST1_TROW + 2)) -lt "$BOOT_LOG_TOP" ]; then
    mdi_rule_line "$ST1_TROW" "$CYAN"
    mdi_center_text $((ST1_TROW + 1)) "$BOLD$WHITE" "$ST1_TITLE"
    mdi_rule_line $((ST1_TROW + 2)) "$CYAN"
  fi
  mdi_boot_log_panel "BOOT INITIALISATION" "$CYAN"
  mdi_boot_log_fixed "runtime detected" "$WHITE"
  mdi_boot_pause normal
  mdi_boot_log_fixed "terminal size detected: ${BOOT_COLS}x${BOOT_ROWS}" "$WHITE"
  mdi_boot_pause normal
  mdi_boot_log_fixed "assets detected" "$WHITE"
  mdi_boot_pause normal
  mdi_boot_log_fixed "boot profile loaded" "$WHITE"
  mdi_boot_pause normal
  mdi_boot_log_fixed "entering security protocol" "$CYAN"
  mdi_stage_seal "stage1" "initial_boot_ready"
  mdi_boot_pause long
}

mdi_stage2_security_protocol() {
  # Hard boundary: kill any prior/uncontrolled writers before starting the security display.
  mdi_stop_boot_animations_soft
  mdi_stage2_layout_init
  mdi_term_wrap_off
  mdi_clear
  # Large Stage 2 title block (rows 1-5). Keep it deterministic and protected.
  mdi_rule_line 1 "$RED"
  mdi_fill_row_sgr 2 "${ESC}[48;5;196m"
  mdi_fill_row_sgr 3 "${ESC}[48;5;196m"
  mdi_center_text 2 "${ESC}[1;37;48;5;196m" "M D I"
  mdi_center_text 3 "${ESC}[1;37;48;5;196m" "SECURITY PROTOCOL"
  mdi_fill_row_sgr 4 "${ESC}[48;5;196m"
  mdi_rule_line 5 "$RED"

  mdi_clear_region "$ST2_LOG_TOP" "$ST2_LOG_BOTTOM"
  if [ "$ST2_SPLIT_OK" -eq 1 ]; then
    mdi_stage2_log_panel left "" "$RED"
    mdi_stage2_log_panel right "" "$RED"
  else
    mdi_boot_log_panel "MDI SECURITY PROTOCOL" "$RED"
  fi

  # Draw order (stable first):
  mdi_start_looking_owl_layer
  mdi_start_security_padlock_layer
  mdi_start_matrix_layer

  STAGE2_STEP="${MDI_STAGE2_STEP:-2.00}"
  STAGE2_HOLD="${MDI_STAGE2_HOLD:-4.00}"
  stage2_pause() { [ "$MDI_ANIMATION" = "off" ] && return 0; mdi_sleep "${1:-$STAGE2_STEP}"; }

  if [ ! -f /opt/mdi/assets/ascii/ascii-art5-small.txt ]; then
    mdi_stage2_log_left "[SEC] watchowl asset missing" "$WHITE"
    mdi_stage2_log_right "[SEC] install /root/ascii-art5-small.txt" "$WHITE"
  fi

  mdi_stage2_log_left "[SEC] loading security protocol" "$WHITE"
  mdi_stage2_log_right "[SEC] protocol init" "$WHITE"
  stage2_pause "$STAGE2_STEP"
  mdi_stage2_log_left "[SEC] hashing local manifests" "$RED"
  mdi_stage2_log_right "[SEC] hash ok" "$WHITE"
  stage2_pause "$STAGE2_STEP"
  mdi_stage2_log_left "[SEC] scanning runtime paths" "$RED"
  mdi_stage2_log_right "[SEC] scan ok" "$WHITE"
  stage2_pause "$STAGE2_STEP"
  mdi_stage2_log_left "[SEC] checking shell boundary" "$RED"
  mdi_stage2_log_right "[SEC] boundary ok" "$WHITE"
  stage2_pause "$STAGE2_STEP"
  mdi_stage2_log_left "[SEC] verifying asset map" "$RED"
  mdi_stage2_log_right "[SEC] assets ok" "$WHITE"
  stage2_pause "$STAGE2_STEP"
  mdi_stage2_log_left "[SEC] checking offline posture" "$RED"
  mdi_stage2_log_right "[SEC] offline ok" "$WHITE"
  stage2_pause "$STAGE2_STEP"
  mdi_stage2_log_left "[SEC] locking terminal control" "$RED"
  mdi_stage2_log_right "[SEC] tty ok" "$WHITE"
  stage2_pause "$STAGE2_STEP"
  mdi_stage2_log_left "[SEC] authorising TUI handoff" "$WHITE"
  mdi_stage2_log_right "[SEC] authorised" "$WHITE"
  mdi_stage_seal "stage2" "security_protocol_ready"
  stage2_pause "$STAGE2_HOLD"

  # Stage 2 completion boundary: stop registered matrix/owl writers, wait, then clear once.
  mdi_stop_boot_animations_soft
  mdi_reset
  mdi_clear
}

mdi_stage3_runtime_preparation() {
  mdi_stage_verify "stage2" || mdi_boot_log_fixed "[RUN] security seal missing; continuing guarded" "$YELLOW"
  mdi_boot_layout
  mdi_draw_stage_header "MDI Security Protocol" "${ESC}[1;37;41m" "RUNTIME MODE"
  mdi_boot_log_panel "RUNTIME PREPARATION" "$CYAN"

  if [ "${LOOKOWL_ACTIVE:-0}" -ne 1 ] && [ "$BOOT_COLS" -ge 84 ] && [ "$BOOT_MAIN_BOTTOM" -ge 31 ]; then
    mdi_render_asset_at '/opt/mdi/assets/ascii/ascii-art(3).txt' 3 2 "$CYAN" "$BOOT_MAIN_BOTTOM" "$((BOOT_COLS - 12))" || true
  fi

  mdi_boot_log_fixed "[RUN] preparing local runtime" "$CYAN"
  mdi_boot_pause normal
  mdi_boot_log_fixed "[RUN] binding shell surface" "$CYAN"
  mdi_boot_pause normal
  mdi_boot_log_fixed "[RUN] checking state directory" "$CYAN"
  mdi_boot_pause normal
  mdi_boot_log_fixed "[RUN] loading command surface" "$CYAN"
  mdi_boot_pause normal
  mdi_boot_log_fixed "[RUN] runtime ready" "$WHITE"
  mdi_stage_seal "stage3" "runtime_ready"
  mdi_boot_pause long
}

mdi_stage4_interface_handoff() {
  mdi_stage_verify "stage3" || mdi_boot_log_fixed "[SYS] runtime seal missing; guarded handoff" "$YELLOW"
  mdi_boot_layout
  mdi_draw_stage_header "MDI Security Protocol" "${ESC}[1;37;41m" "HANDOFF MODE"
  mdi_boot_log_panel "INTERFACE HANDOFF" "$WHITE"

  mdi_boot_log_fixed "preparing operator shell" "$WHITE"
  mdi_boot_pause normal
  mdi_boot_log_fixed "loading TUI bindings" "$WHITE"
  mdi_boot_pause normal
  mdi_boot_log_fixed "checking prompt state" "$WHITE"
  mdi_boot_pause normal
  mdi_boot_log_fixed "clearing boot overlays" "$WHITE"
  mdi_boot_pause normal
  mdi_boot_log_fixed "starting TUI" "$WHITE"
  mdi_stage_seal "stage4" "interface_handoff_ready"
  mdi_boot_pause long
}

mdi_final_whekeos_handoff() {
  FILE="/opt/mdi/assets/ascii/ascii-art13.txt"
  [ -f "$FILE" ] || return 0

  mdi_boot_layout
  RESERVED_BOTTOM=0
  if [ -n "${TERMUX_VERSION:-}" ] || [ -d /data/data/com.termux/files/usr ] || [ "$BOOT_ROWS" -le 30 ]; then
    RESERVED_BOTTOM=2
  fi
  USABLE_ROWS=$((BOOT_ROWS - RESERVED_BOTTOM))
  [ "$USABLE_ROWS" -lt 12 ] && USABLE_ROWS="$BOOT_ROWS"

  ART_W="$(wc -L "$FILE" 2>/dev/null | awk '{print $1}' || echo 120)"
  ART_H="$(wc -l "$FILE" 2>/dev/null | awk '{print $1}' || echo 59)"
  case "$ART_W" in ''|*[!0-9]*) ART_W=120 ;; esac
  case "$ART_H" in ''|*[!0-9]*) ART_H=59 ;; esac

  LABEL_ROWS=3
  DRAW_H=$((USABLE_ROWS - LABEL_ROWS))
  [ "$DRAW_H" -gt "$ART_H" ] && DRAW_H="$ART_H"
  [ "$DRAW_H" -lt 4 ] && DRAW_H=4
  [ "$DRAW_H" -gt "$USABLE_ROWS" ] && DRAW_H="$USABLE_ROWS"

  DRAW_W=$((BOOT_COLS - 2))
  [ "$DRAW_W" -lt 20 ] && DRAW_W="$BOOT_COLS"
  if [ "$ART_W" -le "$DRAW_W" ]; then
    ART_COL=$(( (BOOT_COLS - ART_W) / 2 + 1 ))
    START_COL=1
    DRAW_W="$ART_W"
  else
    ART_COL=1
    START_COL=$(( (ART_W - DRAW_W) / 2 + 1 ))
  fi
  [ "$ART_COL" -lt 1 ] && ART_COL=1

  TOTAL_H=$((DRAW_H + LABEL_ROWS))
  ART_ROW=$(( (USABLE_ROWS - TOTAL_H) / 2 + 1 ))
  [ "$ART_ROW" -lt 1 ] && ART_ROW=1
  ART_MAX_ROW=$((ART_ROW + DRAW_H - 1))

  mdi_render_asset_window_at "$FILE" "$ART_ROW" "$ART_COL" "$CYAN" "$ART_MAX_ROW" "$START_COL" "$DRAW_W" || return 0
  TITLE_ROW=$((ART_MAX_ROW + 1))
  LOAD_ROW=$((ART_MAX_ROW + 2))
  [ "$TITLE_ROW" -le "$USABLE_ROWS" ] && mdi_center_text "$TITLE_ROW" "$BOLD$CYAN" "WhekeOS"
  [ "$LOAD_ROW" -le "$USABLE_ROWS" ] && mdi_center_text "$LOAD_ROW" "$WHITE" "loading terminal interface"
  [ "$MDI_ANIMATION" = "off" ] || mdi_sleep "${MDI_WHEKEOS_HOLD:-1.50}"
}

mdi_stage5_tui_startup() {
  mdi_stop_boot_animations
  mdi_reset
  mdi_hide_cursor
  mdi_clear
  mdi_final_whekeos_handoff
  mdi_reset
  mdi_show_cursor
  mdi_clear
  mdi_boot_log INFO interface "tui startup complete"
}

mdi_intro_sequence() {
  : > "$BOOT_PID_FILE" 2>/dev/null || true
  mdi_boot_session_init
  mdi_stage1_initial_boot
  mdi_stage2_security_protocol
  mdi_stage3_runtime_preparation
  mdi_stage4_interface_handoff
  mdi_stage5_tui_startup
}

mdi_transition() {
  LABEL="$1"
  printf '\n'
  mdi_orbit "$LABEL" 8
  printf '\n'
}
