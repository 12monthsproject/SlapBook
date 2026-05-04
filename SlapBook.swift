import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var process: Process?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建菜单栏图标
        statusItem = NSStatusBar.shared.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "💋"
        
        // 构建菜单
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "⏸ 已停止 · 💋 女声娇喘", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        let startItem = NSMenuItem(title: "▶ 启动", action: #selector(toggleRunning), keyEquivalent: "")
        startItem.target = self
        menu.addItem(startItem)
        
        // 音效子菜单
        let soundMenu = NSMenu()
        let soundItem = NSMenuItem(title: "🎵 选择音效", action: nil, keyEquivalent: "")
        for (key, name) in [("sexy", "💋 女声娇喘"), ("yamete", "🇯🇵 Yamete"), 
                            ("male", "🔥 男声嚎叫"), ("punch", "🥊 拳击音效"),
                            ("fart", "💨 放屁"), ("goat", "🐐 山羊"),
                            ("number", "🔢 计数")] {
            let item = NSMenuItem(title: name, action: #selector(setSound(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = key
            soundMenu.addItem(item)
        }
        soundItem.submenu = soundMenu
        menu.addItem(soundItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "❌ 退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        
        // 启动 Python 后端
        startPython()
    }
    
    func startPython() {
        let appDir = Bundle.main.bundlePath
        let pythonPath = "\(appDir)/Contents/Resources/venv/bin/python3"
        let scriptPath = "\(appDir)/Contents/MacOS/slapbook_simple.py"
        
        process = Process()
        process?.executableURL = URL(fileURLWithPath: pythonPath)
        process?.arguments = [scriptPath]
        
        do {
            try process?.run()
        } catch {
            print("Failed to start Python: \(error)")
        }
    }
    
    @objc func toggleRunning() {
        // 通过信号或文件通知 Python 启动/停止
    }
    
    @objc func setSound(_ sender: NSMenuItem) {
        if let key = sender.representedObject as? String {
            let configFile = "/tmp/slapbook_config.txt"
            try? key.write(toFile: configFile, atomically: true, encoding: .utf8)
        }
    }
    
    @objc func quit() {
        process?.terminate()
        NSApplication.shared.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
