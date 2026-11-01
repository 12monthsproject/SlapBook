#!/bin/bash
# SlapBook 打包脚本 - Swift 菜单栏版本

set -e

APP_NAME="SlapBook"
APP_VERSION="1.3.0"
# 部署目标：必须显式给 swiftc，否则会用工具链默认值（当前为 macosx28.0），
# 导致二进制 minos 高于实际系统版本、LaunchServices 拒绝启动（报 -10825）。
DEPLOY_TARGET="macos13.0"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${APP_VERSION}.dmg"

echo "🚀 开始构建 ${APP_NAME} Swift菜单栏版..."

# 清理旧构建
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# 创建 .app 目录结构
echo "📦 创建 App 包..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# 复制 Python 后端脚本
cp slapbook_simple.py "${APP_BUNDLE}/Contents/MacOS/"
chmod +x "${APP_BUNDLE}/Contents/MacOS/slapbook_simple.py"

# 复制音效资源（兼容空目录，避免通配符失配导致 set -e 中断）
if [ -n "$(ls -A Resources 2>/dev/null)" ]; then
    cp -R Resources/. "${APP_BUNDLE}/Contents/Resources/"
fi

# 创建嵌入式 Python 虚拟环境
echo "🐍 创建嵌入式 Python 环境..."
PYTHON_VENV="${APP_BUNDLE}/Contents/Resources/venv"
# 注意：不能用 PATH 里第一个 python3 —— 可能指向工具链自带的临时运行时
# （例如 ~/.workbuddy/binaries/python/...），那样打出来的 app 依赖该路径，升级/清理即失效。
BASE_PYTHON=""
for p in /usr/local/bin/python3 /opt/homebrew/bin/python3 /usr/bin/python3; do
    if [ -x "$p" ]; then BASE_PYTHON="$p"; break; fi
done
if [ -z "${BASE_PYTHON}" ]; then
    echo "❌ 未找到可用的 python3，无法创建运行环境"
    exit 1
fi
echo "   基础解释器: ${BASE_PYTHON} ($("${BASE_PYTHON}" -V 2>&1))"

# 优先 --copies：把解释器复制进 bundle，避免出现指向 bundle 外的符号链接
# （codesign --deep --strict 会因此报 "invalid destination for symbolic link"）
if ! "${BASE_PYTHON}" -m venv --copies "${PYTHON_VENV}" 2>/dev/null; then
    echo "   ℹ️  该解释器不支持 --copies，改用符号链接模式"
    "${BASE_PYTHON}" -m venv "${PYTHON_VENV}"
fi
"${PYTHON_VENV}/bin/pip" install --quiet --no-cache-dir macimu

# 运行期不需要 pip（app 只用 macimu）。卸掉可减小包体，
# 也避免其中的 auth.py 之类的文件触发沙箱/安全策略导致后续打包失败。
"${PYTHON_VENV}/bin/python3" -m pip uninstall -y -q pip >/dev/null 2>&1 || true
if ! "${PYTHON_VENV}/bin/python3" -c "import macimu" >/dev/null 2>&1; then
    echo "❌ macimu 未正确安装，构建中止"
    exit 1
fi

# 编译 Swift 菜单栏
#
# 必须显式指定 -target：本机 Swift 工具链的默认 target 是 arm64-apple-macosx28.0，
# 不加的话二进制里会写入 minos 28.0，在 macOS 27.x 上 LaunchServices 会以
# -10825 (kLSIncompatibleSystemVersionErr) 拒绝启动，Finder 显示 🚫。
#
# 部署目标与 Info.plist 的 LSMinimumSystemVersion 保持一致（DEPLOY_TARGET）。
echo "🔨 编译 Swift 菜单栏 (target ${DEPLOY_TARGET})..."
swiftc -O -target "$(uname -m)-apple-${DEPLOY_TARGET}" \
    -o "${APP_BUNDLE}/Contents/MacOS/SlapBook" SlapBookMenuBar.swift

# 创建 Info.plist
cat > "${APP_BUNDLE}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>SlapBook</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.luke.slapbook</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 SlapBook. All rights reserved.</string>
</dict>
</plist>
EOF

# 创建图标（图标源可配置，缺失时跳过而不中断构建）
ICON_SOURCE="${ICON_SOURCE:-/Users/luke/Personal/picture/青蛙精-方.png}"
# 找一个带 Pillow 的 Python（系统自带的 3.9 通常没装）
ICON_PYTHON=""
for p in python3 /usr/local/bin/python3 /opt/homebrew/bin/python3; do
    if command -v "$p" >/dev/null 2>&1 && "$p" -c "import PIL" >/dev/null 2>&1; then
        ICON_PYTHON="$p"; break
    fi
done
if [ -f "${ICON_SOURCE}" ] && [ -z "${ICON_PYTHON}" ]; then
    echo "⚠️  未找到带 Pillow 的 Python，跳过图标生成（不影响构建，但 app 图标会是空白）"
fi
if [ -f "${ICON_SOURCE}" ] && [ -n "${ICON_PYTHON}" ]; then
echo "🎨 创建图标（使用 ${ICON_PYTHON}）..."
SLAPBOOK_ICON_SOURCE="${ICON_SOURCE}" "${ICON_PYTHON}" << 'PYEOF'
from PIL import Image, ImageDraw, ImageChops
import subprocess
import tempfile
import shutil
import os
from pathlib import Path

input_path = os.environ.get("SLAPBOOK_ICON_SOURCE", "")
output_path = "build/SlapBook.app/Contents/Resources/AppIcon.icns"

# macOS Big Sur 之后的图标规范：圆角方块只占画布的约 80%，四周留透明边距。
# 铺满整个画布会让图标在 Dock / Launchpad 里明显比别的 app 大一圈。
CONTENT_RATIO = 0.80
CORNER_RATIO = 0.2237   # 圆角半径占「内容方块」的比例（近似苹果 squircle）


