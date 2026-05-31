# Third-Party Notices

This workflow vendors prebuilt binaries so it can run on macOS without a global package manager.

## yt-dlp

- Project: https://github.com/yt-dlp/yt-dlp
- Release used: `2026.03.17`
- Binary used: `yt-dlp_macos`
- Upstream license: Unlicense, with bundled third-party notices published by the project.
- Notices: https://github.com/yt-dlp/yt-dlp/blob/2026.03.17/THIRD_PARTY_LICENSES.txt

## ffmpeg-static

- Project: https://github.com/eugeneware/ffmpeg-static
- Release used: `b6.1.1`
- Required binaries used: `ffmpeg-darwin-arm64` and/or `ffmpeg-darwin-x64`
- Optional binaries supported by the fetcher: `ffprobe-darwin-arm64`, `ffprobe-darwin-x64`
- Upstream ffmpeg-static license files are stored beside each vendored architecture as `ffmpeg-static.LICENSE`.

## Checksums

The fetched files are verified before installation. The resulting vendored-file checksums are stored in:

```text
vendor/checksums.sha256
```
