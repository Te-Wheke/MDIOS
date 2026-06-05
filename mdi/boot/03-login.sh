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
