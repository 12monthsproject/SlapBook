#!/usr/bin/env python3
"""
SlapBook - 守护进程版本
后台运行，支持通过文件控制
"""

import os
import sys
import math
import random
import time
import subprocess
import signal
from pathlib import Path

# 路径配置
APP_DIR = Path(__file__).parent.parent
SOUNDS_DIR = APP_DIR / "Resources"
PID_FILE = Path("/tmp/slapbook.pid")
CONFIG_FILE = Path("/tmp/slapbook_config.txt")
QUIT_FILE = Path("/tmp/slapbook_quit")

# 音效包配置
SOUND_PACKS = {
    "female": {
        "light":  [f"sexy_{i:02d}.mp3" for i in range(0, 14)],
        "medium": [f"sexy_{i:02d}.mp3" for i in range(14, 28)],
        "hard":   [f"sexy_{i:02d}.mp3" for i in range(28, 42)],
    },
    "male": {
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


def load_config():
    """加载配置"""
    global current_pack
    if CONFIG_FILE.exists():
        pack = CONFIG_FILE.read_text().strip()
        if pack in SOUND_PACKS:
            current_pack = pack


def check_quit():
    """检查是否应该退出"""
    global running
    if QUIT_FILE.exists():
        QUIT_FILE.unlink()
        running = False
        return True
    return False


def signal_handler(sig, frame):
    """信号处理"""
    global running
    running = False


def show_notification(title, message):
    """显示 macOS 通知"""
    script = f'display notification "{message}" with title "{title}"'
    subprocess.run(["osascript", "-e", script], capture_output=True)


def main():
    global running, last_trigger
    
    # 设置信号处理
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    # 写入 PID 文件
    PID_FILE.write_text(str(os.getpid()))
    
    try:
        from macimu import IMU
    except ImportError:
        show_notification("SlapBook", "错误：缺少 macimu 库")
        return
    
    if not IMU.available():
        show_notification("SlapBook", "错误：未检测到加速度计")
        return
    
    show_notification("SlapBook", "已开始监听 💋")
    
    with IMU() as imu:
        for sample in imu.stream_accel():
            if not running or check_quit():
                break
            
            # 定期加载配置（检查声音切换）
            if int(time.time()) % 2 == 0:
                load_config()
            
            mag = math.sqrt(sample.x**2 + sample.y**2 + sample.z**2)
            impact = abs(mag - 1.0)
            intensity = detect_intensity(impact)
            
            if intensity:
                now = time.time()
                if now - last_trigger >= min_interval:
                    last_trigger = now
                    play_sound(intensity)
    
    # 清理
    if PID_FILE.exists():
        PID_FILE.unlink()
    show_notification("SlapBook", "已停止")


if __name__ == "__main__":
    main()
