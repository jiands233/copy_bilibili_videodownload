#!/usr/bin/env zsh

emulate -L zsh
set -e
set -u
set -o pipefail

readonly SCRIPT_PATH="${0:A}"
readonly ROOT_DIR="${SCRIPT_PATH:h:h}"
readonly VENDOR_DIR="$ROOT_DIR/vendor"

readonly YTDLP_VERSION="2026.03.17"
readonly FFMPEG_STATIC_VERSION="b6.1.1"
WITH_FFPROBE=0

print_usage() {
  cat <<'EOF'
Fetch vendored macOS dependencies for Bilidown Mac.

Usage:
  fetch-vendor-deps.zsh [--all-arch] [--platform darwin-arm64|darwin-x64] [--with-ffprobe]

Defaults:
  - downloads the current Mac architecture only
  - downloads required dependencies: yt-dlp and ffmpeg
  - skips optional ffprobe unless --with-ffprobe is provided
EOF
}

current_platform() {
  case "$(uname -m)" in
    arm64) print -r -- "darwin-arm64" ;;
    x86_64) print -r -- "darwin-x64" ;;
    *)
      print -r -- "unsupported architecture: $(uname -m)" >&2
      return 1
      ;;
  esac
}

download_checked() {
  local url="$1"
  local dest="$2"
  local expected_sha="$3"
  local mode="${4:-644}"
  local expected="${expected_sha#sha256:}"
  local tmp="$dest.download"
  local actual

  mkdir -p "${dest:h}"

  if [[ -f "$dest" ]]; then
    actual="$(shasum -a 256 "$dest" | awk '{print $1}')"
    if [[ "$actual" == "$expected" ]]; then
      chmod "$mode" "$dest"
      print -r -- "ok: ${dest#$ROOT_DIR/}"
      return 0
    fi
  fi

  print -r -- "download: ${dest#$ROOT_DIR/}"
  curl -L --fail --retry 3 --retry-delay 2 -o "$tmp" "$url"

  actual="$(shasum -a 256 "$tmp" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    rm -f "$tmp"
    print -r -- "sha256 mismatch for $dest" >&2
    print -r -- "expected: $expected" >&2
    print -r -- "actual:   $actual" >&2
    return 1
  fi

  mv "$tmp" "$dest"
  chmod "$mode" "$dest"
}

download_gzip_checked() {
  local url="$1"
  local dest="$2"
  local expected_gz_sha="$3"
  local expected_final_sha="$4"
  local mode="${5:-755}"
  local expected_gz="${expected_gz_sha#sha256:}"
  local expected_final="${expected_final_sha#sha256:}"
  local gz_tmp="$dest.gz.download"
  local out_tmp="$dest.download"
  local actual

  mkdir -p "${dest:h}"

  if [[ -f "$dest" ]]; then
    actual="$(shasum -a 256 "$dest" | awk '{print $1}')"
    if [[ "$actual" == "$expected_final" ]]; then
      chmod "$mode" "$dest"
      print -r -- "ok: ${dest#$ROOT_DIR/}"
      return 0
    fi
  fi

  print -r -- "download: ${dest#$ROOT_DIR/}.gz"
  curl -L --fail --retry 3 --retry-delay 2 -o "$gz_tmp" "$url"

  actual="$(shasum -a 256 "$gz_tmp" | awk '{print $1}')"
  if [[ "$actual" != "$expected_gz" ]]; then
    rm -f "$gz_tmp" "$out_tmp"
    print -r -- "sha256 mismatch for $url" >&2
    print -r -- "expected: $expected_gz" >&2
    print -r -- "actual:   $actual" >&2
    return 1
  fi

  gzip -dc "$gz_tmp" > "$out_tmp"
  actual="$(shasum -a 256 "$out_tmp" | awk '{print $1}')"
  if [[ "$actual" != "$expected_final" ]]; then
    rm -f "$gz_tmp" "$out_tmp"
    print -r -- "sha256 mismatch after decompressing $dest" >&2
    print -r -- "expected: $expected_final" >&2
    print -r -- "actual:   $actual" >&2
    return 1
  fi

  rm -f "$gz_tmp"
  mv "$out_tmp" "$dest"
  chmod "$mode" "$dest"
}

copy_checked() {
  local src="$1"
  local dest="$2"
  local expected_sha="$3"
  local mode="${4:-644}"
  local expected="${expected_sha#sha256:}"
  local actual

  actual="$(shasum -a 256 "$src" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    print -r -- "sha256 mismatch for source copy $src" >&2
    print -r -- "expected: $expected" >&2
    print -r -- "actual:   $actual" >&2
    return 1
  fi

  mkdir -p "${dest:h}"
  cp "$src" "$dest"
  chmod "$mode" "$dest"
  print -r -- "copy: ${dest#$ROOT_DIR/}"
}

