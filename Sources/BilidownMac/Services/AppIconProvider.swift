import AppKit

enum AppIconStyle {
    case light
    case dark
    case transparent

    var resourceName: String {
        switch self {
        case .light:
            return "AppIcon"
        case .dark:
            return "AppIconDark"
        case .transparent:
            return "AppIconTransparent"
        }
    }
}

enum IconStylePreference: String, CaseIterable, Identifiable {
    case automatic
    case light
    case dark
    case transparent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .automatic:
            return "自动"
        case .light:
            return "默认"
        case .dark:
            return "深色"
        case .transparent:
            return "透明"
        }
    }

    func resolved(isDarkMode: Bool) -> AppIconStyle {
        switch self {
        case .automatic:
            return isDarkMode ? .dark : .light
        case .light:
            return .light
        case .dark:
            return .dark
        case .transparent:
            return .transparent
        }
    }
}

enum AppIconProvider {
    private static var currentStyle: AppIconStyle = .light

    static func image(style: AppIconStyle) -> NSImage {
        if let resourceURL = Bundle.main.url(forResource: style.resourceName, withExtension: "icns"),
           let image = NSImage(contentsOf: resourceURL) {
            return image
        }

        return NSApp.applicationIconImage
    }

    static func installAsApplicationIcon(style: AppIconStyle = .light) {
        currentStyle = style
        let icon = image(style: style)
        NSApp.applicationIconImage = icon
        installAsWindowIcon(icon)
    }

    static func installAsWindowIcon(style: AppIconStyle) {
        currentStyle = style
        installAsWindowIcon(image(style: style))
    }

    static func installAsWindowIcon(_ icon: NSImage) {
        for window in NSApp.windows {
            window.miniwindowImage = icon
        }
    }

    static func installAsWindowIcon(style: AppIconStyle, for window: NSWindow?) {
        guard let window else {
            return
        }

        currentStyle = style
        window.miniwindowImage = image(style: style)
    }

    static func installCurrentStyleAsWindowIcon(for window: NSWindow?) {
        installAsWindowIcon(style: currentStyle, for: window)
    }
}
