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
READY_FILE = Path("/tmp/slapbook_ready")     # 就绪标志：Swift 端据此判断「真的起来了」
QUIT_FILE = Path("/tmp/slapbook_quit")
# 以 sudo 运行时记录原登录用户，用于以用户身份播放音频 / 发通知
SUDO_USER = os.environ.get("SUDO_USER")


def _user_home():
    """取原登录用户的家目录（root 的 home 不是用户想要的）"""
    if SUDO_USER:
        try:
            import pwd
            return Path(pwd.getpwnam(SUDO_USER).pw_dir)
        except KeyError:
            return None
    return Path.home()


_HOME = _user_home()
LEGACY_CONFIG_FILE = Path("/tmp/slapbook_config.txt")
# 配置放家目录，重启不丢；读不到时兼容旧的 /tmp 位置
CONFIG_FILE = (_HOME / ".slapbook_config") if _HOME else LEGACY_CONFIG_FILE

# Swift 前端传入自身 PID：app 被强退/崩溃/注销后，后端据此自动退出，避免 root 孤儿进程
try:
    APP_PID = int(os.environ.get("SLAPBOOK_APP_PID") or 0) or None
except ValueError:
    APP_PID = None

# 每次启动的唯一令牌：写进就绪文件，前端只认本次令牌，
# 避免 /tmp 里残留的 root 属主文件（普通用户删不掉）造成「假启动成功」
RUN_ID = os.environ.get("SLAPBOOK_RUN_ID", "")

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
    # root 身份下 afplay 会落到错误的音频会话导致无声；有 SUDO_USER 时用原用户身份播放
    cmd = ["afplay", str(sound_path)]
    if os.geteuid() == 0 and SUDO_USER:
        cmd = ["sudo", "-u", SUDO_USER, "afplay", str(sound_path)]
    subprocess.Popen(
        cmd,
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


def load_config():
    """加载配置，返回是否发生了变化"""
    global current_pack
    src = CONFIG_FILE if CONFIG_FILE.exists() else LEGACY_CONFIG_FILE
    if src.exists():
        try:
            pack = src.read_text(encoding="utf-8", errors="ignore").strip()
        except OSError:
            return False
        if pack in SOUND_PACKS and pack != current_pack:
            current_pack = pack
            return True
    return False


def show_notification(title, message):
    """显示 macOS 通知

    用 osascript 的 argv 传参，而不是拼进脚本字符串——
    异常信息里带引号时不会破坏 AppleScript，也杜绝命令注入。
    """
    script = (
        "on run argv\n"
        "display notification (item 1 of argv) with title (item 2 of argv)\n"
        "end run"
    )
    cmd = ["osascript", "-e", script, str(message), str(title)]
    if os.geteuid() == 0 and SUDO_USER:
        cmd = ["sudo", "-u", SUDO_USER] + cmd
    subprocess.run(cmd, capture_output=True)


def write_flag(path, content):
    """安全写标志文件

    先 unlink 再用 O_CREAT|O_EXCL 创建：/tmp 是所有人可写的，如果攻击者
    预先放一个符号链接，root 的普通 open/write 会跟着链接写到任意文件。
    O_EXCL 遇到已存在的链接会直接失败，避免被利用。
    """
    try:
        os.unlink(path)
    except FileNotFoundError:
        pass
    fd = os.open(str(path), os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(content)


def app_alive():
    """检查前端 app 是否还活着（拿不到 PID 时视为存活，兼容命令行直跑）"""
    if APP_PID is None:
        return True
    try:
        os.kill(APP_PID, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def signal_handler(sig, frame):
    """信号处理"""
    global running
    running = False


def main():
    global running, last_trigger, current_pack

    # 设置信号处理
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    # 清理可能残留的退出/就绪标志，避免误判
    for flag in (QUIT_FILE, READY_FILE):
        if flag.exists():
            flag.unlink()

    # 写入 PID 文件
    write_flag(PID_FILE, str(os.getpid()))

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

    try:
        with IMU() as imu:
            # 真正进入采样后才通知 + 写就绪标志，避免「密码对但传感器没起来」被当成成功
            show_notification("SlapBook", f"开始监听 · {pack_name}")
            write_flag(READY_FILE, RUN_ID or str(os.getpid()))

            last_config_check = 0.0
            for sample in imu.stream_accel():
                if not running or QUIT_FILE.exists():
                    break

                # 每 0.5 秒检查一次配置（响应声音切换）
                now_ts = time.time()
                if now_ts - last_config_check >= 0.5:
                    last_config_check = now_ts
                    # app 已被强退/崩溃 → 自行退出，避免留下 root 孤儿进程继续放音
                    if not app_alive():
                        break
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
    if READY_FILE.exists():
        READY_FILE.unlink()
    if QUIT_FILE.exists():
        QUIT_FILE.unlink()
    show_notification("SlapBook", "已停止")


if __name__ == "__main__":
    main()
