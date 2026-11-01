import Cocoa
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var pythonProcess: Process?
    var isRunning = false
    var currentPack = "sexy"
    private var stateTimer: Timer?
    /// 本次启动的唯一令牌，只认本次写出的就绪文件
    private var pendingRunID: String?

    // 与 root 后端通信的标志文件
    private static let quitFile  = "/tmp/slapbook_quit"
    private static let readyFile = "/tmp/slapbook_ready"
    private static let pidFile   = "/tmp/slapbook.pid"
    // 旧版本配置位置（仅用于一次性迁移）
    private static let legacyConfigFile = "/tmp/slapbook_config.txt"

    /// 配置持久化到家目录（/tmp 重启即丢）
    private var configFile: String { NSHomeDirectory() + "/.slapbook_config" }

    let packNames = [
        "sexy": "💋 女声娇喘",
        "yamete": "🇯🇵 Yamete",
        "male": "🔥 男声嚎叫",
        "punch": "🥊 拳击音效",
        "fart": "💨 放屁",
        "goat": "🐐 山羊",
        "number": "🔢 计数"
    ]
    let packOrder = ["sexy", "yamete", "male", "punch", "fart", "goat", "number"]

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 请求通知权限（替代已废弃的 NSUserNotification）
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }

        // 读取当前配置
        readConfig()

        // 创建菜单栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()

        // 构建菜单
        buildMenu()
    }

    /// 强退 / 崩溃 / 注销 / 关机时也要停掉 root 后端，否则会被 launchd 收养继续跑
    func applicationWillTerminate(_ notification: Notification) {
        stopPython()
    }

    func readConfig() {
        for path in [configFile, Self.legacyConfigFile] {
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            let pack = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard packNames[pack] != nil else { continue }
            currentPack = pack
            if path != configFile { saveConfig(pack) }   // 从旧位置迁移
            return
        }
    }

    func saveConfig(_ pack: String) {
        try? pack.write(toFile: configFile, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configFile)
    }

    func updateIcon() {
        let emoji = String(packNames[currentPack]!.prefix(1))
        statusItem.button?.title = emoji
    }

    func buildMenu() {
        let menu = NSMenu()

        // 状态显示
        let statusText = isRunning ? "▶ 运行中" : "⏸ 已停止"
        let statusLine = NSMenuItem(title: "\(statusText) · \(packNames[currentPack]!)", action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)

        menu.addItem(NSMenuItem.separator())

        // 启动/停止
        let toggleItem = NSMenuItem(title: isRunning ? "⏹ 停止" : "▶ 启动", action: #selector(toggleRunning), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        // 音效子菜单
        let soundMenu = NSMenu()
        for key in packOrder {
            let prefix = (key == currentPack) ? "✓ " : "  "
            let item = NSMenuItem(title: "\(prefix)\(packNames[key]!)", action: #selector(setSound(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = key
            soundMenu.addItem(item)
        }
        let soundItem = NSMenuItem(title: "🎵 选择音效", action: nil, keyEquivalent: "")
        soundItem.submenu = soundMenu
        menu.addItem(soundItem)

        menu.addItem(NSMenuItem.separator())

        // 退出
        let quitItem = NSMenuItem(title: "❌ 退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    @objc func toggleRunning() {
        if !isRunning {
            startPython()
        } else {
            stopPython()
        }
        buildMenu()
    }

    func startPython() {
        // 已在运行则不重复启动（避免两个后端并存）
        if isRunning || (pythonProcess?.isRunning ?? false) { return }

        // 清理上次残留的标志文件，否则新后端会读到旧的 quit / ready 而误判
        for path in [Self.quitFile, Self.readyFile, Self.pidFile] {
            try? FileManager.default.removeItem(atPath: path)
        }

        // 每次启动生成唯一令牌：/tmp 里 root 属主的残留文件普通用户删不掉，
        // 只比对令牌才能确定就绪文件是本次启动写出的
        let runID = UUID().uuidString
        pendingRunID = runID

        let appDir = Bundle.main.bundlePath
        let pythonPath = "\(appDir)/Contents/Resources/venv/bin/python3"
        let scriptPath = "\(appDir)/Contents/MacOS/slapbook_simple.py"
        let resourcesPath = "\(appDir)/Contents/Resources"

        // 先请求密码并启动
        let alert = NSAlert()
        alert.messageText = "SlapBook 需要授权"
        alert.informativeText = "需要您的密码来访问加速度计"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "授权")
        alert.addButton(withTitle: "取消")

        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = input

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let password = input.stringValue

            pythonProcess = Process()
            pythonProcess?.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            pythonProcess?.arguments = ["-S", "-E", pythonPath, scriptPath]

            // 设置环境变量，让 Python 能找到资源
            var env = ProcessInfo.processInfo.environment
            env["SLAPBOOK_RESOURCES"] = resourcesPath
            // 传入自身 PID：app 被杀（强退/崩溃/注销）后，后端据此自动退出，避免 root 孤儿进程
            env["SLAPBOOK_APP_PID"] = String(ProcessInfo.processInfo.processIdentifier)
            // 本次启动令牌，后端写进就绪文件，用于确认「这份 ready 是本轮写的」
            env["SLAPBOOK_RUN_ID"] = runID
            pythonProcess?.environment = env

            // 捕获输出用于调试
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            pythonProcess?.standardOutput = outputPipe
            pythonProcess?.standardError = errorPipe

            let inputPipe = Pipe()
            pythonProcess?.standardInput = inputPipe

            do {
                try pythonProcess?.run()
                if let data = "\(password)\n".data(using: .utf8) {
                    inputPipe.fileHandleForWriting.write(data)
                    inputPipe.fileHandleForWriting.closeFile()
                }

                // 以后端写出的 ready 标志文件为准判断启动成功（不再靠 sudo 进程存活误判）
                self.waitForStart(errorPipe: errorPipe, attempt: 0)
            } catch {
                showNotification("启动失败", error.localizedDescription)
                resetState()
            }
        }
    }

    /// 轮询等待后端就绪（最多约 5 秒）；进程提前退出则读 stderr 回报原因
    private func waitForStart(errorPipe: Pipe, attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self, let proc = self.pythonProcess else { return }

            if self.isReadyForThisRun() {
                self.isRunning = true
                self.buildMenu()
                self.startStateTimer()
                self.showNotification("SlapBook", "已开始监听")
                return
            }

            if !proc.isRunning {
                self.handleStartFailure(errorPipe: errorPipe)
                return
            }

            if attempt < 25 {           // 25 × 0.2s ≈ 5s
                self.waitForStart(errorPipe: errorPipe, attempt: attempt + 1)
                return
            }

            // 超时仍未就绪：停掉后端并报错
            self.stopPython()
            self.showNotification("启动失败", "后端未在 5 秒内就绪")
            self.buildMenu()
        }
    }

    /// 就绪文件内容必须等于本次启动令牌，防止读到上一轮残留
    private func isReadyForThisRun() -> Bool {
        guard let token = pendingRunID,
              let content = try? String(contentsOfFile: Self.readyFile, encoding: .utf8) else {
            return false
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines) == token
    }

    /// 启动失败：后台读取 stderr（sudo 的 "Sorry, try again." 即密码错误），避免阻塞主线程
    private func handleStartFailure(errorPipe: Pipe) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorStr = String(data: errorData, encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                guard let self = self else { return }
                try? FileManager.default.removeItem(atPath: Self.readyFile)
                self.resetState()
                self.buildMenu()
                let detail = errorStr.trimmingCharacters(in: .whitespacesAndNewlines)
                self.showNotification("启动失败", detail.isEmpty ? "密码错误或后端启动失败" : String(detail.prefix(120)))
            }
        }
    }

    /// 停止后端：先写退出标志让其主动退出，再等它真正结束（避免快速「停止→启动」时两个后端并存）
    func stopPython() {
        let proc = pythonProcess
        if proc != nil {
            try? "quit".write(toFile: Self.quitFile, atomically: true, encoding: .utf8)
        }
        proc?.terminate()

        // 最多等 1.5 秒，让后端看到 quit 标志后自行退出
        let deadline = Date().addingTimeInterval(1.5)
        while let p = proc, p.isRunning, Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        if let p = proc, p.isRunning {
            p.interrupt()   // 兜底：SIGINT
        }

        resetState()
    }

    private func resetState() {
        stateTimer?.invalidate()
        stateTimer = nil
        pythonProcess = nil
        isRunning = false
    }

    /// 监听后端存活，异常退出时同步 UI（避免界面一直显示「运行中」）
    private func startStateTimer() {
        stateTimer?.invalidate()
        stateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self, let proc = self.pythonProcess else { return }
            if !proc.isRunning {
                self.resetState()
                self.buildMenu()
                self.showNotification("SlapBook", "后端已退出")
            }
        }
    }

    @objc func setSound(_ sender: NSMenuItem) {
        if let key = sender.representedObject as? String {
            currentPack = key
            saveConfig(key)
            updateIcon()
            buildMenu()
            showNotification("已切换", packNames[key]!)
        }
    }

    @objc func quit() {
        stopPython()
        NSApplication.shared.terminate(nil)
    }

    func showNotification(_ title: String, _ text: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = text
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
