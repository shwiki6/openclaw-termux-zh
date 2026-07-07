(function () {
  var TOKEN = new URLSearchParams(location.search).get("token") || "";
  var roots = [];
  var panes = {
    left: { path: "", entries: [] },
    right: { path: "", entries: [] }
  };
  var active = "left";
  var selected = null;
  var editing = null;

  function $(id) {
    return document.getElementById(id);
  }

  function icon(name, cls) {
    return '<i data-lucide="' + name + '" class="' + (cls || "") + '"></i>';
  }

  function esc(value) {
    return String(value == null ? "" : value).replace(/[&<>"]/g, function (ch) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[ch];
    });
  }

  function attr(value) {
    return esc(value).replace(/'/g, "&#39;");
  }

  function qs(value) {
    return encodeURIComponent(value || "");
  }

  function status(message) {
    $("status").textContent = message || "";
  }

  async function api(path, options) {
    options = options || {};
    options.headers = Object.assign({ "X-OpenClaw-File-Token": TOKEN }, options.headers || {});
    if (options.body && typeof options.body !== "string") {
      options.headers["Content-Type"] = "application/json";
      options.body = JSON.stringify(options.body);
    }
    var response = await fetch(path, options);
    var text = await response.text();
    var data;
    try {
      data = JSON.parse(text);
    } catch (_) {
      data = { error: text };
    }
    if (!response.ok) {
      throw new Error(data.error || String(response.status));
    }
    return data;
  }

  function refreshIcons() {
    if (window.lucide && window.lucide.createIcons) {
      window.lucide.createIcons();
    }
  }

  async function init() {
    bindActions(document);
    decorateStaticButtons();
    var data = await api("/api/roots");
    roots = data.roots || [];
    panes.left.path = (roots[0] && roots[0].path) || "/";
    panes.right.path = (roots[2] && roots[2].path) || (roots[0] && roots[0].path) || "/";
    await Promise.all([load("left"), load("right")]);
    status("就绪");
  }

  function decorateStaticButtons() {
    var style = document.createElement("style");
    style.textContent =
      ".cmd{display:inline-flex;height:28px;min-width:28px;align-items:center;justify-content:center;border-radius:6px;border:1px solid #27272a;background:#18181b;color:#fafafa;padding:0 7px}" +
      ".cmd:active{background:#3f3f46}.cmd.primary{background:#dc2626;border-color:#dc2626}.cmd.danger{color:#fca5a5}" +
      ".sheetBtn{display:flex;height:50px;flex-direction:column;align-items:center;justify-content:center;gap:3px;border-radius:6px;border:1px solid #27272a;background:#18181b;color:#f4f4f5;font-size:10px}" +
      ".sheetBtn:active{background:#3f3f46}.sheetBtn.danger{color:#fca5a5}.sheetBtn svg{width:16px;height:16px}";
    document.head.appendChild(style);
    refreshIcons();
  }

  async function load(id, path) {
    active = id;
    if (path) panes[id].path = path;
    try {
      var data = await api("/api/list?path=" + qs(panes[id].path));
      panes[id].path = data.path;
      panes[id].entries = data.entries || [];
      renderPane(id);
      status(data.path);
    } catch (error) {
      status(error.message);
    }
  }

  function renderPane(id) {
    var pane = panes[id];
    var rootButtons = roots.map(function (root) {
      return '<button class="h-6 shrink-0 rounded-md border border-zinc-700 bg-zinc-900 px-2 text-[10px] text-zinc-100 active:bg-zinc-700" data-pane="' + id + '" data-path="' + attr(root.path) + '" data-action="root">' + esc(root.label) + "</button>";
    }).join("");
    var header =
      '<div class="flex h-[58px] shrink-0 flex-col gap-1 border-b border-zinc-800 bg-zinc-950 p-1.5">' +
      '<div class="fm-roots flex gap-1">' + rootButtons + "</div>" +
      '<div class="flex min-w-0 items-center gap-1 text-[10px] text-zinc-400">' +
      icon("hard-drive", "shrink-0 text-zinc-500") +
      '<span class="truncate">' + esc(pane.path) + "</span></div></div>";
    var up =
      '<button class="fm-row flex w-full items-center gap-1.5 border-b border-zinc-900 px-1.5 text-left text-zinc-100 active:bg-zinc-800" data-pane="' + id + '" data-path="' + attr(parent(pane.path)) + '" data-action="cd">' +
      '<span class="fm-icon text-zinc-400">' + icon("corner-up-left") + "</span>" +
      '<span class="min-w-0 flex-1 truncate"><b class="block truncate text-[11px] font-medium">..</b><small class="block truncate text-[9px] text-zinc-500">上级目录</small></span></button>';
    var rows = pane.entries.map(function (entry) {
      return rowHtml(id, entry);
    }).join("");
    $(id).innerHTML =
      '<div class="flex h-full min-h-0 flex-col bg-zinc-950 ' + (active === id ? "ring-1 ring-inset ring-red-800/50" : "") + '">' +
      header +
      '<div class="fm-scroll flex-1 pb-1" data-scroll-pane="' + id + '">' + up + rows + "</div></div>";
    bindActions($(id));
    refreshIcons();
  }

  function rowHtml(id, entry) {
    var isSelected = selected && selected.path === entry.path;
    var kind = entry.dir ? "文件夹" : formatSize(entry.size);
    var iconName = entry.dir ? "folder" : fileIcon(entry.name);
    var color = entry.dir ? "text-amber-400" : "text-zinc-300";
    return '<button class="fm-row flex w-full items-center gap-1.5 border-b border-zinc-900 px-1.5 text-left ' + (isSelected ? "bg-red-950/60 text-white" : "text-zinc-100 active:bg-zinc-800") + '" data-pane="' + id + '" data-path="' + attr(entry.path) + '" data-dir="' + (entry.dir ? "1" : "0") + '" data-action="open">' +
      '<span class="fm-icon shrink-0 ' + color + '">' + icon(iconName) + "</span>" +
      '<span class="min-w-0 flex-1 truncate"><b class="block truncate text-[11px] font-medium">' + esc(entry.name) + '</b><small class="block truncate text-[9px] text-zinc-500">' + esc(kind) + " · " + esc(entry.modified) + "</small></span>" +
      '<span class="flex h-7 w-7 shrink-0 items-center justify-center rounded-md text-zinc-400 active:bg-zinc-700" data-action="menu" data-pane="' + id + '" data-path="' + attr(entry.path) + '">' + icon("more-vertical") + "</span></button>";
  }

  function bindActions(root) {
    root.querySelectorAll("[data-action]").forEach(function (el) {
      if (el.dataset.bound === "1") return;
      el.dataset.bound = "1";
      el.addEventListener("click", function (event) {
        var action = el.dataset.action;
        if (action === "menu") event.stopPropagation();
        handleAction(action, el);
      });
    });
  }

  function handleAction(action, el) {
    if (action === "refresh") return refresh();
    if (action === "mkdir") return makeDir();
    if (action === "touch") return makeFile();
    if (action === "rename") return renameSelected();
    if (action === "delete") return deleteSelected();
    if (action === "copy") return copyMove(false);
    if (action === "move") return copyMove(true);
    if (action === "save") return saveFile();
    if (action === "close-editor") return closeEditor();
    if (action === "close-sheet") return closeSheet();
    if (action === "open-selected") return openSelected();
    if (action === "root" || action === "cd") return load(el.dataset.pane, el.dataset.path);
    if (action === "menu") return selectAndSheet(el.dataset.pane, el.dataset.path);
    if (action === "open") return openEntry(el.dataset.pane, el.dataset.path, el.dataset.dir === "1");
  }

  function selectAndSheet(id, path) {
    selectEntry(id, path);
    openSheet();
  }

  function selectEntry(id, path) {
    active = id;
    selected = (panes[id].entries || []).find(function (entry) { return entry.path === path; }) || null;
    renderPane("left");
    renderPane("right");
    status(selected ? selected.path : "未选择");
  }

  function openEntry(id, path, isDir) {
    active = id;
    if (isDir) return load(id, path);
    selectEntry(id, path);
    openFile(path);
  }

  function openSheet() {
    if (!selected) return;
    $("sheetTitle").textContent = selected.name;
    $("sheet").classList.remove("hidden");
    refreshIcons();
  }

  function closeSheet() {
    $("sheet").classList.add("hidden");
  }

  function openSelected() {
    if (!selected) return;
    closeSheet();
    if (selected.dir) return load(active, selected.path);
    openFile(selected.path);
  }

  function fileIcon(name) {
    var ext = name.split(".").pop().toLowerCase();
    if (["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "heic", "heif"].indexOf(ext) >= 0) return "image";
    if (["mp3", "m4a", "aac", "wav", "ogg", "flac"].indexOf(ext) >= 0) return "audio-lines";
    if (["mp4", "webm", "3gp", "mkv"].indexOf(ext) >= 0) return "video";
    if (ext === "pdf") return "file-text";
    if (["zip", "tar", "gz", "xz", "apk"].indexOf(ext) >= 0) return "archive";
    if (["js", "css", "html", "kt", "java", "dart", "py", "sh", "json", "xml", "yaml", "yml", "toml"].indexOf(ext) >= 0) return "file-code";
    return "file";
  }

  function openFile(path) {
    editing = path;
    $("editor").classList.remove("hidden");
    $("editor").classList.add("flex");
    $("editPath").textContent = path;
    var ext = path.split(".").pop().toLowerCase();
    var url = fileUrl(path);
    if (["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "heic", "heif"].indexOf(ext) >= 0) {
      $("editBody").innerHTML = '<div class="fm-scroll flex h-full items-center justify-center bg-zinc-950 p-2"><img class="max-h-full max-w-full object-contain" src="' + attr(url) + '"></div>';
    } else if (["mp3", "m4a", "aac", "wav", "ogg", "flac"].indexOf(ext) >= 0) {
      $("editBody").innerHTML = '<div class="flex h-full items-center bg-zinc-950 p-3"><audio class="w-full" controls src="' + attr(url) + '"></audio></div>';
    } else if (["mp4", "webm", "3gp", "mkv"].indexOf(ext) >= 0) {
      $("editBody").innerHTML = '<video class="h-full w-full bg-black" controls src="' + attr(url) + '"></video>';
    } else if (ext === "pdf") {
      $("editBody").innerHTML = '<iframe class="h-full w-full border-0 bg-white" src="' + attr(url) + '"></iframe>';
    } else if (isTextExt(ext)) {
      openAsText(path);
    } else {
      $("editBody").innerHTML = '<div class="flex h-full flex-col gap-2 bg-zinc-950 p-3 text-zinc-300"><b class="truncate text-[12px] text-zinc-100">' + esc(path.split("/").pop() || path) + '</b><span class="text-[10px] text-zinc-500">此文件不会按文本自动打开。</span><div class="flex gap-2"><button class="cmd" onclick="location.href=fileUrl(editing)">打开/下载</button><button class="cmd" onclick="openAsText(editing)">按文本打开</button></div></div>';
    }
    refreshIcons();
  }

  async function openAsText(path) {
    try {
      var data = await api("/api/read?path=" + qs(path));
      $("editBody").innerHTML = '<textarea id="textEdit" class="h-full w-full resize-none border-0 bg-zinc-950 p-2 font-mono text-[11px] leading-5 text-zinc-100 outline-none" spellcheck="false"></textarea>';
      $("textEdit").value = data.content || "";
    } catch (error) {
      $("editBody").innerHTML = '<pre class="fm-scroll h-full whitespace-pre-wrap bg-zinc-950 p-2 font-mono text-[11px] text-red-300">' + esc(error.message) + "</pre>";
    }
  }

  async function saveFile() {
    var text = $("textEdit");
    if (!editing || !text) return;
    await api("/api/write", { method: "POST", body: { path: editing, content: text.value } });
    await refresh();
    status("已保存");
  }

  function closeEditor() {
    editing = null;
    $("editor").classList.add("hidden");
    $("editor").classList.remove("flex");
  }

  function refresh() {
    return Promise.all([load("left"), load("right")]);
  }

  async function makeDir() {
    var name = prompt("文件夹名称");
    if (!name) return;
    await api("/api/mkdir", { method: "POST", body: { parent: panes[active].path, name: name } });
    await load(active);
  }

  async function makeFile() {
    var name = prompt("文件名称");
    if (!name) return;
    await api("/api/touch", { method: "POST", body: { parent: panes[active].path, name: name } });
    await load(active);
  }

  async function renameSelected() {
    if (!selected) return alert("未选择文件");
    var name = prompt("新名称", selected.name);
    if (!name) return;
    await api("/api/rename", { method: "POST", body: { path: selected.path, name: name } });
    selected = null;
    closeSheet();
    await refresh();
  }

  async function deleteSelected() {
    if (!selected) return alert("未选择文件");
    if (!confirm("删除 " + selected.name + "？")) return;
    await api("/api/delete", { method: "POST", body: { path: selected.path } });
    selected = null;
    closeSheet();
    closeEditor();
    await refresh();
  }

  async function copyMove(move) {
    if (!selected) return alert("未选择文件");
    var target = active === "left" ? panes.right.path : panes.left.path;
    await api(move ? "/api/move" : "/api/copy", {
      method: "POST",
      body: { source: selected.path, targetDir: target }
    });
    if (move) selected = null;
    closeSheet();
    await refresh();
  }

  function parent(path) {
    var normalized = String(path || "/").replace(/\/+$/, "");
    var index = normalized.lastIndexOf("/");
    return index <= 0 ? "/" : normalized.slice(0, index);
  }

  function formatSize(size) {
    size = Number(size || 0);
    if (size < 1024) return size + " B";
    if (size < 1048576) return (size / 1024).toFixed(1) + " KB";
    if (size < 1073741824) return (size / 1048576).toFixed(1) + " MB";
    return (size / 1073741824).toFixed(1) + " GB";
  }

  function isTextExt(ext) {
    return ["txt", "md", "json", "yaml", "yml", "toml", "xml", "html", "css", "js", "dart", "kt", "java", "py", "sh", "log"].indexOf(ext) >= 0;
  }

  function fileUrl(path) {
    return "/api/file?token=" + TOKEN + "&path=" + qs(path);
  }

  window.openAsText = openAsText;
  window.fileUrl = fileUrl;

  init().catch(function (error) {
    status(error.message);
  });
})();
