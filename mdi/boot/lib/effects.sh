#!/bin/sh

mdi_matrix_loop() {
  top="$1"; left="$2"; width="$3"; height="$4"
  trap 'exit 0' INT TERM
  frame=1
  while :; do
    row=1
    while [ "$row" -le "$height" ]; do
      seed=$((frame + row + width + height))
      line=""
      i=1
      while [ "$i" -le "$width" ]; do
        bit=$(((seed + i * 3 + frame) % 2))
        case $(((i + frame + row) % 7)) in
          0) line="${line} " ;;
          *) line="${line}${bit}" ;;
        esac
        i=$((i + 1))
      done
      mdi_draw_text "$top" "$left" "$width" "$height" "$row" 1 "$line" "$RED"
      row=$((row + 1))
    done
    frame=$((frame + 1))
    sleep 0.16 2>/dev/null || true
  done
}

mdi_start_matrix() {
  [ "${MDI_ANIMATION_EFFECTIVE:-off}" = "off" ] && return 0
  [ "${EFFECT_WIDTH:-0}" -lt 8 ] && return 0
  [ "${EFFECT_HEIGHT:-0}" -lt 4 ] && return 0
  mdi_matrix_loop "$EFFECT_TOP" "$EFFECT_LEFT" "$EFFECT_WIDTH" "$EFFECT_HEIGHT" &
  mdi_pid_register "$!"
}
