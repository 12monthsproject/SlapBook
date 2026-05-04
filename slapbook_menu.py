#!/usr/bin/env python3
"""
SlapBook - 菜单栏版本
点击菜单栏图标控制，不占用桌面
"""

import os
import sys
import math
import random
import time
import subprocess
import signal
import threading
from pathlib import Path

# 尝试导入 rumps，如果没有则提示安装
try:
    import rumps
except ImportError:
    print("需要安装 rumps: pip install rumps")
    sys.exit(1)

# 路径配置
APP_DIR = Path(__file__).parent.parent
SOUNDS_DIR = APP_DIR / "Resources"
PID_FILE = Path("/tmp/slapbook.pid")
CONFIG_FILE = Path("/tmp/slapbook_config.txt")

# 音效包配置
SOUND_PACKS = {
    "sexy": {
        "name": "💋 女声娇喘",
        "light":  [f"sexy_{i:02d}.mp3" for i in range(0, 14)],
        "medium": [f"sexy_{i:02d}.mp3" for i in range(14, 28)],
        "hard":   [f"sexy_{i:02d}.mp3" for i in range(28, 42)],
    },
    "yamete": {
        "name": "🇯🇵 Yamete",
        "light":  ["yamete_01.mp3", "yamete_02.mp3"],
        "medium": ["yamete_03.mp3", "yamete_04.mp3"],
        "hard":   ["yamete_05.mp3", "yamete_06.mp3"],
    },
    "male": {
        "name": "🔥 男声嚎叫",
        "light":  ["male_00_Ow.mp3", "male_01_Ouch.mp3", "male_02_Owwie.mp3", "male_07_Hey.mp3"],
        "medium": ["male_03_Hey_that_hurts.mp3", "male_04_Ow_stop_it.mp3",
                   "male_06_Ow_ow_ow.mp3", "male_09_That_stings.mp3"],
        "hard":   ["male_05_What_was_that_for.mp3", "male_08_Yowch.mp3"],
    },
    "punch": {
        "name": "🥊 拳击音效",
        "light":  [f"punch_{i:02d}.mp3" for i in range(1, 10)],
        "medium": [f"punch_{i:02d}.mp3" for i in range(10, 18)],
        "hard":   [f"punch_{i:02d}.mp3" for i in range(18, 27)],
    },
    "fart": {
        "name": "💨 放屁",
        "light":  [f"fart_{i:02d}.mp3" for i in range(1, 5)],
        "medium": [f"fart_{i:02d}.mp3" for i in range(5, 10)],
        "hard":   [f"fart_{i:02d}.mp3" for i in range(10, 14)],
    },
    "goat": {
        "name": "🐐 山羊",
        "light":  [f"goat_{i}.mp3" for i in range(1, 4)],
        "medium": [f"goat_{i}.mp3" for i in range(4, 7)],
        "hard":   [f"goat_{i}.mp3" for i in range(7, 11)],
    },
    "number": {
        "name": "🔢 计数",
        "light":  ["1_1.mp3", "1_2.mp3", "1_3.mp3", "2_1.mp3", "2_2.mp3", "2_3.mp3"],
        "medium": ["3_1.mp3", "3_2.mp3", "3_3.mp3", "4_1.mp3", "4_2.mp3",
                   "4_3.mp3", "5_1.mp3", "5_2.mp3", "5_3.mp3"],
        "hard":   ["6_1.mp3", "6_2.mp3", "6_3.mp3", "7_1.mp3", "7_2.mp3",
                   "8_1.mp3", "8_2.mp3", "8_3.mp3", "8_4.mp3",
                   "9_1.mp3", "9_2.mp3", "9_3.mp3"],
    },
}

PACK_KEYS = ["sexy", "yamete", "male", "punch", "fart", "goat", "number"]

# 状态
running = False
imu_thread = None
stop_event = threading.Event()
current_pack = "sexy"
last_trigger = 0
min_interval = 0.3


def pack_name(key):
    """获取音效包显示名"""
    return SOUND_PACKS.get(key, {}).get("name", key)


def get_current_pack():
    """从配置文件读取当前音效包"""
    if CONFIG_FILE.exists():
        pack = CONFIG_FILE.read_text().strip()
        if pack in SOUND_PACKS:
            return pack
    return "sexy"


def save_pack(pack):
    """保存音效包到配置文件"""
    CONFIG_FILE.write_text(pack)


