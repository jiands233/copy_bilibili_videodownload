#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-4789}"
URL="http://127.0.0.1:$PORT"

cd "$ROOT_DIR"

echo "Bilidown Web is starting at $URL"
echo "Press Ctrl+C to stop."

if command -v open >/dev/null 2>&1; then
  (sleep 1 && open "$URL") >/dev/null 2>&1 &
fi

PORT="$PORT" node web-bilidown/server.js
