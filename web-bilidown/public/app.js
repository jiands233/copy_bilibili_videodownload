const form = document.querySelector("#download-form");
const doctorButton = document.querySelector("#doctor-button");
const downloadButton = document.querySelector("#download-button");
const chooseFolderButton = document.querySelector("#choose-folder-button");
const outputInput = document.querySelector("#output");
const statusText = document.querySelector("#status");
const log = document.querySelector("#log");

function setStatus(message, type = "") {
  statusText.textContent = message;
  statusText.className = type;
}

function setBusy(isBusy) {
  downloadButton.disabled = isBusy;
  doctorButton.disabled = isBusy;
  chooseFolderButton.disabled = isBusy;
  downloadButton.textContent = isBusy ? "正在下载..." : "下载视频";
}

function showOutput(data) {
  const files = Array.isArray(data.files) && data.files.length
    ? `\n\n已保存文件：\n${data.files.map((file) => `- ${file}`).join("\n")}`
    : "";
  log.textContent = `${data.output || "没有输出。"}${files}`;
}

doctorButton.addEventListener("click", async () => {
  setBusy(true);
  setStatus("正在检查环境...");
  log.textContent = "正在运行 bilidown doctor...";

  try {
    const response = await fetch("/api/doctor");
    const data = await response.json();
    showOutput(data);
    setStatus(data.ok ? "环境正常" : `检查失败，退出码 ${data.exitCode}`, data.ok ? "success" : "error");
  } catch (error) {
    log.textContent = error.message;
    setStatus("检查失败", "error");
  } finally {
    setBusy(false);
  }
});

chooseFolderButton.addEventListener("click", async () => {
  chooseFolderButton.disabled = true;
  const oldLabel = chooseFolderButton.textContent;
  chooseFolderButton.textContent = "选择中...";
  setStatus("请在弹出的窗口里选择保存文件夹");

  try {
    const response = await fetch("/api/choose-folder", { method: "POST" });
    const data = await response.json();
    if (!data.ok) {
      setStatus(data.output || "已取消选择文件夹");
      return;
    }
    outputInput.value = data.path;
    setStatus("保存位置已更新", "success");
  } catch (error) {
    setStatus("选择文件夹失败", "error");
    log.textContent = error.message;
  } finally {
    chooseFolderButton.disabled = false;
    chooseFolderButton.textContent = oldLabel;
  }
});

form.addEventListener("submit", async (event) => {
  event.preventDefault();

  const formData = new FormData(form);
  const payload = {
    url: String(formData.get("url") || "").trim(),
    quality: formData.get("quality"),
    output: formData.get("output"),
    useCookies: formData.get("cookies") === "on",
    playlist: formData.get("playlist") === "on" ? "all" : "current",
  };

  if (!payload.url) {
    setStatus("请先输入视频链接", "error");
    return;
  }

  setBusy(true);
  setStatus("正在下载，请保持本页打开...");
  log.textContent = "下载任务已启动，完成后会显示结果。";

  try {
    const response = await fetch("/api/download", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(payload),
    });
    const data = await response.json();
    showOutput(data);
    setStatus(data.ok ? "下载完成" : `下载失败，退出码 ${data.exitCode}`, data.ok ? "success" : "error");
  } catch (error) {
    log.textContent = error.message;
    setStatus("下载失败", "error");
  } finally {
    setBusy(false);
  }
});
