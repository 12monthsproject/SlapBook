# SlapBook - 无需 Xcode 构建指南

> 不需要安装 12GB+ 的 Xcode，用命令行就能编译运行！

---

## 环境要求

- **macOS 13.0 (Ventura)** 或更高版本
- **Swift 5.9+**（macOS 自带，不需要单独安装）

验证 Swift 是否可用：
```bash
swift --version
```

如果显示类似 `swift-driver version: 1.87.3 Apple Swift version 5.9.2`，说明环境 OK。

---

## 快速开始

### 1. 进入项目目录

```bash
cd /Users/luke/WorkBuddy/Claw/SlapBook
```

### 2. 构建 App

```bash
swift build -c release
```

等待编译完成（约 10-30 秒）。

### 3. 运行 App

```bash
.build/release/SlapBook
```

菜单栏会出现 👋 图标，拍你的 MacBook 试试吧！

---

## 打包成可分发格式

### 方法一：直接运行（最简单）

```bash
# 复制到 Applications 目录
cp .build/release/SlapBook /Applications/SlapBook.app/Contents/MacOS/SlapBook
```

### 方法二：创建 .app 包结构

```bash
# 创建 App 包
mkdir -p /Applications/SlapBook.app/Contents/MacOS
mkdir -p /Applications/SlapBook.app/Contents/Resources

# 复制可执行文件
cp .build/release/SlapBook /Applications/SlapBook.app/Contents/MacOS/

# 复制音效资源
cp -r Resources/* /Applications/SlapBook.app/Contents/Resources/

# 创建 Info.plist
cat > /Applications/SlapBook.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>SlapBook</string>
    <key>CFBundleIdentifier</key>
    <string>com.yourname.slapbook</string>
    <key>CFBundleName</key>
    <string>SlapBook</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "✅ SlapBook.app 已创建在 /Applications/"
```

现在可以在 Launchpad 或 Finder 里双击运行了。

---

## 常用命令

```bash
# 调试模式编译（更快，但性能较差）
swift build

# 清理构建缓存
swift package clean

# 重新构建
swift build -c release --force-resolved-versions

# 查看依赖
swift package resolve

# 生成 Xcode 工程（如果你以后想用 Xcode 打开）
swift package generate-xcodeproj
```

---

## 开机自启设置

### 方法一：系统设置

1. 打开 **系统设置 → 通用 → 登录项**
2. 点击 **+** 添加 `/Applications/SlapBook.app`

### 方法二：命令行

```bash
# 添加到登录项
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/SlapBook.app", hidden:false}'

# 移除登录项
osascript -e 'tell application "System Events" to delete login item "SlapBook"'
```

---

## 常见问题

### Q: 提示 "No such module 'CoreMotion'"

确保在 macOS 上运行，且 Swift 版本 >= 5.9：
```bash
swift --version
```

### Q: 音效不播放

检查音效文件是否在正确位置：
```bash
ls /Applications/SlapBook.app/Contents/Resources/*.mp3 | head
```

应该有 `sexy_00.mp3` 等文件。

### Q: 如何停止运行

菜单栏点击 👋 图标 → 选择「退出」，或在终端按 `Ctrl+C`。

### Q: 可以上架 App Store 吗？

**命令行构建的版本不能直接上架 App Store**，因为：
- 缺少沙盒签名 (Sandbox entitlements)
- 缺少 App Store 分发证书

如果需要上架，还是需要 Xcode 来：
1. 创建 App ID
2. 配置签名和沙盒
3. 打包成 `.ipa` 或上传

---

## 技术说明

- **构建系统**: Swift Package Manager (SPM)
- **编译器**: `swiftc`（随 macOS 自带）
- **资源处理**: SPM 自动将 `Resources/` 目录打包到 Bundle
- **代码兼容**: 同时支持 SPM 和 Xcode 构建（通过 `SWIFT_PACKAGE` 宏判断）

---

## 与 Xcode 方案的对比

| 功能 | 命令行 (SPM) | Xcode |
|------|-------------|-------|
| 编译 App | ✅ 可以 | ✅ 可以 |
| 文件大小 | 轻量 (~5MB) | 轻量 (~5MB) |
| 需要安装 Xcode | ❌ 不需要 | ✅ 需要 (12GB+) |
| 上架 App Store | ❌ 不可以 | ✅ 可以 |
| 图形化调试 | ❌ 不可以 | ✅ 可以 |
| 代码补全/提示 | ❌ 基础 | ✅ 完善 |

**结论**: 如果只是自己用或给朋友用，命令行完全够用。要上架才需要 Xcode。
