#!/usr/bin/env python3
"""
SlapBook 优雅启动器
提供原生 macOS 密码对话框，避免显示终端
"""

import os
import sys
import subprocess
import tempfile
from pathlib import Path


def show_password_dialog():
    """显示 macOS 原生密码对话框"""
    script = '''
    tell application "System Events"
        activate
        set dialogResult to display dialog "SlapBook 需要授权访问 MacBook 的加速度计传感器。\n\n请输入您的密码：" ¬
            with title "SlapBook 授权" ¬
            with icon note ¬
            buttons {"取消", "授权"} ¬
            default button "授权" ¬
            with hidden answer ¬
            default answer ""
        
        if button returned of dialogResult is "授权" then
            return text returned of dialogResult
        else
            return "CANCELLED"
        end if
    end tell
    '''
    
    result = subprocess.run(
        ['osascript', '-e', script],
        capture_output=True,
        text=True
    )
    
    if result.returncode != 0:
        return None
    
    password = result.stdout.strip()
    if password == "CANCELLED":
        return None
    
    return password


def check_sudo_access():
    """检查是否已有 sudo 权限（无需密码）"""
    result = subprocess.run(
        ['sudo', '-n', 'true'],
        capture_output=True
    )
    return result.returncode == 0


def run_with_password(password, script_path, python_bin):
    """使用提供的密码运行主程序"""
    # 创建 sudo 命令
    cmd = ['sudo', '-S', python_bin, script_path]
    
    # 使用密码运行
    proc = subprocess.Popen(
        cmd,
        stdin=subprocess.PIPE,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True  # 脱离终端
    )
    
    # 发送密码
    proc.stdin.write(f"{password}\n".encode())
    proc.stdin.flush()
    proc.stdin.close()
    
    return proc


def show_notification(title, message):
    """显示 macOS 通知"""
    script = f'''
    display notification "{message}" with title "{title}"
    '''
    subprocess.run(['osascript', '-e', script], capture_output=True)


def main():
    # 获取路径
    app_dir = Path(__file__).parent.parent
    script_path = app_dir / "MacOS" / "SlapBook"
    python_bin = app_dir / "Resources" / "venv" / "bin" / "python3"
    
    # 检查是否已有 sudo 权限
    if check_sudo_access():
        # 直接运行，无需密码
        subprocess.Popen(
            ['sudo', str(python_bin), str(script_path)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True
        )
        show_notification("SlapBook", "应用已启动！拍打你的 MacBook 吧 💋")
        return
    
    # 需要密码，显示对话框
    password = show_password_dialog()
    if password is None:
        show_notification("SlapBook", "启动已取消")
        return
    
    # 验证密码并运行
    try:
        # 先测试密码是否正确
        test_result = subprocess.run(
            ['sudo', '-S', '-k', 'true'],
            input=f"{password}\n",
            capture_output=True,
            text=True,
            timeout=5
        )
        
        if test_result.returncode != 0:
            show_notification("SlapBook", "密码错误，启动失败")
            return
        
        # 密码正确，启动主程序
        subprocess.Popen(
            ['sudo', str(python_bin), str(script_path)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True
        )
        
        show_notification("SlapBook", "应用已启动！拍打你的 MacBook 吧 💋")
        
    except Exception as e:
        show_notification("SlapBook", f"启动失败: {str(e)}")


if __name__ == "__main__":
    main()
