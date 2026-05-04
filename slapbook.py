#!/usr/bin/env python3
"""
SlapBook - Python 版本
拍你的 MacBook，让它发出性感的声音

使用方法:
    sudo python3 slapbook.py

依赖:
    pip install macimu

音效文件路径:
    /Users/luke/WorkBuddy/Claw/SlapBook/Resources/
"""

import os
import sys
import math
import random
import time
import subprocess
from pathlib import Path

# 音效文件目录
SOUNDS_DIR = Path("/Users/luke/WorkBuddy/Claw/SlapBook/Resources")

# 音效包配置
SOUND_PACKS = {
    "female": {
        "light":  [f"sexy_{i:02d}.mp3" for i in range(0, 14)],   # 轻拍
        "medium": [f"sexy_{i:02d}.mp3" for i in range(14, 28)],  # 中等
        "hard":   [f"sexy_{i:02d}.mp3" for i in range(28, 42)],  # 重击
    },
    "male": {
        "light":  ["male_00_Ow.mp3", "male_01_Ouch.mp3", "male_02_Owwie.mp3", "male_07_Hey.mp3"],
        "medium": ["male_03_Hey_that_hurts.mp3", "male_04_Ow_stop_it.mp3", 
                   "male_06_Ow_ow_ow.mp3", "male_09_That_stings.mp3"],
        "hard":   ["male_05_What_was_that_for.mp3", "male_08_Yowch.mp3"],
    }
}

# 当前声音包
current_pack = "female"


def play_sound(intensity: str):
    """播放指定强度的随机音效"""
    sounds = SOUND_PACKS[current_pack].get(intensity, [])
    if not sounds:
        return
    
    sound_file = random.choice(sounds)
    sound_path = SOUNDS_DIR / sound_file
    
    if sound_path.exists():
        # 使用 afplay 后台播放
        subprocess.Popen(
            ["afplay", str(sound_path)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        print(f"🔊 播放: {sound_file}")
    else:
        print(f"⚠️  音效文件不存在: {sound_path}")


def detect_intensity(magnitude: float) -> str:
    """根据加速度大小判断拍打强度（高敏感度版本）"""
    if magnitude >= 0.8:
        return "hard"
    elif magnitude >= 0.4:
        return "medium"
    elif magnitude >= 0.15:
        return "light"
    return None


def main():
    print("=" * 50)
    print("💋 SlapBook - 拍你的 MacBook")
    print("=" * 50)
    print()
    print("使用方法:")
    print("  - 轻拍 MacBook 外壳 → 轻柔回应")
    print("  - 正常力度拍 → 中等回应")
    print("  - 用力拍 → 激烈回应")
    print()
    print("控制命令:")
    print("  - 按 Ctrl+C 退出")
    print("  - 输入 'm' 切换男声, 'f' 切换女声")
    print()
    print("正在初始化加速度计...")
    
    try:
        from macimu import IMU
    except ImportError:
        print("❌ 请先安装依赖: pip install macimu")
        sys.exit(1)
    
    if not IMU.available():
        print("❌ 未检测到 Apple Silicon 加速度计")
        print("   该功能需要 M2/M3/M4 等 Apple Silicon MacBook")
        sys.exit(1)
    
    print("✅ 加速度计已就绪！")
    print()
    
    # 防抖动：上次触发时间
    last_trigger = 0
    min_interval = 0.3  # 最小触发间隔（秒），更灵敏
    
    with IMU() as imu:
        print("👋 开始监听，拍你的 MacBook 吧！")
        print()
        
        for sample in imu.stream_accel():
            # 计算合加速度（去除重力后的冲击）
            mag = math.sqrt(sample.x**2 + sample.y**2 + sample.z**2)
            
            # 检测冲击（减去静止时的 1g 重力）
            impact = abs(mag - 1.0)
            
            # 判断是否达到阈值
            intensity = detect_intensity(impact)
            
            if intensity:
                now = time.time()
                if now - last_trigger >= min_interval:
                    last_trigger = now
                    
                    emoji = {"light": "💋", "medium": "🔥", "hard": "💥"}[intensity]
                    print(f"{emoji} 检测到拍打！强度: {intensity} ({impact:.2f}g)")
                    play_sound(intensity)


if __name__ == "__main__":
    # 检查 root 权限
    if os.geteuid() != 0:
        print("⚠️  需要 root 权限才能访问加速度计")
        print("   请使用: sudo python3 slapbook.py")
        print()
        # 尝试自动提权
        print("正在尝试自动提权...")
        os.execvp("sudo", ["sudo", sys.executable] + sys.argv)
    
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n👋 再见！")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ 错误: {e}")
        sys.exit(1)
