import AppKit
import SwiftUI

struct WindowIconInstaller: NSViewRepresentable {
    let iconStyle: AppIconStyle

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.isHidden = true
        installIcon(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        installIcon(from: nsView)
    }

    private func installIcon(from view: NSView) {
        DispatchQueue.main.async {
            AppIconProvider.installAsWindowIcon(style: iconStyle, for: view.window)
        }
    }
}