def make_icon(img, size):
    """把原图缩到画布的 80% 居中，加圆角后输出 size×size 透明画布图标"""
    content_size = max(1, int(round(size * CONTENT_RATIO)))
    content = img.resize((content_size, content_size), Image.LANCZOS)

    # 圆角遮罩按内容尺寸计算
    radius = int(round(content_size * CORNER_RATIO))
    mask = Image.new('L', (content_size, content_size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, content_size - 1, content_size - 1], radius=radius, fill=255
    )

    # 与原图自带透明通道相乘，避免覆盖掉原本的透明区域
    alpha = ImageChops.multiply(content.getchannel('A'), mask)
    content.putalpha(alpha)

    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    offset = ((size - content_size) // 2, (size - content_size) // 2)
    canvas.paste(content, offset, content)
    return canvas


img = Image.open(input_path)
if img.mode != 'RGBA':
    img = img.convert('RGBA')

sizes = [16, 32, 128, 256, 512]
temp_dir = tempfile.mkdtemp()
iconset_dir = Path(temp_dir) / "icon.iconset"
iconset_dir.mkdir()

try:
    for size in sizes:
        make_icon(img, size).save(iconset_dir / f"icon_{size}x{size}.png", 'PNG')
        make_icon(img, size * 2).save(iconset_dir / f"icon_{size}x{size}@2x.png", 'PNG')

    result = subprocess.run(
        ['iconutil', '-c', 'icns', str(iconset_dir), '-o', output_path],
        capture_output=True
    )

    if result.returncode != 0:
        print(f"⚠️  iconutil 失败: {result.stderr.decode()}")
    else:
        print("✅ 图标创建成功（80% 画布 + 圆角，符合 macOS 规范）")
finally:
    shutil.rmtree(temp_dir)
PYEOF

echo "✅ 图标创建完成（由 CFBundleIconFile 指向 AppIcon.icns，无需 setIcon 注入）"
else
echo "⚠️  未找到图标源 ${ICON_SOURCE}，跳过图标生成（不影响构建）"
fi

# 创建 README
cat > "${BUILD_DIR}/README.txt" << EOF
SlapBook 💋 v${APP_VERSION}
==================

拍你的 MacBook，让它发出各种有趣的声音！

【Swift 菜单栏版使用说明】
1. 把 SlapBook.app 拖到 Applications 文件夹
2. 从 Applications 打开 SlapBook
3. 菜单栏会出现 💋 图标
4. 点击图标：
   - ▶ 启动 / ⏹ 停止 监听（需要输入密码授权）
   - 🎵 选择音效 → 展开子菜单选择声音
   - 图标会随音效变化（💋🔥🥊💨🐐🔢）
5. 拍你的 MacBook！

系统要求：
- macOS 13.0+
- Apple Silicon MacBook (M2/M3/M4)

音效来源：SlapMac (slapmac.com)
EOF

# 代码签名：刻意【不做】codesign，保留编译器自动生成的 linker-signed 状态
#
# 为什么不签（2026-11-01 实测结论，macOS 27.2）：
#   1.2.0 之所以能双击启动，正是因为它的 codesign 步骤被 FinderInfo 污染而失败了，
#   app 保持了 ld64 自动写入的 linker-signed（flags=0x20002 adhoc,linker-signed，
#   无 _CodeSignature 目录）。系统把这种 app 当作「未签名」→ 放行。
#
#   而真正执行 codesign --force --deep --sign - 之后（1.3.0），app 变成
#   flags=0x2(adhoc) + _CodeSignature 目录 + 资源封装，Gatekeeper 认为
#   「签了名但证书不可信」，open 直接报 -10825，Finder 图标显示 🚫。
#
#   对照实验：同一台机器上，全新编译的最小 app 只要做 ad-hoc 签名就报 -10825；
#   未签名的 1.2.0 则 open exit=0 正常启动。
#
# 如需正式分发给他人，正确做法是用 Apple Developer ID 证书签名 + notarytool 公证，
# 而不是 ad-hoc。自用场景保持不签名即可。
echo "🔏 跳过 ad-hoc 签名（保留 linker-signed，macOS 27 下可正常启动）"
# 去掉扩展属性（resource fork / FinderInfo 会污染 app，也可能触发 Gatekeeper 异常）
xattr -cr "${APP_BUNDLE}" 2>/dev/null || true
# 确保没有遗留的签名目录（增量构建或旧产物可能带入，会导致被判定为「已签名」）
rm -rf "${APP_BUNDLE}/Contents/_CodeSignature" 2>/dev/null || true

# 创建 DMG
echo "💿 创建 DMG 镜像..."
DMG_TEMP="${BUILD_DIR}/dmg_contents"
mkdir -p "${DMG_TEMP}"
# 必须用 ditto：cp -r 会丢弃 com.apple.cs.* 代码签名扩展属性（可执行脚本 .py 的签名
# 存在 xattr 里），导致 DMG 里的 app 变成「脱签」状态、图标带 🚫 禁用标识
ditto "${APP_BUNDLE}" "${DMG_TEMP}/$(basename "${APP_BUNDLE}")"
cp "${BUILD_DIR}/README.txt" "${DMG_TEMP}/"
ln -s /Applications "${DMG_TEMP}/Applications"

hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_TEMP}" -ov -format UDZO "${BUILD_DIR}/${DMG_NAME}"
rm -rf "${DMG_TEMP}"

echo ""
echo "✅ 构建完成！"
echo "   App: ${APP_BUNDLE}"
echo "   DMG: ${BUILD_DIR}/${DMG_NAME}"
