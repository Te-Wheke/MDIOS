#!/bin/sh

MDI_BOOT_ASSET_ROOT="/opt/mdi/assets/boot"
MDI_ASSET_IDENTITY=""
MDI_ASSET_SECURITY=""
MDI_ASSET_OWL=""
MDI_ASSET_MISSING=""

mdi_assets_discover() {
  profile="${MDI_PROFILE:-phone}"
  MDI_ASSET_IDENTITY=""
  MDI_ASSET_SECURITY=""
  MDI_ASSET_OWL=""
  MDI_ASSET_MISSING=""

  scan_dirs="$MDI_BOOT_ASSET_ROOT/$profile /opt/mdi/assets/ascii $MDI_BOOT_ASSET_ROOT/phone $MDI_BOOT_ASSET_ROOT/tablet $MDI_BOOT_ASSET_ROOT/desktop $MDI_BOOT_ASSET_ROOT/ultra-compact"
  for dir in $scan_dirs; do
    [ -d "$dir" ] || continue
    found="$(find "$dir" -maxdepth 1 -type f 2>/dev/null | sort)"
    old_ifs="$IFS"
    IFS='
'
    for f in $found; do
      b="$(basename "$f")"
      case "$b" in
        boot_logo_mdi.txt)
          [ -z "$MDI_ASSET_IDENTITY" ] && MDI_ASSET_IDENTITY="$f"
          ;;
        ascii-art\(7\).txt|ascii-art7-padlock.txt|art5-padlock.txt|ascii-art-padlock-security.txt)
          [ -z "$MDI_ASSET_SECURITY" ] && MDI_ASSET_SECURITY="$f"
          ;;
        ascii-art5-small.txt)
          [ -z "$MDI_ASSET_OWL" ] && MDI_ASSET_OWL="$f"
          ;;
      esac
    done
    IFS="$old_ifs"
  done

  [ -n "$MDI_ASSET_IDENTITY" ] || MDI_ASSET_MISSING="${MDI_ASSET_MISSING} identity"
  [ -n "$MDI_ASSET_SECURITY" ] || MDI_ASSET_MISSING="${MDI_ASSET_MISSING} lock"
  [ -n "$MDI_ASSET_OWL" ] || MDI_ASSET_MISSING="${MDI_ASSET_MISSING} owl"
}
