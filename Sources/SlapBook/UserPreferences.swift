import Foundation

class UserPreferences: ObservableObject {
    
    static let shared = UserPreferences()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Keys
    
    private enum Key {
        static let selectedGender     = "selectedGender"
        static let volume             = "volume"
        static let sensitivity        = "sensitivity"
        static let launchAtLogin      = "launchAtLogin"
        static let isEnabled          = "isEnabled"
    }
    
    // MARK: - Properties
    
    @Published var selectedGender: VoiceGender {
        didSet { defaults.set(selectedGender.rawValue, forKey: Key.selectedGender) }
    }
    
    @Published var volume: Float {
        didSet {
            defaults.set(volume, forKey: Key.volume)
            AudioPlayer.shared.volume = volume
        }
    }
    
    /// 灵敏度等级 1(低) ~ 3(高)，控制拍打阈值
    @Published var sensitivity: Int {
        didSet {
            defaults.set(sensitivity, forKey: Key.sensitivity)
            applySensitivity()
        }
    }
    
    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) }
    }
    
    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Key.isEnabled) }
    }
    
    // MARK: - Init
    
    private init() {
        selectedGender = VoiceGender(rawValue: defaults.string(forKey: Key.selectedGender) ?? "") ?? .female
        volume         = defaults.object(forKey: Key.volume) != nil ? defaults.float(forKey: Key.volume) : 1.0
        sensitivity    = defaults.object(forKey: Key.sensitivity) != nil ? defaults.integer(forKey: Key.sensitivity) : 2
        launchAtLogin  = defaults.bool(forKey: Key.launchAtLogin)
        isEnabled      = defaults.object(forKey: Key.isEnabled) != nil ? defaults.bool(forKey: Key.isEnabled) : true
        
        AudioPlayer.shared.volume = volume
    }
    
    // MARK: - Sensitivity
    
    /// 将灵敏度等级转换为实际阈值
    func applySensitivity(to detector: SlapDetector? = nil) {
        // 灵敏度越高 → 阈值越低 → 更容易触发
        switch sensitivity {
        case 1: // 低灵敏（需要用力拍）
            SlapDetector.lightThresholdOverride  = 1.5
            SlapDetector.mediumThresholdOverride = 2.5
            SlapDetector.hardThresholdOverride   = 4.0
        case 3: // 高灵敏（轻轻拍就触发）
            SlapDetector.lightThresholdOverride  = 0.5
            SlapDetector.mediumThresholdOverride = 1.0
            SlapDetector.hardThresholdOverride   = 2.0
        default: // 中等（默认）
            SlapDetector.lightThresholdOverride  = 0.8
            SlapDetector.mediumThresholdOverride = 1.5
            SlapDetector.hardThresholdOverride   = 2.5
        }
    }
}

// 用 static 属性传递阈值覆盖（简化跨对象通信）
extension SlapDetector {
    static var lightThresholdOverride: Double  = 0.8
    static var mediumThresholdOverride: Double = 1.5
    static var hardThresholdOverride: Double   = 2.5
}
