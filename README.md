# Bilidown Mac Workflow

这是一个 macOS 版 B 站视频下载工作流。给它一个 Bilibili 链接，它会下载并合并成 MP4 文件。

核心实现位于 [`mac-bilidown`](./mac-bilidown)：

- `bin/bilidown`：命令行入口
- `vendor/darwin-arm64`：Apple Silicon 依赖
- `vendor/darwin-x64`：Intel Mac 依赖
- `scripts/fetch-vendor-deps.zsh`：依赖修复/重拉脚本
- `使用说明.md`：中文使用文档

## 快速开始

```bash
./mac-bilidown/bin/bilidown doctor
./mac-bilidown/bin/bilidown download "https://www.bilibili.com/video/BV..."
```

默认输出目录：

```text
~/Downloads/Bilidown
```

完整说明见：

- [中文使用说明](./mac-bilidown/使用说明.md)
- [English README](./mac-bilidown/README.md)

## 说明

这个项目不复用原 Windows `.exe`，也不依赖原作者私有服务。下载能力基于 `yt-dlp` 的 Bilibili extractor 和内置 macOS `ffmpeg`。
