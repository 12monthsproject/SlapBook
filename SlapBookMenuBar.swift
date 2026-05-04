import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var pythonProcess: Process?
    var isRunning = false
    var currentPack = "sexy"
    
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
        // 读取当前配置
        readConfig()
        
        // 创建菜单栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()
        
        // 构建菜单
        buildMenu()
    }
    
    func readConfig() {
        let configFile = "/tmp/slapbook_config.txt"
        if FileManager.default.fileExists(atPath: configFile) {
            if let content = try? String(contentsOfFile: configFile, encoding: .utf8) {
                let pack = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if packNames[pack] != nil {
                    currentPack = pack
                }
            }
        }
    }
    
    func saveConfig(_ pack: String) {
        let configFile = "/tmp/slapbook_config.txt"
        try? pack.write(toFile: configFile, atomically: true, encoding: .utf8)
    }
    
    func updateIcon() {
        let emoji = String(packNames[currentPack]!.prefix(1))
        statusItem.button?.title = emoji
    }
    
    func buildMenu() {
        let menu = NSMenu()
        
        // 状态显示
        let statusText = isRunning ? "▶ 运行中" : "⏸ 已停止"
        let statusItem = NSMenuItem(title: "\(statusText) · \(packNames[currentPack]!)", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        
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
                
                // 延迟检查进程是否还在运行
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    if self?.pythonProcess?.isRunning == true {
                        self?.isRunning = true
                        self?.buildMenu()
                        self?.showNotification("SlapBook", "已开始监听")
                    } else {
                        // 读取错误输出
                        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        if let errorStr = String(data: errorData, encoding: .utf8), !errorStr.isEmpty {
                            self?.showNotification("启动失败", errorStr.prefix(100).description)
                        }
                        self?.pythonProcess = nil
                        self?.buildMenu()
                    }
                }
            } catch {
                showNotification("启动失败", error.localizedDescription)
            }
        }
    }
    
    func stopPython() {
        pythonProcess?.terminate()
        pythonProcess = nil
        isRunning = false
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
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = text
        NSUserNotificationCenter.default.deliver(notification)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
