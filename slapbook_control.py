#!/usr/bin/env python3
"""
SlapBook 控制脚本
用于启动、停止和切换声音
"""

import os
import sys
import subprocess
from pathlib import Path

PID_FILE = Path("/tmp/slapbook.pid")
CONFIG_FILE = Path("/tmp/slapbook_config.txt")
QUIT_FILE = Path("/tmp/slapbook_quit")


def show_notification(title, message):
    """显示 macOS 通知"""
    script = f'display notification "{message}" with title "{title}"'
    subprocess.run(["osascript", "-e", script], capture_output=True)


def is_running():
    """检查是否正在运行"""
    if PID_FILE.exists():
        pid = PID_FILE.read_text().strip()
        result = subprocess.run(["ps", "-p", pid], capture_output=True)
        return result.returncode == 0
    return False


def start():
    """启动 SlapBook"""
    if is_running():
        show_notification("SlapBook", "已经在运行中")
        return
    
    # 获取路径
    app_dir = Path(__file__).parent
    python_bin = app_dir / "Contents" / "Resources" / "venv" / "bin" / "python3"
    script = app_dir / "Contents" / "MacOS" / "slapbook_daemon.py"
    
    # 启动守护进程
    subprocess.Popen(
        ["sudo", str(python_bin), str(script)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True
    )
    show_notification("SlapBook", "已启动 💋")


def stop():
    """停止 SlapBook"""
    if not is_running():
        show_notification("SlapBook", "未在运行")
        return
    
    # 创建退出标志文件
    QUIT_FILE.touch()
    show_notification("SlapBook", "正在停止...")


def set_female():
    """切换到女声"""
    CONFIG_FILE.write_text("female")
    show_notification("SlapBook", "已切换到女声 💋")


def set_male():
    """切换到男声"""
    CONFIG_FILE.write_text("male")
    show_notification("SlapBook", "已切换到男声 🔥")


def show_menu():
    """显示控制菜单"""
    status = "停止" if is_running() else "启动"
    
    # 获取当前声音
    current = "女声"
    if CONFIG_FILE.exists():
        pack = CONFIG_FILE.read_text().strip()
        current = "男声" if pack == "male" else "女声"
    
    script = f'''
    set options to {{"{status} SlapBook", "切换到女声 💋", "切换到男声 🔥", "退出菜单"}}
    set selected to choose from list options with title "SlapBook 控制面板" with prompt "当前状态: {'运行中' if is_running() else '已停止'} | 当前声音: {current}"
    return selected
    '''
    
    result = subprocess.run(
        ["osascript", "-e", script],
        capture_output=True,
        text=True
    )
    
    if result.returncode != 0:
        return None
    
    return result.stdout.strip()


def main():
    while True:
        choice = show_menu()
        
        if choice is None or choice == "退出菜单":
            break
        elif choice.startswith("启动"):
            start()
        elif choice.startswith("停止"):
            stop()
        elif choice.startswith("切换到女声"):
            set_female()
        elif choice.startswith("切换到男声"):
            set_male()


if __name__ == "__main__":
    main()
