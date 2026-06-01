import Foundation

enum DownloadState: Equatable {
    case idle
    case running
    case succeeded(String)
    case failed(String)

    var isRunning: Bool {
        if case .running = self {
            return true
        }
        return false
    }
}
