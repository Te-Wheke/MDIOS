#!/bin/sh

mdi_str_clip() {
  txt="$1"
  max="$2"
  case "$max" in ''|*[!0-9]*) max=0 ;; esac
  [ "$max" -le 0 ] && return 0
  printf '%s' "$txt" | cut -c 1-"$max"
}

mdi_region_clear() {
  top="$1"; left="$2"; width="$3"; height="$4"
  case "$width" in ''|*[!0-9]*) return 0 ;; esac
  case "$height" in ''|*[!0-9]*) return 0 ;; esac
  [ "$width" -le 0 ] && return 0
  [ "$height" -le 0 ] && return 0
  row=0
  while [ "$row" -lt "$height" ]; do
    abs=$((top + row))
    [ "$abs" -gt "${MDI_ROWS:-24}" ] && break
    mdi_move "$abs" "$left"
    printf '%*s' "$width" ' '
    row=$((row + 1))
  done
}

mdi_draw_text() {
  top="$1"; left="$2"; width="$3"; height="$4"; rel_row="$5"; rel_col="$6"; text="$7"; colour="${8:-}"
  case "$width" in ''|*[!0-9]*) return 0 ;; esac
  case "$height" in ''|*[!0-9]*) return 0 ;; esac
  case "$rel_row" in ''|*[!0-9]*) return 0 ;; esac
  case "$rel_col" in ''|*[!0-9]*) return 0 ;; esac
  [ "$width" -le 0 ] && return 0
  [ "$height" -le 0 ] && return 0
  [ "$rel_row" -lt 1 ] && return 0
  [ "$rel_row" -gt "$height" ] && return 0
  [ "$rel_col" -lt 1 ] && return 0
  [ "$rel_col" -gt "$width" ] && return 0
  avail=$((width - rel_col + 1))
  [ "$avail" -le 0 ] && return 0
  line="$(mdi_str_clip "$text" "$avail")"
  abs_row=$((top + rel_row - 1))
  abs_col=$((left + rel_col - 1))
  [ "$abs_row" -gt "${MDI_ROWS:-24}" ] && return 0
  [ "$abs_col" -gt "${MDI_COLS:-80}" ] && return 0
  mdi_move "$abs_row" "$abs_col"
  printf '%s%s%s' "$colour" "$line" "${RST:-}"
}

mdi_draw_center() {
  top="$1"; left="$2"; width="$3"; height="$4"; rel_row="$5"; text="$6"; colour="${7:-}"
  case "$width" in ''|*[!0-9]*) return 0 ;; esac
  len=${#text}
  if [ "$len" -gt "$width" ]; then
    text="$(mdi_str_clip "$text" "$width")"
    len=${#text}
  fi
  col=$(((width - len) / 2 + 1))
  [ "$col" -lt 1 ] && col=1
  mdi_draw_text "$top" "$left" "$width" "$height" "$rel_row" "$col" "$text" "$colour"
}

mdi_asset_size() {
  file="$1"
  [ -f "$file" ] || return 1
  ASSET_H="$(awk 'END { print NR + 0 }' "$file" 2>/dev/null || printf '0')"
  ASSET_W="$(awk '{ if (length($0) > m) m = length($0) } END { print m + 0 }' "$file" 2>/dev/null || printf '0')"
  case "$ASSET_H" in ''|*[!0-9]*) ASSET_H=0 ;; esac
  case "$ASSET_W" in ''|*[!0-9]*) ASSET_W=0 ;; esac
  [ "$ASSET_H" -gt 0 ] && [ "$ASSET_W" -gt 0 ]
}

mdi_draw_asset_center() {
  top="$1"; left="$2"; width="$3"; height="$4"; file="$5"; colour="${6:-}"
  [ -f "$file" ] || return 1
  mdi_asset_size "$file" || return 1
  [ "$ASSET_W" -gt "$width" ] && return 1
  [ "$ASSET_H" -gt "$height" ] && return 1
  start_row=$(((height - ASSET_H) / 2 + 1))
  start_col=$(((width - ASSET_W) / 2 + 1))
  row=0
  while IFS= read -r line || [ -n "$line" ]; do
    row=$((row + 1))
    mdi_draw_text "$top" "$left" "$width" "$height" $((start_row + row - 1)) "$start_col" "$line" "$colour"
  done < "$file"
  return 0
}

mdi_draw_status() {
  rel_row="$1"; label="$2"; result="$3"; colour="${4:-}"
  text="$label $result"
  mdi_draw_text "$STATUS_TOP" "$STATUS_LEFT" "$STATUS_WIDTH" "$STATUS_HEIGHT" "$rel_row" 2 "$text" "$colour"
}
