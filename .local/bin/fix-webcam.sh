#!/usr/bin/env bash
# Configuration automatique de la qualité de la webcam

# Attendre éventuellement que le périphérique soit prêt si appelé au boot
for i in {1..10}; do
    if [ -e "/dev/video0" ]; then
        /usr/bin/v4l2-ctl -d /dev/video0 \
            --set-ctrl=contrast=40 \
            --set-ctrl=saturation=69 \
            --set-ctrl=sharpness=5 \
            --set-ctrl=brightness=126 \
            --set-ctrl=gamma=116 \
            --set-ctrl=exposure_dynamic_framerate=0
        exit 0
    fi
    sleep 1
done
