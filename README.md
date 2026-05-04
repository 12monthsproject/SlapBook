# SlapBook 💋

> 拍你的 MacBook，让它发出性感的回应。

受 [SlapMac](https://slapmac.com) 启发，用 Swift 原生实现，支持 App Store 上架。

---

## ✨ 功能

- **拍打检测**：利用 MacBook 内置加速度计，实时监测拍打动作
- **力度分级**：轻拍 / 中等 / 重击，三档触发不同音效
- **双声音包**：性感女声 💋 & 性感男声 🔥，随时切换
- **菜单栏 App**：不占 Dock，随时可用
- **随机播放**：每档 3 条音效随机选择，不重复
- **音量 & 灵敏度**：可调节，适应不同场景

---

## 🛠 技术栈

| 模块 | 技术 |
|------|------|
| 加速度计 | CoreMotion / CMMotionManager |
| 音频播放 | AVFoundation / AVAudioPlayer |
| UI | AppKit（菜单栏 NSStatusItem） |
| 偏好存储 | UserDefaults |
| 语言 | Swift 5.9 |
| 最低系统 | macOS 13.0 Ventura |

---

## 📁 项目结构

```
SlapBook/
├── SlapBook/
│   ├── AppDelegate.swift          # App 入口，菜单栏模式
│   ├── SlapDetector.swift         # 加速度计监听 & 拍打检测
│   ├── AudioPlayer.swift          # 音效播放 & 音效包管理
│   ├── UserPreferences.swift      # 用户偏好持久化
│   ├── StatusBarController.swift  # 菜单栏 UI
│   ├── Info.plist                 # App 配置
│   ├── SlapBook.entitlements      # 沙盒权限（App Store 必需）
│   └── Sounds/                   # 音效文件目录（mp3/wav）
│       ├── female_light_1.mp3
│       ├── female_light_2.mp3
│       ├── female_light_3.mp3
│       ├── female_medium_1.mp3
│       ├── female_medium_2.mp3
│       ├── female_medium_3.mp3
│       ├── female_hard_1.mp3
│       ├── female_hard_2.mp3
│       ├── female_hard_3.mp3
│       ├── male_light_1.mp3
│       ├── male_light_2.mp3
│       ├── male_light_3.mp3
│       ├── male_medium_1.mp3
│       ├── male_medium_2.mp3
│       ├── male_medium_3.mp3
│       ├── male_hard_1.mp3
│       ├── male_hard_2.mp3
│       └── male_hard_3.mp3
└── generate_sounds.py             # ElevenLabs 音效生成脚本
```

---

## 🎙 第一步：生成音效

音效需要用 ElevenLabs TTS API 生成（免费额度足够）：

### 1. 注册 ElevenLabs（免费）

前往 https://elevenlabs.io/sign-up 注册，免费账号每月 **10,000 字符**额度，生成这套 18 条音效只需约 **500 字符**。

### 2. 获取 API Key

登录后进入 Profile → API Key，复制你的 Key。

### 3. 运行生成脚本

```bash
cd /path/to/SlapBook

# 安装依赖
pip install elevenlabs

# 设置 API Key
export ELEVEN_API_KEY="你的API密钥"

# 运行生成
python3 generate_sounds.py
```

脚本会自动在 `SlapBook/Sounds/` 目录下生成 18 个 mp3 文件。

### 4. 也可以手动录制

如果你有更好的声音资源（真人录音、其他 TTS），只要按照命名规则放入 `Sounds/` 目录即可：

| 文件名 | 用途 |
|--------|------|
| `female_light_1~3.mp3` | 女声轻拍（3条随机） |
| `female_medium_1~3.mp3` | 女声中等力度（3条随机） |
| `female_hard_1~3.mp3` | 女声重击（3条随机） |
| `male_light_1~3.mp3` | 男声轻拍（3条随机） |
| `male_medium_1~3.mp3` | 男声中等力度（3条随机） |
| `male_hard_1~3.mp3` | 男声重击（3条随机） |

---

## 🔨 第二步：创建 Xcode 工程

### 1. 新建工程

```
File → New → Project
macOS → App → 命名为 SlapBook
Language: Swift
User Interface: Storyboard（稍后我们会删掉 storyboard）
Bundle Identifier: com.你的名字.slapbook
```

### 2. 替换代码文件

将本项目 `SlapBook/` 目录下的所有 `.swift` 文件拖入 Xcode，替换自动生成的 `AppDelegate.swift`，并删掉 `ViewController.swift` 和 `Main.storyboard`。

### 3. 添加音效

将 `Sounds/` 文件夹整体拖入 Xcode → 勾选 **"Add to target: SlapBook"** → **"Create folder references"**。

### 4. 配置 Info.plist

确保 `Info.plist` 包含：
```xml
<key>LSUIElement</key>
<true/>
```
（隐藏 Dock 图标，纯菜单栏 App）

删掉 `NSMainStoryboardFile` 这条（或设置为空字符串）。

### 5. 添加 Framework

Target → Build Phases → Link Binary with Libraries：
- `CoreMotion.framework`
- `AVFoundation.framework`

### 6. 设置 Entitlements

Target → Signing & Capabilities → + Capability → App Sandbox（启用）

确保 `.entitlements` 文件已包含 `com.apple.security.app-sandbox = true`。

### 7. 构建运行

`Cmd + R` 运行，菜单栏出现 👋 图标即成功。

拍你的 MacBook 试试 💋

---

## 🏪 上架 App Store

### 准备工作
1. 注册 [Apple Developer Program](https://developer.apple.com/programs/) ($99/年)
2. 创建 App ID 和 Distribution Certificate
3. 在 App Store Connect 创建 App 记录

### 审核注意事项
- **NSMotionUsageDescription** 必须填写（已在 Info.plist 中配置）
- **音效内容**：App Store 对音频内容有审核，建议音效暗示性但不露骨，通过审核的核心是"性感但不色情"
- **年龄分级**：建议设置 17+（Frequent/Intense Sexual Content and Nudity）
- **截图**：准备干净的 UI 截图，不要包含成人内容
- **App 描述**：强调"趣味互动"而非性暗示内容

### 关于 CoreMotion 在 App Store
macOS CoreMotion 无需特殊 entitlement，通过 App Sandbox 即可使用。

---

## 📝 音效文案参考

### 女声台词（英文，ElevenLabs 效果更好）

| 强度 | 台词 |
|------|------|
| 轻拍 | "Mm, that tickles~" |
| 轻拍 | "Oh~ hello there" |
| 轻拍 | "Hey~ be gentle" |
| 中等 | "Mmm~ I like that" |
| 中等 | "Oh yes, right there" |
| 中等 | "Mmm~ don't stop" |
| 重击 | "Oh my god~ yes!" |
| 重击 | "Ahh~ so good!" |
| 重击 | "Yes! Like that!" |

### 男声台词

| 强度 | 台词 |
|------|------|
| 轻拍 | "Hey~ what was that" |
| 轻拍 | "Mmm, interesting" |
| 轻拍 | "Oh~ I felt that" |
| 中等 | "Mmm~ keep going" |
| 中等 | "Yeah~ like that" |
| 中等 | "Ohh~ that's good" |
| 重击 | "Oh damn~ yes!" |
| 重击 | "Ahh~ don't stop!" |
| 重击 | "Yes! Give me more!" |

---

## 🔮 未来计划

- [ ] 中文声音包（普通话性感版）
- [ ] 更多角色包（学姐、总裁、ASMR...）
- [ ] 力度可视化仪表盘
- [ ] 整蛊模式（别人碰触发）
- [ ] iOS 版（摇手机触发）
- [ ] 自定义录音上传

---

## 📄 License

MIT License
