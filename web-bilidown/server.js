#!/usr/bin/env node

const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");
const { spawn } = require("node:child_process");

const rootDir = path.resolve(__dirname, "..");
const publicDir = path.join(__dirname, "public");
const cliPath = path.join(rootDir, "mac-bilidown", "bin", "bilidown");
const port = Number(process.env.PORT || 4789);

const mimeTypes = {
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".png": "image/png",
  ".svg": "image/svg+xml",
};

function sendJSON(response, statusCode, payload) {
  response.writeHead(statusCode, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
  });
  response.end(JSON.stringify(payload));
}

function sendText(response, statusCode, text) {
  response.writeHead(statusCode, { "content-type": "text/plain; charset=utf-8" });
  response.end(text);
}

function readBody(request) {
  return new Promise((resolve, reject) => {
    let body = "";
    request.on("data", (chunk) => {
      body += chunk;
      if (body.length > 1024 * 1024) {
        request.destroy();
        reject(new Error("Request body is too large."));
      }
    });
    request.on("end", () => {
      if (!body) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(body));
      } catch {
        reject(new Error("Expected JSON request body."));
      }
    });
    request.on("error", reject);
  });
}

function isBilibiliURL(value) {
  try {
    const parsed = new URL(value);
    const host = parsed.hostname.toLowerCase();
    return ["http:", "https:"].includes(parsed.protocol)
      && (host === "b23.tv" || host === "bilibili.com" || host.endsWith(".bilibili.com"));
  } catch {
    return false;
  }
}

function expandHome(value) {
  if (!value || typeof value !== "string") {
    return "";
  }
  if (value === "~") {
    return process.env.HOME || value;
  }
  if (value.startsWith("~/")) {
    return path.join(process.env.HOME || "", value.slice(2));
  }
  return value;
}

function runCLI(args) {
  return new Promise((resolve) => {
    const child = spawn(cliPath, args, {
      cwd: rootDir,
      env: {
        ...process.env,
        BILIDOWN_COOKIE_TIMEOUT: process.env.BILIDOWN_COOKIE_TIMEOUT || "20",
      },
      stdio: ["ignore", "pipe", "pipe"],
    });

    let stdout = "";
    let stderr = "";

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });
    child.on("error", (error) => {
      resolve({
        exitCode: 10,
        stdout,
        stderr: `${stderr}\n${error.message}`.trim(),
      });
    });
    child.on("close", (exitCode) => {
      resolve({ exitCode: exitCode ?? 30, stdout, stderr });
    });
  });
}

function chooseFolder() {
  return new Promise((resolve) => {
    const script = [
      "set pickedFolder to choose folder with prompt \"选择 Bilidown 视频保存位置\"",
      "POSIX path of pickedFolder",
    ].join("\n");
    const child = spawn("osascript", ["-e", script], {
      cwd: rootDir,
      stdio: ["ignore", "pipe", "pipe"],
    });

    let stdout = "";
    let stderr = "";

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });
    child.on("error", (error) => {
      resolve({ ok: false, output: error.message });
    });
    child.on("close", (exitCode) => {
      const output = [stdout, stderr].filter(Boolean).join("\n").trim();
      if (exitCode === 0 && stdout.trim()) {
        resolve({ ok: true, path: stdout.trim().replace(/\/$/, ""), output });
        return;
      }
      resolve({
        ok: false,
        output: output || "已取消选择文件夹。",
      });
    });
  });
}

function parseDownloadedFiles(stdout) {
  return stdout
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => path.isAbsolute(line) && /\.(mp4|m4a|mov|mkv|webm)$/i.test(line));
}

function serveStatic(request, response) {
  const requestPath = decodeURIComponent(new URL(request.url, `http://${request.headers.host}`).pathname);
  if (requestPath === "/assets/app-icon.png") {
    return serveFile(path.join(rootDir, "Assets", "AppIcon.png"), response);
  }

  const safePath = requestPath === "/" ? "/index.html" : requestPath;
  const filePath = path.normalize(path.join(publicDir, safePath));
  if (!filePath.startsWith(publicDir)) {
    sendText(response, 403, "Forbidden");
    return;
  }
  serveFile(filePath, response);
}

function serveFile(filePath, response) {
  fs.readFile(filePath, (error, content) => {
    if (error) {
      sendText(response, error.code === "ENOENT" ? 404 : 500, error.code === "ENOENT" ? "Not found" : "Server error");
      return;
    }
    const extension = path.extname(filePath);
    response.writeHead(200, {
      "content-type": mimeTypes[extension] || "application/octet-stream",
      "cache-control": "no-store",
    });
    response.end(content);
  });
}

async function handleAPI(request, response, route) {
  if (route === "/api/choose-folder" && request.method === "POST") {
    const result = await chooseFolder();
    sendJSON(response, result.ok ? 200 : 400, result);
    return;
  }

  if (route === "/api/doctor" && request.method === "GET") {
    const result = await runCLI(["doctor", "--skip-cookie-check"]);
    sendJSON(response, result.exitCode === 0 ? 200 : 500, {
      ok: result.exitCode === 0,
      exitCode: result.exitCode,
      output: [result.stdout, result.stderr].filter(Boolean).join("\n"),
    });
    return;
  }

  if (route === "/api/download" && request.method === "POST") {
    let body;
    try {
      body = await readBody(request);
    } catch (error) {
      sendJSON(response, 400, { ok: false, exitCode: 2, output: error.message });
      return;
    }

    const videoURL = String(body.url || "").trim();
    const quality = String(body.quality || "best");
    const playlist = body.playlist === "all" ? "all" : "current";
    const outputDirectory = expandHome(String(body.output || "~/Downloads/Bilidown").trim());
    const useCookies = body.useCookies !== false;

    if (!isBilibiliURL(videoURL)) {
      sendJSON(response, 400, {
        ok: false,
        exitCode: 2,
        output: "请输入有效的 bilibili.com 或 b23.tv 链接。",
      });
      return;
    }

    if (!["best", "1080p", "720p", "audio"].includes(quality)) {
      sendJSON(response, 400, {
        ok: false,
        exitCode: 2,
        output: "清晰度只能是 best、1080p、720p 或 audio。",
      });
      return;
    }

    const args = [
      "download",
      videoURL,
      "--quality",
      quality,
      "--playlist",
      playlist,
      "--output",
      outputDirectory,
    ];
    if (!useCookies) {
      args.push("--no-cookies");
    }

    const result = await runCLI(args);
    const output = [result.stdout, result.stderr].filter(Boolean).join("\n");
    sendJSON(response, result.exitCode === 0 ? 200 : 500, {
      ok: result.exitCode === 0,
      exitCode: result.exitCode,
      files: parseDownloadedFiles(result.stdout),
      output,
    });
    return;
  }

  sendJSON(response, 404, { ok: false, output: "Unknown API route." });
}

const server = http.createServer((request, response) => {
  const route = new URL(request.url, `http://${request.headers.host}`).pathname;
  if (route.startsWith("/api/")) {
    handleAPI(request, response, route).catch((error) => {
      sendJSON(response, 500, { ok: false, exitCode: 30, output: error.message });
    });
    return;
  }
  serveStatic(request, response);
});

server.listen(port, "127.0.0.1", () => {
  console.log(`Bilidown Web is running at http://127.0.0.1:${port}`);
});
