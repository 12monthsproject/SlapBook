import Foundation
import IOKit
import IOKit.hid

/// 拍打强度等级
enum SlapIntensity {
    case light   // 0.3 ~ 0.8g
    case medium  // 0.8 ~ 1.5g
    case hard    // 1.5g+
}

/// 拍打事件回调
typealias SlapHandler = (SlapIntensity) -> Void

class SlapDetector {
    
    // MARK: - Properties
    
    private var device: IOHIDDevice?
    private var manager: IOHIDManager?
    private var lastSlapTime: Date = Date.distantPast
    
    /// 两次拍打之间的最小间隔（秒），防止连续触发
    var minimumInterval: TimeInterval = 0.5
    
    /// 各强度阈值（单位：g）
    var lightThreshold: Double  = 0.3
    var mediumThreshold: Double = 0.8
    var hardThreshold: Double   = 1.5
    
    /// 事件回调
    var onSlap: SlapHandler?
    
    /// 是否正在监听
    private(set) var isMonitoring: Bool = false
    
    // MARK: - Monitoring
    
    var isAvailable: Bool {
        return findAccelerometerDevice() != nil
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        guard let device = findAccelerometerDevice() else {
            print("[SlapDetector] 未找到加速度计设备（可能不是 Apple Silicon MacBook）")
            return
        }
        
        self.device = device
        
        // 打开设备
        let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            print("[SlapDetector] 无法打开设备: \(result)")
            return
        }
        
        // 注册回调
        let callback: IOHIDValueCallback = { context, _, _, value in
            let detector = Unmanaged<SlapDetector>.fromOpaque(context!).takeUnretainedValue()
            detector.handleValue(value)
        }
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputValueCallback(device, callback, selfPtr)
        
        // 开始调度
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        
        isMonitoring = true
        print("[SlapDetector] 开始监听加速度计")
    }
    
    func stopMonitoring() {
        guard let device = device, isMonitoring else { return }
        
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        
        self.device = nil
        isMonitoring = false
        print("[SlapDetector] 停止监听")
    }
    
    // MARK: - Device Discovery
    
    private func findAccelerometerDevice() -> IOHIDDevice? {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager
        
        // 设置匹配条件：Apple Silicon 加速度计的 VendorID 和 ProductID
        // 根据逆向工程，Apple 内置加速度计的 VID 通常是 0x05AC (Apple Inc.)
        let matching: [String: Any] = [
            kIOHIDDeviceUsagePageKey: kHIDPage_Sensor,
            kIOHIDDeviceUsageKey: kHIDUsage_Snsr_Accelerometer3D
        ]
        
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              let device = devices.first else {
            // 尝试更宽松的匹配
            return findDeviceByVendor()
        }
        
        return device
    }
    
    /// 通过 Vendor ID 查找 Apple 设备
    private func findDeviceByVendor() -> IOHIDDevice? {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        
        // Apple Inc. Vendor ID = 0x05AC (1452)
        let matching: [String: Any] = [
            kIOHIDVendorIDKey: 1452
        ]
        
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            return nil
        }
        
        // 查找包含加速度计相关属性的设备
        for device in devices {
            if let product = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String {
                // 检查是否是传感器类设备
                if product.lowercased().contains("sensor") ||
                   product.lowercased().contains("accelerometer") ||
                   product.lowercased().contains("motion") {
                    return device
                }
            }
        }
        
        // 如果没有找到特定设备，返回第一个 Apple HID 设备
        return devices.first
    }
    
    // MARK: - Processing
    
    private func handleValue(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let usagePage = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        
        // 只处理加速度计数据
        guard usagePage == kHIDPage_Sensor || usagePage == kHIDPage_GenericDesktop else { return }
        
        let rawValue = IOHIDValueGetScaledValue(value, kIOHIDValueScaleTypeCalibrated)
        
        // 根据 usage 判断是哪个轴
        var axisValue = Double(rawValue)
        
        // 转换为 g 单位（根据设备校准调整）
        // Apple Silicon 加速度计通常是 16-bit，需要缩放
        let gValue = abs(axisValue)
        
        // 检测冲击（简化版：只看数值突变）
        guard gValue >= lightThreshold else { return }
        
        // 防抖：间隔内不重复触发
        let now = Date()
        guard now.timeIntervalSince(lastSlapTime) >= minimumInterval else { return }
        lastSlapTime = now
        
        // 判断强度
        let intensity: SlapIntensity
        if gValue >= hardThreshold {
            intensity = .hard
        } else if gValue >= mediumThreshold {
            intensity = .medium
        } else {
            intensity = .light
        }
        
        print("[SlapDetector] 检测到拍打！加速度: \(String(format: "%.2f", gValue))g → \(intensity)")
        onSlap?(intensity)
    }
}

// MARK: - Threshold Overrides

extension SlapDetector {
    static var lightThresholdOverride: Double  = 0.3
    static var mediumThresholdOverride: Double = 0.8
    static var hardThresholdOverride: Double   = 1.5
}
