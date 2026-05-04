#!/usr/bin/env python3
"""
SlapBook - 带 GUI 菜单栏的版本
拍你的 MacBook，让它发出性感的声音
"""

import os
import sys
import math
import random
import time
import subprocess
import threading
from pathlib import Path

# 音效文件目录
APP_DIR = Path(__file__).parent.parent
SOUNDS_DIR = APP_DIR / "Resources"

# 音效包配置
SOUND_PACKS = {
    "female": {
        "name": "女声 💋",
        "light":  [f"sexy_{i:02d}.mp3" for i in range(0, 14)],
        "medium": [f"sexy_{i:02d}.mp3" for i in range(14, 28)],
        "hard":   [f"sexy_{i:02d}.mp3" for i in range(28, 42)],
    },
    "male": {
        "name": "男声 🔥",
        "light":  ["male_00_Ow.mp3", "male_01_Ouch.mp3", "male_02_Owwie.mp3", "male_07_Hey.mp3"],
        "medium": ["male_03_Hey_that_hurts.mp3", "male_04_Ow_stop_it.mp3", 
                   "male_06_Ow_ow_ow.mp3", "male_09_That_stings.mp3"],
        "hard":   ["male_05_What_was_that_for.mp3", "male_08_Yowch.mp3"],
    }
}

# 全局状态
current_pack = "female"
last_trigger = 0
min_interval = 0.3
running = True


def play_sound(intensity: str):
    """播放指定强度的随机音效"""
    sounds = SOUND_PACKS[current_pack].get(intensity, [])
    if not sounds:
        return
    
    sound_file = random.choice(sounds)
    sound_path = SOUNDS_DIR / sound_file
    
    if sound_path.exists():
        subprocess.Popen(
            ["afplay", str(sound_path)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )


def detect_intensity(magnitude: float) -> str:
    """根据加速度大小判断拍打强度"""
    if magnitude >= 0.8:
        return "hard"
    elif magnitude >= 0.4:
        return "medium"
    elif magnitude >= 0.15:
        return "light"
    return None


def set_sound_pack(pack_name: str):
    """设置声音包"""
    global current_pack
    current_pack = pack_name
    show_notification("SlapBook", f"已切换到{SOUND_PACKS[pack_name]['name']}")


def show_notification(title, message):
    """显示 macOS 通知"""
    script = f'display notification "{message}" with title "{title}"'
    subprocess.run(["osascript", "-e", script], capture_output=True)


def imu_loop():
    """IMU 监听循环（在后台线程运行）"""
    global last_trigger, running
    
    try:
        from macimu import IMU
    except ImportError:
        show_notification("SlapBook", "错误：缺少 macimu 库")
        return
    
    if not IMU.available():
        show_notification("SlapBook", "错误：未检测到加速度计")
        return
    
    with IMU() as imu:
        show_notification("SlapBook", "已开始监听 💋")
        for sample in imu.stream_accel():
            if not running:
                break
            
            mag = math.sqrt(sample.x**2 + sample.y**2 + sample.z**2)
            impact = abs(mag - 1.0)
            intensity = detect_intensity(impact)
            
            if intensity:
                now = time.time()
                if now - last_trigger >= min_interval:
                    last_trigger = now
                    play_sound(intensity)


def create_menu_bar():
    """创建 macOS 菜单栏应用"""
    try:
        import rumps
    except ImportError:
        # 如果没有 rumps，使用简单的后台运行
        print("rumps not available, running in background mode")
        imu_loop()
        return
    
    class SlapBookApp(rumps.App):
        def __init__(self):
            super().__init__("SlapBook", icon=None, quit_button=None)
            self.menu = [
                rumps.MenuItem("当前声音: 女声 💋", callback=None),
                None,
                rumps.MenuItem("切换到女声", callback=self.set_female),
                rumps.MenuItem("切换到男声", callback=self.set_male),
                None,
                rumps.MenuItem("退出", callback=self.quit_app),
            ]
            self.current_item = self.menu[0]
            
            # 启动 IMU 监听线程
            self.imu_thread = threading.Thread(target=imu_loop, daemon=True)
            self.imu_thread.start()
        
        def set_female(self, _):
            set_sound_pack("female")
            self.current_item.title = "当前声音: 女声 💋"
        
        def set_male(self, _):
            set_sound_pack("male")
            self.current_item.title = "当前声音: 男声 🔥"
        
        def quit_app(self, _):
            global running
            running = False
            rumps.quit_application()
    
    app = SlapBookApp()
    app.run()


def main():
    # 检查 root 权限
    if os.geteuid() != 0:
        show_notification("SlapBook", "需要授权才能访问加速度计")
        sys.exit(1)
    
    # 尝试使用 rumps 创建菜单栏
    try:
        create_menu_bar()
    except Exception as e:
        # 如果失败，回退到简单模式
        print(f"GUI mode failed: {e}")
        imu_loop()


if __name__ == "__main__":
    main()
