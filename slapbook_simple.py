#!/usr/bin/env python3
"""
SlapBook - 简化版本
后台运行，使用通知显示状态
"""

import os
import sys
import math
import random
import time
import subprocess
import signal
from pathlib import Path

# 路径配置 - 支持直接运行和通过 sudo 运行
if "SLAPBOOK_RESOURCES" in os.environ:
    # 从环境变量获取路径（Swift 前端传入）
    SOUNDS_DIR = Path(os.environ["SLAPBOOK_RESOURCES"])
else:
    # 自动检测路径
    APP_DIR = Path(__file__).parent.parent
    SOUNDS_DIR = APP_DIR / "Resources"
PID_FILE = Path("/tmp/slapbook.pid")
CONFIG_FILE = Path("/tmp/slapbook_config.txt")

# 音效包配置 —— 按文件名前缀分组，每包提供 light/medium/hard 三档
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
        "name": "🔢 数字音效",
        "light":  ["1_1.mp3", "1_2.mp3", "1_3.mp3", "2_1.mp3", "2_2.mp3", "2_3.mp3"],
        "medium": ["3_1.mp3", "3_2.mp3", "3_3.mp3", "4_1.mp3", "4_2.mp3",
                   "4_3.mp3", "5_1.mp3", "5_2.mp3", "5_3.mp3"],
        "hard":   ["6_1.mp3", "6_2.mp3", "6_3.mp3", "7_1.mp3", "7_2.mp3",
                   "8_1.mp3", "8_2.mp3", "8_3.mp3", "8_4.mp3",
                   "9_1.mp3", "9_2.mp3", "9_3.mp3"],
    },
}

# 全局状态
current_pack = "sexy"
last_trigger = 0
min_interval = 0.3
running = True


def play_sound(intensity: str):
    """播放指定强度的随机音效"""
    pack = SOUND_PACKS.get(current_pack, SOUND_PACKS["sexy"])
    sounds = pack.get(intensity, [])
    if not sounds:
        return

    # 过滤掉不存在的文件，再随机选一个
    valid = [s for s in sounds if (SOUNDS_DIR / s).exists()]
    if not valid:
        return

    sound_path = SOUNDS_DIR / random.choice(valid)
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
    """加载配置，返回是否发生了变化"""
    global current_pack
    if CONFIG_FILE.exists():
        pack = CONFIG_FILE.read_text().strip()
        if pack in SOUND_PACKS and pack != current_pack:
            current_pack = pack
            return True
    return False


def show_notification(title, message):
    """显示 macOS 通知"""
    script = f'display notification "{message}" with title "{title}"'
    subprocess.run(["osascript", "-e", script], capture_output=True)


def signal_handler(sig, frame):
    """信号处理"""
    global running
    running = False


def main():
    global running, last_trigger, current_pack

    # 设置信号处理
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    # 写入 PID 文件
    PID_FILE.write_text(str(os.getpid()))

    # 加载配置
    load_config()

    try:
        from macimu import IMU
    except ImportError:
        show_notification("SlapBook", "错误：缺少 macimu 库")
        return

    if not IMU.available():
        show_notification("SlapBook", "错误：未检测到加速度计")
        return

    pack_name = SOUND_PACKS[current_pack]["name"]
    show_notification("SlapBook", f"开始监听 · {pack_name}")

    try:
        with IMU() as imu:
            for sample in imu.stream_accel():
                if not running:
                    break

                # 每 0.5 秒检查一次配置（响应声音切换）
                if int(time.time() * 2) % 2 == 0:
                    if load_config():
                        pack_name = SOUND_PACKS[current_pack]["name"]
                        show_notification("SlapBook", f"已切换音效 · {pack_name}")

                mag = math.sqrt(sample.x**2 + sample.y**2 + sample.z**2)
                impact = abs(mag - 1.0)
                intensity = detect_intensity(impact)

                if intensity:
                    now = time.time()
                    if now - last_trigger >= min_interval:
                        last_trigger = now
                        play_sound(intensity)
    except Exception as e:
        show_notification("SlapBook", f"错误: {str(e)}")

    # 清理
    if PID_FILE.exists():
        PID_FILE.unlink()
    show_notification("SlapBook", "已停止")


if __name__ == "__main__":
    main()