write_checksums() {
  (
    cd "$ROOT_DIR"
    find vendor -type f ! -name checksums.sha256 -print0 |
      sort -z |
      xargs -0 shasum -a 256
  ) > "$VENDOR_DIR/checksums.sha256"
}

install_platform() {
  local platform="$1"
  local ytdlp_url="https://github.com/yt-dlp/yt-dlp/releases/download/$YTDLP_VERSION/yt-dlp_macos"
  local ytdlp_sha="sha256:e80c47b3ce712acee51d5e3d4eace2d181b44d38f1942c3a32e3c7ff53cd9ed5"

  mkdir -p "$VENDOR_DIR/$platform"
  download_checked "$ytdlp_url" "$VENDOR_DIR/$platform/yt-dlp" "$ytdlp_sha" 755

  case "$platform" in
    darwin-arm64)
      download_gzip_checked \
        "https://github.com/eugeneware/ffmpeg-static/releases/download/$FFMPEG_STATIC_VERSION/ffmpeg-darwin-arm64.gz" \
        "$VENDOR_DIR/darwin-arm64/ffmpeg" \
        "sha256:8923876afa8db5585022d7860ec7e589af192f441c56793971276d450ed3bbfa" \
        "sha256:a90e3db6a3fd35f6074b013f948b1aa45b31c6375489d39e572bea3f18336584" \
        755
      if (( WITH_FFPROBE )); then
        download_gzip_checked \
          "https://github.com/eugeneware/ffmpeg-static/releases/download/$FFMPEG_STATIC_VERSION/ffprobe-darwin-arm64.gz" \
          "$VENDOR_DIR/darwin-arm64/ffprobe" \
          "sha256:d986a8ec7b030899fe66a8a288ed809a3543338705a3ce178cfb85869c5d80be" \
          "sha256:bb2db6f5d8cef919da12fbf592119a987202a8c060a886f3cab091f9cab90b64" \
          755
      fi
      download_checked \
        "https://github.com/eugeneware/ffmpeg-static/releases/download/$FFMPEG_STATIC_VERSION/darwin-arm64.LICENSE" \
        "$VENDOR_DIR/darwin-arm64/ffmpeg-static.LICENSE" \
        "sha256:cb48bf09a11f5fb576cddb0431c8f5ed0a60157a9ec942adffc13907cbe083f2"
      ;;
    darwin-x64)
      download_gzip_checked \
        "https://github.com/eugeneware/ffmpeg-static/releases/download/$FFMPEG_STATIC_VERSION/ffmpeg-darwin-x64.gz" \
        "$VENDOR_DIR/darwin-x64/ffmpeg" \
        "sha256:929b375c1182d956c51f7ac25e0b2b0411fb01f6f407aa15c9758efeb4242106" \
        "sha256:ebdddc936f61e14049a2d4b549a412b8a40deeff6540e58a9f2a2da9e6b18894" \
        755
      if (( WITH_FFPROBE )); then
        download_gzip_checked \
          "https://github.com/eugeneware/ffmpeg-static/releases/download/$FFMPEG_STATIC_VERSION/ffprobe-darwin-x64.gz" \
          "$VENDOR_DIR/darwin-x64/ffprobe" \
          "sha256:d4da574d6e2e197bd259b47d69cf262df9e312af24ad960444f6d806d3d4c186" \
          "sha256:fa3add0ce901f7241abe0dfc0155d958fc834aca3f8ce61f87cc712ae669c1e0" \
          755
      fi
      download_checked \
        "https://github.com/eugeneware/ffmpeg-static/releases/download/$FFMPEG_STATIC_VERSION/darwin-x64.LICENSE" \
        "$VENDOR_DIR/darwin-x64/ffmpeg-static.LICENSE" \
        "sha256:2e1d16c72fd74e12063776371da757322f8b77589386532f4fd8634bde7de1af"
      ;;
    *)
      print -r -- "unknown platform: $platform" >&2
      return 1
      ;;
  esac
}

main() {
  local -a platforms
  platforms=("$(current_platform)")

  while (( $# )); do
    case "$1" in
      --all-arch)
        platforms=(darwin-arm64 darwin-x64)
        ;;
      --platform)
        shift
        (( $# )) || {
          print -r -- "missing value for --platform" >&2
          return 2
        }
        platforms=("$1")
        ;;
      --with-ffprobe)
        WITH_FFPROBE=1
        ;;
      -h|--help)
        print_usage
        return 0
        ;;
      *)
        print -r -- "unknown option: $1" >&2
        print_usage >&2
        return 2
        ;;
    esac
    shift
  done

  for platform in "${platforms[@]}"; do
    install_platform "$platform"
  done

  write_checksums
  print -r -- "wrote: ${VENDOR_DIR#$ROOT_DIR/}/checksums.sha256"
}

main "$@"
