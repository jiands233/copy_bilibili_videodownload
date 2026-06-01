import AppKit
import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("iconStylePreference") private var iconStylePreferenceRaw = IconStylePreference.automatic.rawValue
    @EnvironmentObject private var store: DownloadStore

    private var iconStylePreference: IconStylePreference {
        IconStylePreference(rawValue: iconStylePreferenceRaw) ?? .automatic
    }

    private var iconStyle: AppIconStyle {
        iconStylePreference.resolved(isDarkMode: colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            AppBackgroundView()

            VStack(alignment: .leading, spacing: 22) {
                HeaderView(iconStyle: iconStyle)

                VStack(alignment: .leading, spacing: 16) {
                    LinkInputView(url: $store.videoURL)
                    DownloadOptionsView(
                        outputDirectory: store.outputDirectory,
                        quality: $store.quality,
                        iconStylePreference: $iconStylePreferenceRaw,
                        useChromeCookies: $store.useChromeCookies,
                        chooseOutputDirectory: store.chooseOutputDirectory
                    )
                }
                .glassPanel(cornerRadius: 22)

                HStack(spacing: 14) {
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
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(.white.opacity(0.55), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.10), radius: 32, y: 18)
            .padding(.horizontal, 24)
            .padding(.top, 38)
            .padding(.bottom, 24)
        }
        .onAppear {
            AppIconProvider.installAsApplicationIcon(style: iconStyle)
        }
        .onChange(of: colorScheme) { newValue in
            let isDarkMode = newValue == .dark
            AppIconProvider.installAsApplicationIcon(style: iconStylePreference.resolved(isDarkMode: isDarkMode))
        }
        .onChange(of: iconStylePreferenceRaw) { _ in
            AppIconProvider.installAsApplicationIcon(style: iconStyle)
        }
    }
}

private struct AppBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(red: 0.90, green: 0.95, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    .blue.opacity(0.10),
                    .clear,
                    .white.opacity(0.30)
                ],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
        }
        .ignoresSafeArea()
    }
}

private struct HeaderView: View {
    let iconStyle: AppIconStyle

    var body: some View {
        HStack(spacing: 16) {
            Image(nsImage: AppIconProvider.image(style: iconStyle))
                .resizable()
                .frame(width: 68, height: 68)
                .shadow(color: .blue.opacity(0.16), radius: 10, y: 5)

            VStack(alignment: .leading, spacing: 6) {
                Text("Bilidown Mac")
                    .font(.largeTitle.bold())
                Text("输入 B 站链接，选择保存位置和清晰度，然后下载为 MP4。")
                    .foregroundStyle(.secondary)
            }
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
    @Binding var iconStylePreference: String
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

            GridRow {
                Text("App 图标")
                    .font(.headline)
                Picker("App 图标", selection: $iconStylePreference) {
                    ForEach(IconStylePreference.allCases) { preference in
                        Text(preference.label).tag(preference.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
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
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.45), lineWidth: 1)
            }
            .frame(minHeight: 140)
        }
    }
}

private struct GlassPanelModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.48), lineWidth: 1)
            }
    }
}

private extension View {
    func glassPanel(cornerRadius: CGFloat) -> some View {
        modifier(GlassPanelModifier(cornerRadius: cornerRadius))
    }
}
