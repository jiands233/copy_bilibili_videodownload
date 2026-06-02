import AppKit
import SwiftUI

@main
struct BilidownMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var downloadStore = DownloadStore()

    var body: some Scene {
        WindowGroup("Bilidown Mac") {
            ContentView()
                .environmentObject(downloadStore)
                .frame(minWidth: 760, minHeight: 560)
        }
        .defaultSize(width: 880, height: 620)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowIconObserver: NSObjectProtocol?

    func applicationWillFinishLaunching(_ notification: Notification) {
        AppIconProvider.installAsApplicationIcon()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        AppIconProvider.installAsApplicationIcon()
        windowIconObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { notification in
            AppIconProvider.installCurrentStyleAsWindowIcon(for: notification.object as? NSWindow)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let windowIconObserver {
            NotificationCenter.default.removeObserver(windowIconObserver)
        }
    }
}
