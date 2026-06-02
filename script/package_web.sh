#!/usr/bin/env bash
set -euo pipefail

NODE_VERSION="${NODE_VERSION:-v22.16.0}"
APP_NAME="BilidownWeb"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_ROOT="$ROOT_DIR/dist"
PACKAGE_DIR="$DIST_ROOT/$APP_NAME"
CACHE_DIR="$ROOT_DIR/.cache/node"

node_arch_for() {
  case "$1" in
    darwin-arm64) printf 'arm64' ;;
    darwin-x64) printf 'x64' ;;
    *) return 1 ;;
  esac
}

download_node_runtime() {
  local platform="$1"
  local node_arch archive_name archive_path extract_dir runtime_dir

  node_arch="$(node_arch_for "$platform")"
  archive_name="node-$NODE_VERSION-darwin-$node_arch.tar.gz"
  archive_path="$CACHE_DIR/$archive_name"
  extract_dir="$CACHE_DIR/node-$NODE_VERSION-darwin-$node_arch"
  runtime_dir="$PACKAGE_DIR/runtime/$platform"

  mkdir -p "$CACHE_DIR" "$runtime_dir"

  if [[ ! -f "$archive_path" ]]; then
    echo "Downloading Node.js $NODE_VERSION for $platform..."
    curl -L "https://nodejs.org/dist/$NODE_VERSION/$archive_name" -o "$archive_path"
  fi

  if [[ ! -x "$extract_dir/bin/node" ]]; then
    rm -rf "$extract_dir"
    tar -xzf "$archive_path" -C "$CACHE_DIR"
  fi

  ditto "$extract_dir" "$runtime_dir/node"
}

write_launcher() {
  local launcher="$PACKAGE_DIR/启动 Bilidown Web.command"

  cat >"$launcher" <<'LAUNCHER'
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-4789}"
URL="http://127.0.0.1:$PORT"

case "$(uname -m)" in
  arm64) PLATFORM="darwin-arm64" ;;
  x86_64) PLATFORM="darwin-x64" ;;
  *)
    echo "不支持的 Mac 架构：$(uname -m)"
    read -r -p "按回车退出..."
    exit 10
    ;;
esac

NODE="$ROOT_DIR/runtime/$PLATFORM/node/bin/node"
if [[ ! -x "$NODE" ]]; then
  echo "找不到内置 Node：$NODE"
  read -r -p "请确认整个 BilidownWeb 文件夹完整，再按回车退出..."
  exit 10
fi

echo "Bilidown Web 正在启动：$URL"
echo "请保持这个终端窗口打开。关闭服务时按 Control+C。"

(sleep 1 && open "$URL") >/dev/null 2>&1 &
cd "$ROOT_DIR"
PORT="$PORT" "$NODE" web-bilidown/server.js
LAUNCHER

  chmod +x "$launcher"
}

write_readme() {
  cat >"$PACKAGE_DIR/使用说明.md" <<'README'
# Bilidown Web 使用说明

这是 Bilidown 的本地 Web 版。把整个 `BilidownWeb` 文件夹发给别人，对方在 Mac 上打开文件夹后，双击：

```text
启动 Bilidown Web.command
```

然后浏览器会自动打开：

```text
http://127.0.0.1:4789
```

## 注意

- 终端窗口需要保持打开，Web 服务才会继续运行。
- 关闭服务：回到终端按 `Control+C`。
- 第一次使用 Chrome Cookie 下载高清资源时，macOS 可能会弹出钥匙串授权。
- 如果端口被占用，可以在终端里这样启动：

```bash
PORT=4790 ./启动\ Bilidown\ Web.command
```

## 包内内容

- `web-bilidown/`：网页和本地后端。
- `mac-bilidown/`：真正下载视频的 CLI、yt-dlp、ffmpeg。
- `runtime/`：内置 Node.js 运行时，支持 Apple Silicon 和 Intel Mac。
- `Assets/`：图标资源。
README
}

main() {
  rm -rf "$PACKAGE_DIR"
  mkdir -p "$PACKAGE_DIR"

  echo "Copying Bilidown files..."
  ditto "$ROOT_DIR/web-bilidown" "$PACKAGE_DIR/web-bilidown"
  ditto "$ROOT_DIR/mac-bilidown" "$PACKAGE_DIR/mac-bilidown"
  mkdir -p "$PACKAGE_DIR/Assets"
  cp "$ROOT_DIR/Assets/AppIcon.png" "$PACKAGE_DIR/Assets/AppIcon.png"

  download_node_runtime darwin-arm64
  download_node_runtime darwin-x64
  write_launcher
  write_readme

  echo "Packaged Web folder:"
  echo "$PACKAGE_DIR"
}

main "$@"
