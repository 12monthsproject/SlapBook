#!/bin/bash
# SlapBook 打包脚本 - Swift 菜单栏版本

set -e

APP_NAME="SlapBook"
APP_VERSION="1.2.0"
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

# 复制音效资源
cp -r Resources/* "${APP_BUNDLE}/Contents/Resources/"

# 创建嵌入式 Python 虚拟环境
echo "🐍 创建嵌入式 Python 环境..."
PYTHON_VENV="${APP_BUNDLE}/Contents/Resources/venv"
python3 -m venv "${PYTHON_VENV}"
"${PYTHON_VENV}/bin/pip" install --quiet macimu

# 编译 Swift 菜单栏
echo "🔨 编译 Swift 菜单栏..."
swiftc -O -o "${APP_BUNDLE}/Contents/MacOS/SlapBook" SlapBookMenuBar.swift

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
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 SlapBook. All rights reserved.</string>
</dict>
</plist>
EOF

# 创建图标
echo "🎨 创建图标..."
python3 << 'PYEOF'
from PIL import Image, ImageDraw
import subprocess
import tempfile
import shutil
from pathlib import Path

input_path = "/Users/luke/Personal/picture/青蛙精-方.png"
output_path = "build/SlapBook.app/Contents/Resources/AppIcon.icns"

def add_rounded_corners(img, radius_ratio=0.2):
    """为图片添加 macOS 风格的圆角"""
    size = img.size[0]
    radius = int(size * radius_ratio)
    
    # 创建圆角遮罩
    mask = Image.new('L', img.size, 0)
    draw = ImageDraw.Draw(mask)
    
    # 绘制圆角矩形
    draw.rounded_rectangle([0, 0, size, size], radius=radius, fill=255)
    
    # 应用遮罩
    img_with_alpha = img.copy()
    img_with_alpha.putalpha(mask)
    return img_with_alpha

img = Image.open(input_path)
if img.mode != 'RGBA':
    img = img.convert('RGBA')

sizes = [16, 32, 128, 256, 512]
temp_dir = tempfile.mkdtemp()
iconset_dir = Path(temp_dir) / "icon.iconset"
iconset_dir.mkdir()

try:
    for size in sizes:
        # 调整圆角半径比例，大图标用更小的比例保持视觉一致
        radius_ratio = 0.18 if size >= 128 else 0.22
        
        resized = img.resize((size, size), Image.LANCZOS)
        rounded = add_rounded_corners(resized, radius_ratio)
        rounded.save(iconset_dir / f"icon_{size}x{size}.png", 'PNG')
        
        resized2x = img.resize((size*2, size*2), Image.LANCZOS)
        rounded2x = add_rounded_corners(resized2x, radius_ratio)
        rounded2x.save(iconset_dir / f"icon_{size}x{size}@2x.png", 'PNG')
    
    result = subprocess.run(
        ['iconutil', '-c', 'icns', str(iconset_dir), '-o', output_path],
        capture_output=True
    )
    
    if result.returncode != 0:
        print(f"⚠️  iconutil 失败: {result.stderr.decode()}")
    else:
        print("✅ 图标创建成功（已添加圆角）")
finally:
    shutil.rmtree(temp_dir)
PYEOF

# 注入图标
echo "🎨 注入图标到 App Bundle..."
osascript << ASEOF
use framework "Foundation"
use framework "AppKit"
use scripting additions
set iconImage to current application's NSImage's alloc()'s initWithContentsOfFile:"${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
current application's NSWorkspace's sharedWorkspace()'s setIcon:iconImage forFile:"${APP_BUNDLE}" options:0
ASEOF
echo "✅ 图标注入完成"

# 创建 README
cat > "${BUILD_DIR}/README.txt" << 'EOF'
SlapBook 💋 v1.2.0
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

# 创建 DMG
echo "💿 创建 DMG 镜像..."
DMG_TEMP="${BUILD_DIR}/dmg_contents"
mkdir -p "${DMG_TEMP}"
cp -r "${APP_BUNDLE}" "${DMG_TEMP}/"
cp "${BUILD_DIR}/README.txt" "${DMG_TEMP}/"
ln -s /Applications "${DMG_TEMP}/Applications"

hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_TEMP}" -ov -format UDZO "${BUILD_DIR}/${DMG_NAME}"
rm -rf "${DMG_TEMP}"

echo ""
echo "✅ 构建完成！"
echo "   App: ${APP_BUNDLE}"
echo "   DMG: ${BUILD_DIR}/${DMG_NAME}"
