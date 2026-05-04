import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var statusBarController: StatusBarController?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 隐藏 Dock 图标，只在菜单栏显示
        NSApp.setActivationPolicy(.accessory)
        
        statusBarController = StatusBarController()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        statusBarController?.slapDetector.stopMonitoring()
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
