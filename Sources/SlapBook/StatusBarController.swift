import AppKit

class StatusBarController: NSObject {
    
    // MARK: - Properties
    
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var menu: NSMenu!
    
    let slapDetector = SlapDetector()
    let prefs = UserPreferences.shared
    
    // 菜单项引用
    private var enableMenuItem: NSMenuItem?
    private var femaleMenuItem: NSMenuItem?
    private var maleMenuItem: NSMenuItem?
    private var volumeSlider: NSSlider?
    private var sensitivityControl: NSSegmentedControl?
    
    // 动画相关
    private var animationTimer: Timer?
    private let idleIcon   = "👋"
    private let activeIcons = ["💥", "✨", "🔥", "💋"]
    
    // MARK: - Init
    
    override init() {
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        
        super.init()
        
        setupStatusButton()
        buildMenu()
        setupSlapDetector()
        
        // 预加载音效
        AudioPlayer.shared.preloadAll()
    }
    
    // MARK: - UI Setup
    
    private func setupStatusButton() {
        if let button = statusItem.button {
            button.title = "👋"
            button.toolTip = "SlapBook - 拍它！"
        }
    }
    
    private func buildMenu() {
        menu = NSMenu()
        
        // ── 标题 ──────────────────────────────────────
        let titleItem = NSMenuItem(title: "SlapBook 💋", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(.separator())
        
        // ── 启用/禁用 ────────────────────────────────
        let enableItem = NSMenuItem(
            title: prefs.isEnabled ? "✅ 已启用" : "⬜ 已禁用",
            action: #selector(toggleEnabled),
            keyEquivalent: "e"
        )
        enableItem.target = self
        menu.addItem(enableItem)
        enableMenuItem = enableItem
        
        menu.addItem(.separator())
        
        // ── 声音类型 ─────────────────────────────────
        let voiceHeader = NSMenuItem(title: "声音类型", action: nil, keyEquivalent: "")
        voiceHeader.isEnabled = false
        menu.addItem(voiceHeader)
        
        let femaleItem = NSMenuItem(
            title: "💋 性感女声",
            action: #selector(selectFemale),
            keyEquivalent: ""
        )
        femaleItem.target = self
        femaleItem.state = prefs.selectedGender == .female ? .on : .off
        menu.addItem(femaleItem)
        femaleMenuItem = femaleItem
        
        let maleItem = NSMenuItem(
            title: "🔥 性感男声",
            action: #selector(selectMale),
            keyEquivalent: ""
        )
        maleItem.target = self
        maleItem.state = prefs.selectedGender == .male ? .on : .off
        menu.addItem(maleItem)
        maleMenuItem = maleItem
        
        menu.addItem(.separator())
        
        // ── 音量 ─────────────────────────────────────
        let volumeHeader = NSMenuItem(title: "音量", action: nil, keyEquivalent: "")
        volumeHeader.isEnabled = false
        menu.addItem(volumeHeader)
        
        let volumeView = makeSliderView(
            value: Double(prefs.volume),
            min: 0, max: 1,
            action: #selector(volumeChanged(_:))
        )
        let volumeItem = NSMenuItem()
        volumeItem.view = volumeView
        menu.addItem(volumeItem)
        
        menu.addItem(.separator())
        
        // ── 灵敏度 ───────────────────────────────────
        let sensitivityHeader = NSMenuItem(title: "灵敏度", action: nil, keyEquivalent: "")
        sensitivityHeader.isEnabled = false
        menu.addItem(sensitivityHeader)
        
        let sensitivityView = makeSensitivityView()
        let sensitivityItem = NSMenuItem()
        sensitivityItem.view = sensitivityView
        menu.addItem(sensitivityItem)
        
        menu.addItem(.separator())
        
        // ── 测试按钮 ─────────────────────────────────
        let testItem = NSMenuItem(title: "🎵 测试声音", action: #selector(testSound), keyEquivalent: "t")
        testItem.target = self
        menu.addItem(testItem)
        
        menu.addItem(.separator())
        
        // ── 关于 & 退出 ───────────────────────────────
        let aboutItem = NSMenuItem(title: "关于 SlapBook", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        let quitItem = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    // MARK: - Slap Detector
    
    private func setupSlapDetector() {
        // 应用当前灵敏度设置
        prefs.applySensitivity()
        
        slapDetector.onSlap = { [weak self] intensity in
            self?.handleSlap(intensity: intensity)
        }
        
        if prefs.isEnabled {
            slapDetector.startMonitoring()
        }
    }
    
    private func handleSlap(intensity: SlapIntensity) {
        guard prefs.isEnabled else { return }
        
        // 播放音效
        AudioPlayer.shared.play(gender: prefs.selectedGender, intensity: intensity)
        
        // 菜单栏图标动画
        animateIcon(intensity: intensity)
    }
    
    // MARK: - Icon Animation
    
    private func animateIcon(intensity: SlapIntensity) {
        animationTimer?.invalidate()
        
        let icon: String
        switch intensity {
        case .light:  icon = "💋"
        case .medium: icon = "🔥"
        case .hard:   icon = "💥"
        }
        
        statusItem.button?.title = icon
        
        // 1秒后恢复
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.statusItem.button?.title = self?.idleIcon ?? "👋"
        }
    }
    
    // MARK: - Actions
    
    @objc private func toggleEnabled() {
        prefs.isEnabled.toggle()
        
        if prefs.isEnabled {
            slapDetector.startMonitoring()
            enableMenuItem?.title = "✅ 已启用"
        } else {
            slapDetector.stopMonitoring()
            enableMenuItem?.title = "⬜ 已禁用"
        }
    }
    
    @objc private func selectFemale() {
        prefs.selectedGender = .female
        femaleMenuItem?.state = .on
        maleMenuItem?.state   = .off
    }
    
    @objc private func selectMale() {
        prefs.selectedGender = .male
        femaleMenuItem?.state = .off
        maleMenuItem?.state   = .on
    }
    
    @objc private func volumeChanged(_ sender: NSSlider) {
        prefs.volume = sender.floatValue
    }
    
    @objc private func sensitivityChanged(_ sender: NSSegmentedControl) {
        prefs.sensitivity = sender.selectedSegment + 1 // 1~3
    }
    
    @objc private func testSound() {
        AudioPlayer.shared.play(gender: prefs.selectedGender, intensity: .medium)
        animateIcon(intensity: .medium)
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "SlapBook 💋"
        alert.informativeText = "拍你的 MacBook，让它发出性感的回应！\n\n版本 1.0\n\n用 ❤️ 制作"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    // MARK: - Custom Views
    
    private func makeSliderView(value: Double, min: Double, max: Double, action: Selector) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 30))
        
        let slider = NSSlider(frame: NSRect(x: 20, y: 5, width: 160, height: 20))
        slider.minValue = min
        slider.maxValue = max
        slider.doubleValue = value
        slider.target = self
        slider.action = action
        slider.isContinuous = true
        
        container.addSubview(slider)
        volumeSlider = slider
        return container
    }
    
    private func makeSensitivityView() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 32))
        
        let segmented = NSSegmentedControl(
            labels: ["低", "中", "高"],
            trackingMode: .selectOne,
            target: self,
            action: #selector(sensitivityChanged(_:))
        )
        segmented.frame = NSRect(x: 20, y: 4, width: 160, height: 24)
        segmented.selectedSegment = prefs.sensitivity - 1
        
        container.addSubview(segmented)
        sensitivityControl = segmented
        return container
    }
}
