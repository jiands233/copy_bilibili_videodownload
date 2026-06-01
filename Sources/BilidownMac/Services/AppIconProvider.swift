import AppKit

enum AppIconProvider {
    static func image() -> NSImage {
        if let resourceURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: resourceURL) {
            return image
        }

        return NSApp.applicationIconImage
    }

    static func installAsApplicationIcon() {
        NSApp.applicationIconImage = image()
    }
}
