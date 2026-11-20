#!/usr/bin/env python3
import sys
import os
import json
import subprocess
import numpy as np
from PyQt6.QtGui import QImage, QColor, QPainter, QRadialGradient, QBrush
from PyQt6.QtCore import Qt, QPointF

MASK_PATH = os.path.expanduser("~/.config/dms/wallpaper/opium_mask.png")
CONFIG_JSON = os.path.expanduser("~/.cache/dms/wallpaper.json")
WAL_JSON = os.path.expanduser("~/.cache/wal/colors.json")
CACHE_DIR = os.path.expanduser("~/.cache/dms")
PATH_A = os.path.join(CACHE_DIR, "opium_wallpaper_a.png")
PATH_B = os.path.join(CACHE_DIR, "opium_wallpaper_b.png")

def get_accent_color():
    # Priority 1: Argument passed
    if len(sys.argv) > 1 and sys.argv[1].startswith("#"):
        return sys.argv[1]
    
    # Priority 2: Matugen wallpaper.json
    if os.path.exists(CONFIG_JSON):
        try:
            with open(CONFIG_JSON) as f:
                data = json.load(f)
                if "primary" in data and data["primary"].startswith("#"):
                    return data["primary"]
        except Exception:
            pass

    # Priority 3: Pywal colors.json
    if os.path.exists(WAL_JSON):
        try:
            with open(WAL_JSON) as f:
                data = json.load(f)
                return data.get("colors", {}).get("color4", "#cdbdff")
        except Exception:
            pass

    return "#cdbdff"

def render_wallpaper(accent_hex):
    if not os.path.exists(MASK_PATH):
        print(f"Mask file not found: {MASK_PATH}", file=sys.stderr)
        return None

    mask_img = QImage(MASK_PATH)
    cw, ch = mask_img.width(), mask_img.height()

    accent = QColor(accent_hex)
    bg = QColor("#08080a")

    # Generate tinted logo: light tone with accent hue
    # Keeps text very clear and readable while beautifully carrying the music tone
    h, s, v, _ = accent.getHsv()
    text_color = QColor.fromHsv(h, min(s, 60), 245)

    # Colorize mask with text_color
    tinted_logo = QImage(cw, ch, QImage.Format.Format_ARGB32)
    tinted_logo.fill(Qt.GlobalColor.transparent)
    lp = QPainter(tinted_logo)
    lp.drawImage(0, 0, mask_img)
    lp.setCompositionMode(QPainter.CompositionMode.CompositionMode_SourceIn)
    lp.fillRect(0, 0, cw, ch, text_color)
    lp.end()

    # 1920x1080 canvas
    target = QImage(1920, 1080, QImage.Format.Format_ARGB32)
    target.fill(bg)

    p = QPainter(target)
    p.setRenderHint(QPainter.RenderHint.Antialiasing)
    p.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform)

    # Ambient radial backlight glow in the music accent
    grad = QRadialGradient(QPointF(960, 540), 450)
    c_glow = QColor(accent)
    c_glow.setAlpha(55)
    grad.setColorAt(0.0, c_glow)
    c_fade = QColor(accent)
    c_fade.setAlpha(0)
    grad.setColorAt(1.0, c_fade)
    p.fillRect(0, 0, 1920, 1080, QBrush(grad))

    # Center logo with slight upscale (1.2x)
    scale = 1.2
    sw, sh = int(cw * scale), int(ch * scale)
    scaled_logo = tinted_logo.scaled(sw, sh, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)
    x = (1920 - sw) // 2
    y = (1080 - sh) // 2
    p.drawImage(x, y, scaled_logo)
    p.end()

    # Alternate paths to ensure DMS detects path change
    try:
        cur_proc = subprocess.run(["dms", "ipc", "call", "wallpaper", "get"], capture_output=True, text=True)
        cur_path = cur_proc.stdout.strip()
    except Exception:
        cur_path = ""

    out_path = PATH_B if cur_path == PATH_A else PATH_A
    target.save(out_path)
    return out_path

def main():
    os.makedirs(CACHE_DIR, exist_ok=True)
    accent_hex = get_accent_color()
    out_path = render_wallpaper(accent_hex)
    if out_path:
        subprocess.run(["dms", "ipc", "call", "wallpaper", "set", out_path], capture_output=True)
        print(f"Applied music wallpaper: {out_path} (color: {accent_hex})")

if __name__ == "__main__":
    main()