def play_sound(intensity: str):
    """播放指定强度的随机音效"""
    pack = SOUND_PACKS.get(current_pack, SOUND_PACKS["sexy"])
    sounds = pack.get(intensity, [])
    if not sounds:
        return

    valid = [s for s in sounds if (SOUNDS_DIR / s).exists()]
    if not valid:
        return

    sound_path = SOUNDS_DIR / random.choice(valid)
    subprocess.Popen(
        ["afplay", str(sound_path)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )


def detect_intensity(magnitude: float):
    """根据加速度大小判断拍打强度"""
    if magnitude >= 0.8:
        return "hard"
    elif magnitude >= 0.4:
        return "medium"
    elif magnitude >= 0.15:
        return "light"
    return None


def imu_loop():
    """IMU 监听循环（在后台线程运行）"""
    global current_pack, last_trigger
    
    try:
        from macimu import IMU
    except ImportError:
        rumps.notification("SlapBook", "错误", "缺少 macimu 库")
        return

    if not IMU.available():
        rumps.notification("SlapBook", "错误", "未检测到加速度计")
        return

    try:
        with IMU() as imu:
            for sample in imu.stream_accel():
                if stop_event.is_set():
                    break

                # 每 0.5 秒检查一次配置
                if int(time.time() * 2) % 2 == 0:
                    new_pack = get_current_pack()
                    if new_pack != current_pack:
                        current_pack = new_pack

                mag = math.sqrt(sample.x**2 + sample.y**2 + sample.z**2)
                impact = abs(mag - 1.0)
                intensity = detect_intensity(impact)

                if intensity:
                    now = time.time()
                    if now - last_trigger >= min_interval:
                        last_trigger = now
                        play_sound(intensity)
    except Exception as e:
        rumps.notification("SlapBook", "错误", str(e))


class SlapBookApp(rumps.App):
    def __init__(self):
        super().__init__(
            "SlapBook",
            title="",
            icon=None,  # 可以用 emoji 或自定义图标
            template=True,  # 使用模板图标（适配深色模式）
        )
        
        # 设置菜单栏图标为 emoji
        self.title = "💋"
        
        # 初始化状态
        global current_pack
        current_pack = get_current_pack()
        self.update_menu()
    
    def update_menu(self):
        """更新菜单项"""
        pack = get_current_pack()
        status = "▶ 运行中" if running else "⏸ 已停止"
        
        # 构建音效包子菜单 - rumps 格式: (父菜单, [子菜单列表])
        sound_submenu = []
        for key in PACK_KEYS:
            name = pack_name(key)
            checked = key == pack
            menu_title = f"{'✓ ' if checked else '  '}{name}"
            # 使用 functools.partial 来正确捕获 key
            from functools import partial
            sound_submenu.append(
                rumps.MenuItem(menu_title, callback=partial(self.set_sound_pack, key))
            )
        
        self.menu = [
            rumps.MenuItem(f"{status} · {pack_name(pack)}", callback=None),
            None,  # 分隔线
            rumps.MenuItem("▶ 启动" if not running else "⏹ 停止", callback=self.toggle_running),
            ("🎵 选择音效", sound_submenu),  # 子菜单格式
            None,
            rumps.MenuItem("❌ 退出", callback=self.quit_app),
        ]
    
    def set_sound_pack(self, pack_key, sender=None):
        """设置音效包"""
        save_pack(pack_key)
        global current_pack
        current_pack = pack_key
        self.title = pack_name(pack_key)[0]  # 取第一个 emoji 作为图标
        self.update_menu()
        rumps.notification("SlapBook", "已切换", pack_name(pack_key))
    
    def toggle_running(self, sender):
        """启动/停止监听"""
        global running, imu_thread, stop_event
        
        if not running:
            # 启动
            stop_event.clear()
            imu_thread = threading.Thread(target=imu_loop, daemon=True)
            imu_thread.start()
            running = True
            rumps.notification("SlapBook", "已启动", pack_name(current_pack))
        else:
            # 停止
            stop_event.set()
            running = False
            rumps.notification("SlapBook", "已停止", "")
        
        self.update_menu()
    
    def quit_app(self, sender):
        """退出应用"""
        global running
        if running:
            stop_event.set()
            running = False
        rumps.quit_application()


if __name__ == "__main__":
    app = SlapBookApp()
    app.run()
