#!/bin/bash
# SlapBook 控制脚本

APP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PID_FILE="/tmp/slapbook.pid"
CONFIG_FILE="/tmp/slapbook_config.txt"

# 所有音效包定义（key 顺序即列表顺序）
PACK_KEYS=("sexy" "yamete" "male" "punch" "fart" "goat" "number")

# bash 3.2 兼容的 key→显示名 函数（macOS 默认 bash 不支持关联数组）
pack_name() {
    case "$1" in
        sexy)   echo "💋 女声娇喘" ;;
        yamete) echo "🇯🇵 Yamete" ;;
        male)   echo "🔥 男声嚎叫" ;;
        punch)  echo "🥊 拳击音效" ;;
        fart)   echo "💨 放屁" ;;
        goat)   echo "🐐 山羊" ;;
        number) echo "🔢 计数" ;;
        *)      echo "$1" ;;
    esac
}

# 检查是否运行中
is_running() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# 获取当前音效包 key
get_current_pack() {
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
    else
        echo "sexy"
    fi
}

# 获取当前音效包显示名
get_current_name() {
    local key
    key=$(get_current_pack)
    pack_name "$key"
}

# 显示主控制面板
show_menu() {
    local status="⏸ 已停止"
    if is_running; then
        status="▶ 运行中"
    fi
    local current_name
    current_name=$(get_current_name)

    osascript << EOF
set options to {"▶ 启动 SlapBook", "⏹ 停止 SlapBook", "🎵 切换音效包...", "❌ 退出"}
set selected to choose from list options ¬
    with title "SlapBook 控制面板" ¬
    with prompt "状态: $status    当前音效: $current_name" ¬
    default items {"▶ 启动 SlapBook"}
if selected is false then return ""
return item 1 of selected
EOF
}

# 显示音效包选择列表
show_sound_picker() {
    local current_key
    current_key=$(get_current_pack)
    local current_name
    current_name=$(pack_name "$current_key")

    # 构造 AppleScript 列表
    local list_items=""
    for key in "${PACK_KEYS[@]}"; do
        local display
        display=$(pack_name "$key")
        if [ "$key" = "$current_key" ]; then
            display="${display} ✓"
        fi
        if [ -z "$list_items" ]; then
            list_items="\"${display}\""
        else
            list_items="${list_items}, \"${display}\""
        fi
    done

    osascript << EOF
set options to {$list_items}
set selected to choose from list options ¬
    with title "选择音效包" ¬
    with prompt "当前: $current_name" ¬
    default items {"$current_name"}
if selected is false then return ""
return item 1 of selected
EOF
}

# 启动
start_slapbook() {
    if is_running; then
        osascript -e 'display notification "已经在运行中" with title "SlapBook"'
        return
    fi

    PYTHON_BIN="${APP_DIR}/Contents/Resources/venv/bin/python3"
    SCRIPT="${APP_DIR}/Contents/MacOS/slapbook_simple.py"

    # 获取密码
    PASSWORD=$(osascript << 'APPLESCRIPT' 2>/dev/null
        tell application "System Events"
            activate
            set dialogResult to display dialog "SlapBook 需要授权访问 MacBook 的加速度计。\n\n请输入您的密码：" with title "SlapBook 授权" with icon note buttons {"取消", "授权"} default button "授权" with hidden answer default answer ""
            if button returned of dialogResult is "授权" then
                return text returned of dialogResult
            end if
        end tell
APPLESCRIPT
    )

    if [ -z "$PASSWORD" ]; then
        return
    fi

    # 验证密码
    echo "$PASSWORD" | sudo -S true 2>/dev/null
    if [ $? -ne 0 ]; then
        osascript -e 'display notification "密码错误" with title "SlapBook"'
        return
    fi

    # 启动
    sudo "$PYTHON_BIN" "$SCRIPT" &
    sleep 1

    if is_running; then
        local pack_name
        pack_name=$(get_current_name)
        osascript -e "display notification \"SlapBook 已启动 · $pack_name\" with title \"SlapBook\""
    else
        osascript -e 'display notification "启动失败" with title "SlapBook"'
    fi
}

# 停止
stop_slapbook() {
    if ! is_running; then
        osascript -e 'display notification "未在运行" with title "SlapBook"'
        return
    fi

    PID=$(cat "$PID_FILE")
    sudo kill "$PID" 2>/dev/null
    rm -f "$PID_FILE"
    osascript -e 'display notification "SlapBook 已停止" with title "SlapBook"'
}

# 切换音效包（弹出列表选择）
pick_sound_pack() {
    local selected
    selected=$(show_sound_picker 2>/dev/null)

    if [ -z "$selected" ] || [ "$selected" = "false" ]; then
        return
    fi

    # 去掉末尾的 " ✓"（如果有）
    selected="${selected% ✓}"

    # 找到对应 key
    local matched_key=""
    for key in "${PACK_KEYS[@]}"; do
        if [ "$(pack_name "$key")" = "$selected" ]; then
            matched_key="$key"
            break
        fi
    done

    if [ -n "$matched_key" ]; then
        echo "$matched_key" > "$CONFIG_FILE"
        local name
        name=$(pack_name "$matched_key")
        osascript -e "display notification \"已切换到 $name\" with title \"SlapBook\""
    fi
}

# 主循环
while true; do
    RESULT=$(show_menu 2>/dev/null)

    case "$RESULT" in
        "▶ 启动 SlapBook")
            start_slapbook
            ;;
        "⏹ 停止 SlapBook")
            stop_slapbook
            ;;
        "🎵 切换音效包...")
            pick_sound_pack
            ;;
        "❌ 退出" | "" | "false")
            exit 0
            ;;
    esac
done
