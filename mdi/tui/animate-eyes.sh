#!/bin/sh

ART="${1:-ascii-art5-small.txt}"

# Colour scheme
BODY_COLOUR='\033[2;32m'     # dim green
EYE_COLOUR='\033[1;92m'      # bright green
RESET='\033[0m'

if [ ! -f "$ART" ]; then
  echo "Missing ASCII file: $ART"
  exit 1
fi

hide_cursor() { printf '\033[?25l'; }
show_cursor() { printf '\033[?25h\033[0m'; }
clear_screen() { printf '\033[2J\033[H'; }

# Move cursor: row ; column
move_to() {
  printf '\033[%s;%sH' "$1" "$2"
}

draw_body() {
  clear_screen
  printf '%b' "$BODY_COLOUR"
  cat "$ART"
  printf '%b' "$RESET"
}

draw_eyes() {
  # Args: left_eye_col right_eye_col
  LCOL="$1"
  RCOL="$2"

  # Clear previous eye area on line 10
  move_to 10 11
  printf '      '
  move_to 10 27
  printf '      '

  # Draw pupils
  printf '%b' "$EYE_COLOUR"

  move_to 10 "$LCOL"
  printf 'oo'

  move_to 10 "$RCOL"
  printf 'oo'

  printf '%b' "$RESET"
}

trap 'show_cursor; printf "\033[0m\n"; exit 0' INT TERM EXIT

hide_cursor
draw_body

while :; do
  # Look left
  draw_eyes 11 27
  sleep 0.35

  # Look centre
  draw_eyes 12 28
  sleep 0.25

  # Look right
  draw_eyes 13 29
  sleep 0.60

  # Back to centre
  draw_eyes 12 28
  sleep 0.25

  # Back left
  draw_eyes 11 27
  sleep 0.60
done
