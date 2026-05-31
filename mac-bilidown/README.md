# Bilidown Mac

Bilidown Mac is a self-contained macOS command-line workflow for downloading Bilibili videos as MP4 files. It is a clean-room workflow around `yt-dlp` and bundled macOS `ffmpeg` binaries, not a port of the Windows `.exe`.

## Quick Start

```bash
./mac-bilidown/scripts/fetch-vendor-deps.zsh
./mac-bilidown/bin/bilidown doctor
./mac-bilidown/bin/bilidown download "https://www.bilibili.com/video/BV..."
```

Downloaded videos go to `~/Downloads/Bilidown` by default. The final file path is printed after yt-dlp moves the completed file into place, which makes the command easy to call from Raycast, Shortcuts, Codex, shell scripts, or other automation tools.

## Commands

```bash
./mac-bilidown/bin/bilidown doctor [--url URL] [--skip-cookie-check]
./mac-bilidown/bin/bilidown info URL [--json] [--playlist current|all]
./mac-bilidown/bin/bilidown download URL [--output DIR] [--quality best|1080p|720p|audio] [--playlist current|all]
```

Defaults:

- `--output ~/Downloads/Bilidown`
- `--quality best`
- `--playlist current`
- `--cookies-from-browser chrome`
- `--merge-output-format mp4`

The dependency fetcher downloads the current Mac architecture by default. Use `./mac-bilidown/scripts/fetch-vendor-deps.zsh --all-arch` if you want to prebundle both Apple Silicon and Intel binaries, and add `--with-ffprobe` if another workflow needs ffprobe.

For video downloads, the format selector prefers H.264/AAC when Bilibili offers it, then falls back to yt-dlp's best compatible streams.

Use `--playlist all` when you intentionally want to download every item in a multi-part video or playlist. Use `--no-cookies` for public-only downloads.

## Chrome Login

The default mode reads your local Chrome cookies through `yt-dlp --cookies-from-browser chrome`. This keeps credentials on your Mac and helps unlock the same access level your browser has, such as 1080P or member-only formats when your account is entitled to them.

On first use, macOS may ask whether the terminal can access Chrome's Keychain item. Allow it if you want cookie-based downloads to work.

If a workflow cannot show the macOS prompt, Bilidown fails fast with exit code `20` after `20` seconds instead of hanging forever. You can change that window with `BILIDOWN_COOKIE_TIMEOUT=60`, or pass `--no-cookies` for public-only downloads.

## Exit Codes

- `0`: success
- `2`: argument or URL error
- `10`: bundled dependency missing or not executable
- `20`: Chrome/cookie access failed
- `30`: download, metadata, or merge failed

## Examples

Download a single video:

```bash
./mac-bilidown/bin/bilidown download "https://www.bilibili.com/video/BV..."
```

Download to a custom folder:

```bash
./mac-bilidown/bin/bilidown download "https://www.bilibili.com/video/BV..." --output "$HOME/Desktop/Bilibili"
```

Download every playlist item:

```bash
./mac-bilidown/bin/bilidown download "https://www.bilibili.com/video/BV..." --playlist all
```

Return metadata JSON:

```bash
./mac-bilidown/bin/bilidown info "https://www.bilibili.com/video/BV..." --json
```

## Scope

Version 1 focuses on "give it a Bilibili URL, get an MP4." It does not implement the original Windows app's GUI, tray controls, clipboard listener, cover download, danmaku, subtitles, background music extraction, or QR-code login.

Only download videos you have the right to access. This tool does not bypass Bilibili permissions; it uses the same account access available in your local Chrome session.
