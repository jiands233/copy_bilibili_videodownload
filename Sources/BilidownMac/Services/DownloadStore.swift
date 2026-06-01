import AppKit
import Foundation

@MainActor
final class DownloadStore: ObservableObject {
    @Published var videoURL = ""
    @Published var outputDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Downloads/Bilidown")
    @Published var quality: DownloadQuality = .best
    @Published var useChromeCookies = false
    @Published var state: DownloadState = .idle
    @Published var logText = ""

    private let cli = BilidownCLI()

    var canDownload: Bool {
        !state.isRunning && videoURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = outputDirectory
        panel.prompt = "选择"
        panel.message = "选择视频保存位置"

        if panel.runModal() == .OK, let url = panel.url {
            outputDirectory = url
        }
    }

    func download() {
        let trimmedURL = normalizedVideoURL(videoURL)
        guard trimmedURL.isEmpty == false else {
            state = .failed("请输入 B 站视频链接。")
            return
        }

        state = .running
        logText = "开始下载...\n"

        let request = DownloadRequest(
            url: trimmedURL,
            outputDirectory: outputDirectory,
            quality: quality,
            useChromeCookies: useChromeCookies
        )

        let capturedRequest = request

        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try BilidownCLI().download(capturedRequest)
                }.value

                await MainActor.run {
                    self.logText += result.output
                    if result.exitCode == 0 {
                        self.state = .succeeded("下载完成，文件已保存到 \(self.outputDirectory.path)")
                    } else {
                        self.state = .failed("下载失败，退出码 \(result.exitCode)。请查看日志。")
                    }
                }
            } catch {
                await MainActor.run {
                    self.state = .failed(error.localizedDescription)
                    self.logText += "\n\(error.localizedDescription)\n"
                }
            }
        }
    }

    private func normalizedVideoURL(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("https//") {
            return "https://" + trimmed.dropFirst("https//".count)
        }
        if trimmed.hasPrefix("http//") {
            return "http://" + trimmed.dropFirst("http//".count)
        }
        return trimmed
    }
}
