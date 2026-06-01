#!/system/bin/sh
# Persistent root boot script for REVVL 7 Pro 5G
# Place in /data/adb/service.d/ (executed by Magisk daemon)
# Or run manually: sh /data/local/tmp/auto_root.sh

LOG=/data/local/tmp/root_boot.log
echo "[$(date)] Auto-root starting..." >> $LOG

for i in 0 1 2 3; do
    RESULT=$(CHEESE_ATTEMPT=$i /data/local/tmp/cheese whoami 2>/dev/null)
    if [ "$RESULT" = "root" ]; then
        echo "[$(date)] Root obtained (idx $i)" >> $LOG
        CHEESE_ATTEMPT=$i /data/local/tmp/cheese sh -c '
            setenforce 0 2>/dev/null
            # Setup su for Magisk
            if [ -d /data/adb/magisk ]; then
                /data/adb/magisk/busybox sh -c "magisk --daemon" 2>/dev/null &
            fi
            echo "[$(date)] Root daemon active" >> /data/local/tmp/root_boot.log
        ' &
        exit 0
    fi
done
echo "[$(date)] Failed - retrying in background" >> $LOG
