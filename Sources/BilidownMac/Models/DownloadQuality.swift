import Foundation

enum DownloadQuality: String, CaseIterable, Identifiable, Sendable {
    case best
    case hd1080 = "1080p"
    case hd720 = "720p"
    case audio

    var id: String { rawValue }

    var label: String {
        switch self {
        case .best:
            return "最佳画质"
        case .hd1080:
            return "1080p"
        case .hd720:
            return "720p"
        case .audio:
            return "仅音频"
        }
    }

    var cliValue: String { rawValue }
}
