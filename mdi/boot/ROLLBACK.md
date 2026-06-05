# ROLLBACK

Backup archive:
/opt/mdi/backups/boot-v1-visual-prototype-20260605-133507.tar.gz

Restore command:
tar -xzf /opt/mdi/backups/boot-v1-visual-prototype-20260605-133507.tar.gz -C /

Affected files:
/opt/mdi/bin/mdi-boot
/opt/mdi/bin/mdi-session
/opt/mdi/bin/mdi-status
/opt/mdi/tui/main.sh
/opt/mdi/tui/mdi-start
/opt/mdi/boot/mdi-boot
/opt/mdi/boot/lib
/opt/mdi/boot/phases
/opt/mdi/boot/themes
/opt/mdi/boot/tests
/opt/mdi/assets/boot

Verify restored boot:
/opt/mdi/bin/mdi-boot --diag
/opt/mdi/bin/mdi-boot
