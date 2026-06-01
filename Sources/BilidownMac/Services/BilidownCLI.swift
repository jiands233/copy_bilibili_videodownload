import Foundation

struct DownloadRequest: Sendable {
    let url: String
    let outputDirectory: URL
    let quality: DownloadQuality
    let useChromeCookies: Bool
}

struct DownloadResult: Sendable {
    let exitCode: Int32
    let output: String
}

enum BilidownCLIError: LocalizedError {
    case executableNotFound

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "找不到内置的 bilidown 命令，请通过项目里的 build_and_run.sh 启动 App。"
        }
    }
}

final class BilidownCLI {
    func download(_ request: DownloadRequest) throws -> DownloadResult {
        let executable = try locateExecutable()
        let process = Process()
        let pipe = Pipe()

        process.executableURL = executable
        process.arguments = [
            "download",
            request.url,
            "--output",
            request.outputDirectory.path,
            "--quality",
            request.quality.cliValue
        ]

        if !request.useChromeCookies {
            process.arguments?.append("--no-cookies")
        }
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return DownloadResult(exitCode: process.terminationStatus, output: output)
    }

    private func locateExecutable() throws -> URL {
        let fileManager = FileManager.default
        let resourceCandidate = Bundle.main.resourceURL?
            .appendingPathComponent("mac-bilidown/bin/bilidown")

        let localCandidate = URL(fileURLWithPath: fileManager.currentDirectoryPath)
            .appendingPathComponent("mac-bilidown/bin/bilidown")

        let executablePath = CommandLine.arguments.first.map(URL.init(fileURLWithPath:))
        let executableRootCandidate = executablePath?
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("mac-bilidown/bin/bilidown")

        for candidate in [resourceCandidate, executableRootCandidate, localCandidate].compactMap({ $0 }) {
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        throw BilidownCLIError.executableNotFound
    }
}
