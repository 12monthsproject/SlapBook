import Foundation
import AVFoundation

// MARK: - Models

enum VoiceGender: String, CaseIterable, Codable {
    case female = "female"
    case male   = "male"
    
    var displayName: String {
        switch self {
        case .female: return "性感女声 💋"
        case .male:   return "性感男声 🔥"
        }
    }
}

struct SoundPack {
    let gender: VoiceGender
    
    /// 文件名前缀，实际文件为 female_light_1.mp3 等
    var lightSounds:  [String]
    var mediumSounds: [String]
    var hardSounds:   [String]
    
    func sounds(for intensity: SlapIntensity) -> [String] {
        switch intensity {
        case .light:  return lightSounds
        case .medium: return mediumSounds
        case .hard:   return hardSounds
        }
    }
}

// MARK: - AudioPlayer

class AudioPlayer: NSObject {
    
    static let shared = AudioPlayer()
    
    private var players: [String: AVAudioPlayer] = [:]
    private var currentPlayer: AVAudioPlayer?
    
    /// 音量 0.0 ~ 1.0
    var volume: Float = 1.0
    
    // 预置音效包（使用从 SlapMac 提取的真实音效）
    let soundPacks: [VoiceGender: SoundPack] = [
        // 性感女声包：sexy_00 ~ sexy_41 共42条
        .female: SoundPack(
            gender: .female,
            lightSounds:  ["sexy_00", "sexy_01", "sexy_02", "sexy_03", "sexy_04",
                           "sexy_05", "sexy_06", "sexy_07", "sexy_08", "sexy_09",
                           "sexy_10", "sexy_11", "sexy_12", "sexy_13"],
            mediumSounds: ["sexy_14", "sexy_15", "sexy_16", "sexy_17", "sexy_18",
                           "sexy_19", "sexy_20", "sexy_21", "sexy_22", "sexy_23",
                           "sexy_24", "sexy_25", "sexy_26", "sexy_27"],
            hardSounds:   ["sexy_28", "sexy_29", "sexy_30", "sexy_31", "sexy_32",
                           "sexy_33", "sexy_34", "sexy_35", "sexy_36", "sexy_37",
                           "sexy_38", "sexy_39", "sexy_40", "sexy_41"]
        ),
        // 性感男声包：male_00 ~ male_09 共10条
        .male: SoundPack(
            gender: .male,
            lightSounds:  ["male_00_Ow",    "male_01_Ouch",   "male_02_Owwie",  "male_07_Hey"],
            mediumSounds: ["male_03_Hey_that_hurts", "male_04_Ow_stop_it",
                           "male_06_Ow_ow_ow", "male_09_That_stings"],
            hardSounds:   ["male_05_What_was_that_for", "male_08_Yowch"]
        )
    ]
    
    // MARK: - Playback
    
    func play(gender: VoiceGender, intensity: SlapIntensity) {
        guard let pack = soundPacks[gender] else { return }
        
        let sounds = pack.sounds(for: intensity)
        guard !sounds.isEmpty else { return }
        
        // 随机选择一条音效，避免重复
        let name = sounds.randomElement()!
        playSound(named: name)
    }
    
    // MARK: - Bundle Access Helper
    
    private var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle.main
        #endif
    }
    
    private func playSound(named name: String) {
        // 优先找 mp3，其次 wav
        let extensions = ["mp3", "wav", "m4a", "aiff"]
        var url: URL?
        
        for ext in extensions {
            if let u = resourceBundle.url(forResource: name, withExtension: ext) {
                url = u
                break
            }
        }
        
        guard let soundURL = url else {
            print("[AudioPlayer] 找不到音效文件: \(name)")
            // 找不到文件时播放系统音效作为占位
            playFallbackSound()
            return
        }
        
        // 缓存 player
        if players[name] == nil {
            do {
                let player = try AVAudioPlayer(contentsOf: soundURL)
                player.prepareToPlay()
                players[name] = player
            } catch {
                print("[AudioPlayer] 加载音效失败: \(error)")
                return
            }
        }
        
        let player = players[name]!
        player.volume = volume
        
        // 停止当前播放，立即响应新的拍打
        currentPlayer?.stop()
        currentPlayer?.currentTime = 0
        
        player.currentTime = 0
        player.play()
        currentPlayer = player
    }
    
    /// 没有音效文件时的系统音占位
    private func playFallbackSound() {
        NSSound.beep()
    }
    
    // MARK: - Preload
    
    func preloadAll() {
        // 预加载所有音效
        for (_, pack) in soundPacks {
            let all = pack.lightSounds + pack.mediumSounds + pack.hardSounds
            for name in all {
                let extensions = ["mp3", "wav", "m4a", "aiff"]
                for ext in extensions {
                    if let url = resourceBundle.url(forResource: name, withExtension: ext) {
                        do {
                            let player = try AVAudioPlayer(contentsOf: url)
                            player.prepareToPlay()
                            players[name] = player
                        } catch { }
                        break
                    }
                }
            }
        }
    }
}
