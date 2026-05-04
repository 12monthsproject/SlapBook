#!/usr/bin/env python3
"""
SlapBook - 简化菜单栏版本 (rumps)
"""

import os
import sys
import math
import random
import time
import subprocess
import threading
from pathlib import Path

import rumps

# 路径配置
APP_DIR = Path(__file__).parent.parent
SOUNDS_DIR = APP_DIR / "Resources"
CONFIG_FILE = Path("/tmp/slapbook_config.txt")

# 音效包配置
PACKS = {
    "sexy":   ("💋 女声娇喘", [f"sexy_{i:02d}.mp3" for i in range(42)]),
    "yamete": ("🇯🇵 Yamete", [f"yamete_0{i}.mp3" for i in range(1, 7)]),
    "male":   ("🔥 男声嚎叫", [f"male_0{i}_{n}.mp3" for i, n in enumerate([
                "Ow", "Ouch", "Owwie", "Hey_that_hurts", "Ow_stop_it",
                "What_was_that_for", "Hey", "Yowch", "That_stings"])]),
    "punch":  ("🥊 拳击音效", [f"punch_{i:02d}.mp3" for i in range(1, 27)]),
    "fart":   ("💨 放屁", [f"fart_{i:02d}.mp3" for i in range(1, 14)]),
    "goat":   ("🐐 山羊", [f"goat_{i}.mp3" for i in range(1, 11)]),
    "number": ("🔢 计数", [f"{i}_{j}.mp3" for i in range(1, 10) for j in range(1, 4)]),
}
PACK_ORDER = ["sexy", "yamete", "male", "punch", "fart", "goat", "number"]

# 状态
running = False
stop_event = threading.Event()
current_pack = "sexy"
last_trigger = 0


def get_pack():
    if CONFIG_FILE.exists():
        p = CONFIG_FILE.read_text().strip()
        if p in PACKS:
            return p
    return "sexy"


def save_pack(p):
    CONFIG_FILE.write_text(p)


def play(intensity):
    name, sounds = PACKS.get(current_pack, PACKS["sexy"])
    valid = [s for s in sounds if (SOUNDS_DIR / s).exists()]
    if valid:
        subprocess.Popen(["afplay", str(SOUNDS_DIR / random.choice(valid))],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def detect(mag):
    impact = abs(mag - 1.0)
    if impact >= 0.8: return "hard"
    if impact >= 0.4: return "medium"
    if impact >= 0.15: return "light"
    return None


def imu_loop():
    global current_pack, last_trigger
    try:
        from macimu import IMU
        if not IMU.available():
            rumps.notification("SlapBook", "错误", "未检测到加速度计")
            return
        with IMU() as imu:
            for sample in imu.stream_accel():
                if stop_event.is_set():
                    break
                if int(time.time() * 2) % 2 == 0:
                    new_pack = get_pack()
                    if new_pack != current_pack:
                        current_pack = new_pack
                mag = math.sqrt(sample.x**2 + sample.y**2 + sample.z**2)
                intensity = detect(mag)
                if intensity:
                    now = time.time()
                    if now - last_trigger >= 0.3:
                        last_trigger = now
                        play(intensity)
    except Exception as e:
        rumps.notification("SlapBook", "错误", str(e))


class SlapBookApp(rumps.App):
    def __init__(self):
        super().__init__("SlapBook", title="💋", quit_button=None)
        global current_pack
        current_pack = get_pack()
        self.update_menu()
    
    def update_menu(self):
        pack = get_pack()
        status = "▶ 运行中" if running else "⏸ 已停止"
        name, _ = PACKS[pack]
        
        # 构建音效菜单
        sound_items = []
        for key in PACK_ORDER:
            n, _ = PACKS[key]
            prefix = "✓ " if key == pack else "  "
            sound_items.append(rumps.MenuItem(f"{prefix}{n}", 
                           callback=lambda s, k=key: self.set_pack(k)))
        
        self.menu = [
            f"{status} · {name}",
            None,
            rumps.MenuItem("▶ 启动" if not running else "⏹ 停止", 
                          callback=self.toggle),
            ("🎵 选择音效", sound_items),
            None,
            rumps.MenuItem("❌ 退出", callback=self.quit_app),
        ]
    
    def set_pack(self, key):
        global current_pack
        save_pack(key)
        current_pack = key
        self.title = PACKS[key][0][0]  # emoji
        self.update_menu()
        rumps.notification("SlapBook", "已切换", PACKS[key][0])
    
    def toggle(self, _):
        global running
        if not running:
            stop_event.clear()
            threading.Thread(target=imu_loop, daemon=True).start()
            running = True
            rumps.notification("SlapBook", "已启动", PACKS[current_pack][0])
        else:
            stop_event.set()
            running = False
            rumps.notification("SlapBook", "已停止", "")
        self.update_menu()
    
    def quit_app(self, _):
        global running
        if running:
            stop_event.set()
        rumps.quit_application()


if __name__ == "__main__":
    SlapBookApp().run()
