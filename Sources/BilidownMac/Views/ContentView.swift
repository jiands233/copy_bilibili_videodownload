import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: DownloadStore

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HeaderView()

            VStack(alignment: .leading, spacing: 16) {
                LinkInputView(url: $store.videoURL)
                DownloadOptionsView(
                    outputDirectory: store.outputDirectory,
                    quality: $store.quality,
                    useChromeCookies: $store.useChromeCookies,
                    chooseOutputDirectory: store.chooseOutputDirectory
                )
            }

            HStack {
                Button {
                    store.download()
                } label: {
                    Label(store.state.isRunning ? "下载中..." : "下载视频", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!store.canDownload)

                StatusView(state: store.state)

                Spacer()
            }

            LogView(text: store.logText)
        }
        .padding(28)
    }
}

private struct HeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Bilidown Mac")
                .font(.largeTitle.bold())
            Text("输入 B 站链接，选择保存位置和清晰度，然后下载为 MP4。")
                .foregroundStyle(.secondary)
        }
    }
}

private struct LinkInputView: View {
    @Binding var url: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("视频链接")
                .font(.headline)
            TextField("https://www.bilibili.com/video/BV...", text: $url)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14, design: .monospaced))
        }
    }
}

private struct DownloadOptionsView: View {
    let outputDirectory: URL
    @Binding var quality: DownloadQuality
    @Binding var useChromeCookies: Bool
    let chooseOutputDirectory: () -> Void

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
            GridRow {
                Text("保存位置")
                    .font(.headline)
                HStack(spacing: 10) {
                    Text(outputDirectory.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button("选择文件夹", action: chooseOutputDirectory)
                }
            }

            GridRow {
                Text("清晰度")
                    .font(.headline)
                Picker("清晰度", selection: $quality) {
                    ForEach(DownloadQuality.allCases) { quality in
                        Text(quality.label).tag(quality)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
            }

            GridRow {
                Text("")
                Toggle("使用 Chrome Cookie（登录后可下载更高清晰度）", isOn: $useChromeCookies)
                    .toggleStyle(.checkbox)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct StatusView: View {
    let state: DownloadState

    var body: some View {
        switch state {
        case .idle:
            Text("准备就绪")
                .foregroundStyle(.secondary)
        case .running:
            ProgressView()
                .controlSize(.small)
            Text("正在调用下载器")
                .foregroundStyle(.secondary)
        case .succeeded(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .lineLimit(1)
                .truncationMode(.middle)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

private struct LogView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("日志")
                .font(.headline)
            ScrollView {
                Text(text.isEmpty ? "下载日志会显示在这里。" : text)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(text.isEmpty ? .tertiary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(12)
            }
            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            .frame(minHeight: 140)
        }
    }
}
