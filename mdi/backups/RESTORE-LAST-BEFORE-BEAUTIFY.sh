#!/bin/sh
set -eu
tar -xzf "/opt/mdi/backups/opt-mdi-before-tui-beautify-20260527-100518.tar.gz" -C /
chmod +x /opt/mdi/bin/* /opt/mdi/boot/*.sh /opt/mdi/tui/*.sh 2>/dev/null || true
echo "Restored from /opt/mdi/backups/opt-mdi-before-tui-beautify-20260527-100518.tar.gz"
