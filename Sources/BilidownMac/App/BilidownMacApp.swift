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
                .frame(minWidth: 700, minHeight: 460)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
