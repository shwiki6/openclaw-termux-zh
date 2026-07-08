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
  var editorInstance = null;
  var aceConfigured = false;
  var currentView = "source";
  var textPreviewable = false;
  var previewTimer = null;
  var currentWorkbook = null;
  var currentSheet = "";

  var IMAGE_EXTS = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "avif", "heic", "heif"];
  var AUDIO_EXTS = ["mp3", "m4a", "aac", "wav", "ogg", "oga", "flac", "opus", "amr"];
  var VIDEO_EXTS = ["mp4", "m4v", "webm", "3gp", "3gpp", "mkv", "mov", "avi"];
  var ARCHIVE_EXTS = ["zip", "tar", "gz", "xz", "bz2", "7z", "rar", "apk", "jar", "war"];
  var TEXT_EXTS = [
    "txt", "text", "md", "markdown", "json", "json5", "yaml", "yml", "toml",
    "xml", "html", "htm", "css", "scss", "less", "js", "mjs", "cjs", "ts",
    "tsx", "jsx", "dart", "kt", "kts", "java", "py", "pyw", "sh", "bash",
    "zsh", "fish", "log", "ini", "conf", "cfg", "properties", "gradle", "c",
    "h", "cpp", "hpp", "cc", "cxx", "go", "rs", "php", "rb", "lua", "sql",
    "csv", "tsv", "svg", "dockerfile", "gitignore", "env", "lock"
  ];

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
    configureAce();
    bindActions(document);
    decorateStaticButtons();
    var data = await api("/api/roots");
    roots = data.roots || [];
    panes.left.path = (roots[0] && roots[0].path) || "/";
    panes.right.path = (roots[2] && roots[2].path) || (roots[0] && roots[0].path) || "/";
    await Promise.all([load("left"), load("right")]);
    status("就绪");
  }

  function configureAce() {
    if (aceConfigured || !window.ace) return;
    window.ace.config.set("basePath", "/assets/vendor/ace");
    window.ace.config.set("modePath", "/assets/vendor/ace");
    window.ace.config.set("themePath", "/assets/vendor/ace");
    window.ace.config.set("workerPath", "/assets/vendor/ace");
    window.ace.config.set("loadWorkerFromBlob", false);
    aceConfigured = true;
  }

  function decorateStaticButtons() {
    var style = document.createElement("style");
    style.textContent =
      ".cmd{display:inline-flex;height:28px;min-width:28px;align-items:center;justify-content:center;border-radius:6px;border:1px solid #27272a;background:#18181b;color:#fafafa;padding:0 7px}" +
      ".cmd:active{background:#3f3f46}.cmd.primary{background:#dc2626;border-color:#dc2626}.cmd.danger{color:#fca5a5}.cmd:disabled{opacity:.45}" +
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
      return '<button class="fm-root-button" data-pane="' + id + '" data-path="' + attr(root.path) + '" data-action="root">' + esc(root.label) + "</button>";
    }).join("");
    var header =
      '<div class="fm-pane-head">' +
      '<div class="fm-roots">' + rootButtons + "</div>" +
      '<div class="fm-path">' +
      icon("hard-drive", "shrink-0 text-zinc-500") +
      '<span class="truncate">' + esc(pane.path) + "</span></div></div>";
    var up =
      '<div role="button" tabindex="0" class="fm-row" data-pane="' + id + '" data-path="' + attr(parent(pane.path)) + '" data-action="cd">' +
      '<span class="fm-icon text-zinc-400">' + icon("corner-up-left") + "</span>" +
      '<span class="fm-row-main"><b class="fm-row-title">..</b><small class="fm-row-sub">上级目录</small></span></div>';
    var rows = pane.entries.map(function (entry) {
      return rowHtml(id, entry);
    }).join("");
    $(id).innerHTML =
      '<div class="fm-pane ' + (active === id ? "active" : "") + '">' +
      header +
      '<div class="fm-list" data-scroll-pane="' + id + '">' + up + rows + "</div></div>";
    bindActions($(id));
    refreshIcons();
  }

  function rowHtml(id, entry) {
    var isSelected = selected && selected.path === entry.path;
    var kind = entry.dir ? "文件夹" : formatSize(entry.size);
    var iconName = entry.dir ? "folder" : fileIcon(entry.name);
    var color = entry.dir ? "text-amber-400" : "text-zinc-300";
    return '<div role="button" tabindex="0" class="fm-row ' + (isSelected ? "selected" : "") + '" data-pane="' + id + '" data-path="' + attr(entry.path) + '" data-dir="' + (entry.dir ? "1" : "0") + '" data-action="open">' +
      '<span class="fm-icon shrink-0 ' + color + '">' + icon(iconName) + "</span>" +
      '<span class="fm-row-main"><b class="fm-row-title">' + esc(entry.name) + '</b><small class="fm-row-sub">' + esc(kind) + " · " + esc(entry.modified) + "</small></span>" +
      '<span class="fm-more" data-action="menu" data-pane="' + id + '" data-path="' + attr(entry.path) + '">' + icon("more-vertical") + "</span></div>";
  }

  function bindActions(root) {
    root.querySelectorAll("[data-action]").forEach(function (el) {
      if (el.dataset.bound === "1") return;
      el.dataset.bound = "1";
      var touchStartX = 0;
      var touchStartY = 0;
      var touchMoved = false;
      el.addEventListener("touchstart", function (event) {
        var touch = event.touches && event.touches[0];
        if (!touch) return;
        touchStartX = touch.clientX;
        touchStartY = touch.clientY;
        touchMoved = false;
      }, { passive: true });
      el.addEventListener("touchmove", function (event) {
        var touch = event.touches && event.touches[0];
        if (!touch) return;
        if (Math.abs(touch.clientX - touchStartX) + Math.abs(touch.clientY - touchStartY) > 10) {
          touchMoved = true;
        }
      }, { passive: true });
      el.addEventListener("click", function (event) {
        if (touchMoved) {
          event.preventDefault();
          event.stopPropagation();
          return;
        }
        var action = el.dataset.action;
        if (action === "menu") event.stopPropagation();
        handleAction(action, el);
      });
      el.addEventListener("keydown", function (event) {
        if (event.key !== "Enter" && event.key !== " ") return;
        event.preventDefault();
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
    if (action === "download-editing") return downloadEditing();
    if (action === "text-editing") return openAsText(editing, false);
    if (action === "switch-view") return switchEditorView(el.dataset.view);
    if (action === "sheet-tab") return renderWorkbookSheet(el.dataset.sheet);
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
    var ext = fileExt(name);
    if (IMAGE_EXTS.indexOf(ext) >= 0 || ext === "svg") return "image";
    if (AUDIO_EXTS.indexOf(ext) >= 0) return "audio-lines";
    if (VIDEO_EXTS.indexOf(ext) >= 0) return "video";
    if (ext === "pdf" || ["doc", "docx", "odt", "rtf"].indexOf(ext) >= 0) return "file-text";
    if (["xls", "xlsx", "ods", "csv", "tsv"].indexOf(ext) >= 0) return "table";
    if (["ppt", "pptx", "odp"].indexOf(ext) >= 0) return "presentation";
    if (ARCHIVE_EXTS.indexOf(ext) >= 0) return "archive";
    if (isTextExt(ext) || isSpecialTextName(name)) return "file-code";
    return "file";
  }

  async function openFile(path) {
    editing = path;
    currentWorkbook = null;
    currentSheet = "";
    $("editor").classList.remove("hidden");
    $("editor").classList.add("flex");
    $("editPath").textContent = path;
    destroyAce();
    setToolbar(false, false, false);
    var ext = fileExt(path);
    var url = fileUrl(path);

    if (isTextExt(ext) || isSpecialTextName(path)) {
      return openAsText(path, canPreviewText(path));
    }
    if (IMAGE_EXTS.indexOf(ext) >= 0) {
      renderStaticPreview('<div class="fm-media-preview"><img src="' + attr(url) + '" alt=""></div>');
    } else if (AUDIO_EXTS.indexOf(ext) >= 0) {
      renderStaticPreview('<div class="fm-media-preview"><audio controls preload="metadata" src="' + attr(url) + '"></audio></div>');
    } else if (VIDEO_EXTS.indexOf(ext) >= 0) {
      renderStaticPreview('<div class="fm-media-preview"><video controls preload="metadata" src="' + attr(url) + '"></video></div>');
    } else if (ext === "pdf") {
      renderStaticPreview('<object class="h-full w-full bg-white" data="' + attr(url) + '" type="application/pdf"><iframe class="h-full w-full border-0 bg-white" src="' + attr(url) + '"></iframe></object>');
    } else if (ext === "docx") {
      await openDocx(path);
    } else if (["xls", "xlsx", "ods"].indexOf(ext) >= 0) {
      await openSpreadsheet(path);
    } else if (ext === "pptx") {
      await openPptx(path);
    } else {
      renderUnsupported(path, "此文件不会按文本自动打开。");
    }
    refreshIcons();
  }

  function renderStaticPreview(html) {
    destroyAce();
    setToolbar(false, false, false);
    $("editBody").innerHTML = html;
    bindActions($("editBody"));
    refreshIcons();
  }

  function renderUnsupported(path, message) {
    destroyAce();
    setToolbar(false, false, false);
    $("editBody").innerHTML =
      '<div class="fm-empty-preview"><b>' + esc(path.split("/").pop() || path) + '</b>' +
      '<span>' + esc(message) + '</span><div class="flex gap-2">' +
      '<button class="cmd" data-action="download-editing">' + icon("download") + '</button>' +
      '<button class="cmd" data-action="text-editing">按文本打开</button></div></div>';
    bindActions($("editBody"));
    refreshIcons();
  }

  function renderLoading(label) {
    destroyAce();
    setToolbar(false, false, false);
    $("editBody").innerHTML = '<div class="fm-empty-preview"><b>' + esc(label) + '</b><span>正在读取...</span></div>';
  }

  function downloadEditing() {
    if (!editing) return;
    location.href = fileUrl(editing);
  }

  async function openAsText(path, preferPreview) {
    editing = path;
    renderLoading(path.split("/").pop() || path);
    try {
      var data = await api("/api/read?path=" + qs(path));
      renderTextEditor(path, data.content || "", !!preferPreview);
    } catch (error) {
      renderUnsupported(path, error.message);
    }
  }

  function renderTextEditor(path, content, preferPreview) {
    destroyAce();
    textPreviewable = canPreviewText(path);
    setToolbar(true, textPreviewable, true);
    $("editBody").innerHTML =
      '<div class="fm-editor-shell">' +
      '<div id="previewPane" class="fm-preview hidden"></div>' +
      '<div id="sourcePane" class="fm-code-pane"><div id="codeEditor"></div></div></div>';
    setupAce(path, content);
    if (textPreviewable) updateTextPreview();
    switchEditorView(textPreviewable && preferPreview ? "preview" : "source");
    refreshIcons();
  }

  function setupAce(path, content) {
    configureAce();
    if (!window.ace) {
      $("sourcePane").innerHTML = '<textarea id="textEdit" class="h-full w-full resize-none border-0 bg-zinc-950 p-2 font-mono text-[11px] leading-5 text-zinc-100 outline-none" spellcheck="false"></textarea>';
      $("textEdit").value = content;
      return;
    }
    editorInstance = window.ace.edit("codeEditor");
    editorInstance.setTheme("ace/theme/tomorrow_night_eighties");
    editorInstance.session.setMode("ace/mode/" + aceModeForPath(path));
    editorInstance.session.setUseWorker(false);
    editorInstance.session.setUseWrapMode(true);
    editorInstance.session.setTabSize(2);
    editorInstance.session.setUseSoftTabs(true);
    editorInstance.setValue(content, -1);
    editorInstance.setOptions({
      animatedScroll: false,
      autoScrollEditorIntoView: true,
      fontSize: "11px",
      highlightActiveLine: true,
      printMargin: false,
      scrollPastEnd: 0.25,
      showPrintMargin: false
    });
    editorInstance.session.on("change", function () {
      if (!textPreviewable) return;
      clearTimeout(previewTimer);
      previewTimer = setTimeout(function () {
        if (currentView === "preview") updateTextPreview();
      }, 350);
    });
    setTimeout(function () {
      if (editorInstance) editorInstance.resize();
    }, 0);
  }

  function switchEditorView(view) {
    if (view === "preview" && textPreviewable) updateTextPreview();
    currentView = view === "preview" && textPreviewable ? "preview" : "source";
    var previewPane = $("previewPane");
    var sourcePane = $("sourcePane");
    if (previewPane) previewPane.classList.toggle("hidden", currentView !== "preview");
    if (sourcePane) sourcePane.classList.toggle("hidden", currentView !== "source");
    $("previewTab").classList.toggle("active", currentView === "preview");
    $("sourceTab").classList.toggle("active", currentView === "source");
    if (editorInstance && currentView === "source") {
      setTimeout(function () { editorInstance.resize(); editorInstance.focus(); }, 0);
    }
  }

  function updateTextPreview() {
    var previewPane = $("previewPane");
    if (!previewPane || !editing) return;
    var content = getEditorText();
    var ext = fileExt(editing);
    if (["html", "htm", "svg"].indexOf(ext) >= 0) {
      previewPane.innerHTML = '<iframe id="htmlPreview" class="h-full w-full border-0 bg-white" sandbox=""></iframe>';
      $("htmlPreview").srcdoc = content;
      return;
    }
    if (["md", "markdown"].indexOf(ext) >= 0) {
      previewPane.innerHTML = '<article class="fm-doc">' + renderMarkdown(content) + "</article>";
      return;
    }
    if (["csv", "tsv"].indexOf(ext) >= 0) {
      previewPane.innerHTML = renderTable(parseDelimited(content, ext === "tsv" ? "\t" : ","), 500, 80);
      return;
    }
    if (["json", "json5"].indexOf(ext) >= 0) {
      previewPane.innerHTML = '<article class="fm-doc dark"><pre>' + esc(prettyJson(content)) + "</pre></article>";
      return;
    }
    if (ext === "xml") {
      previewPane.innerHTML = '<article class="fm-doc dark"><pre>' + esc(content) + "</pre></article>";
      return;
    }
    previewPane.innerHTML = '<article class="fm-doc dark"><pre>' + esc(content) + "</pre></article>";
  }

  function renderMarkdown(content) {
    var parser = window.marked && (window.marked.parse || window.marked.marked);
    if (!parser) return '<pre>' + esc(content) + "</pre>";
    return sanitizeHtml(parser(content));
  }

  async function openDocx(path) {
    renderLoading(path.split("/").pop() || path);
    try {
      if (!window.mammoth) throw new Error("DOCX 预览组件未加载");
      var result = await window.mammoth.convertToHtml({ arrayBuffer: await fetchFileBuffer(path) });
      var messages = (result.messages || []).map(function (message) {
        return '<li>' + esc(message.message || String(message)) + "</li>";
      }).join("");
      setToolbar(false, false, false);
      $("editBody").innerHTML =
        '<div class="fm-preview"><article class="fm-doc">' +
        sanitizeHtml(result.value || "<p></p>") +
        (messages ? '<hr><small><ul>' + messages + "</ul></small>" : "") +
        "</article></div>";
    } catch (error) {
      renderUnsupported(path, "DOCX 预览失败：" + error.message);
    }
  }

  async function openSpreadsheet(path) {
    renderLoading(path.split("/").pop() || path);
    try {
      if (!window.XLSX) throw new Error("表格预览组件未加载");
      currentWorkbook = window.XLSX.read(await fetchFileBuffer(path), { type: "array" });
      currentSheet = currentWorkbook.SheetNames[0] || "";
      setToolbar(false, false, false);
      renderWorkbook();
    } catch (error) {
      renderUnsupported(path, "表格预览失败：" + error.message);
    }
  }

  function renderWorkbook() {
    var buttons = (currentWorkbook.SheetNames || []).map(function (name) {
      return '<button class="' + (name === currentSheet ? "active" : "") + '" data-action="sheet-tab" data-sheet="' + attr(name) + '">' + esc(name) + "</button>";
    }).join("");
    $("editBody").innerHTML =
      '<div class="fm-editor-view"><div class="fm-doc-tabs">' + buttons +
      '</div><div id="sheetBody" class="min-h-0 flex-1 overflow-hidden"></div></div>';
    bindActions($("editBody"));
    renderWorkbookSheet(currentSheet);
  }

  function renderWorkbookSheet(sheetName) {
    if (!currentWorkbook || !sheetName) return;
    currentSheet = sheetName;
    var sheet = currentWorkbook.Sheets[sheetName];
    var rows = window.XLSX.utils.sheet_to_json(sheet, { header: 1, raw: false, defval: "" });
    $("sheetBody").innerHTML = renderTable(rows, 1000, 120);
    document.querySelectorAll('[data-action="sheet-tab"]').forEach(function (button) {
      button.classList.toggle("active", button.dataset.sheet === currentSheet);
    });
  }

  async function openPptx(path) {
    renderLoading(path.split("/").pop() || path);
    try {
      if (!window.JSZip) throw new Error("PPTX 预览组件未加载");
      var zip = await window.JSZip.loadAsync(await fetchFileBuffer(path));
      var slidePaths = Object.keys(zip.files).filter(function (name) {
        return /^ppt\/slides\/slide[0-9]+\.xml$/.test(name);
      }).sort(function (a, b) {
        return slideNumber(a) - slideNumber(b);
      });
      var html = "";
      for (var i = 0; i < slidePaths.length; i += 1) {
        var xml = await zip.file(slidePaths[i]).async("string");
        var text = extractPptxText(xml);
        html += '<section class="fm-slide">' +
          '<b>幻灯片 ' + (i + 1) + '</b><pre>' + esc(text || "(空)") + "</pre></section>";
      }
      setToolbar(false, false, false);
      $("editBody").innerHTML = '<div class="fm-preview"><article class="fm-doc">' + (html || "<p>未找到幻灯片文本。</p>") + "</article></div>";
    } catch (error) {
      renderUnsupported(path, "PPTX 预览失败：" + error.message);
    }
  }

  function slideNumber(path) {
    var match = path.match(/slide([0-9]+)\.xml$/);
    return match ? Number(match[1]) : 0;
  }

  function extractPptxText(xml) {
    var matches = xml.match(/<a:t[^>]*>[\s\S]*?<\/a:t>/g) || [];
    return matches.map(function (item) {
      return xmlDecode(item.replace(/^<a:t[^>]*>/, "").replace(/<\/a:t>$/, ""));
    }).join("\n").replace(/\n{3,}/g, "\n\n").trim();
  }

  function xmlDecode(text) {
    return String(text || "")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&quot;/g, '"')
      .replace(/&apos;/g, "'")
      .replace(/&amp;/g, "&");
  }

  async function fetchFileBuffer(path) {
    var response = await fetch(fileUrl(path));
    if (!response.ok) throw new Error(String(response.status));
    return response.arrayBuffer();
  }

  function renderTable(rows, maxRows, maxCols) {
    rows = rows || [];
    if (!rows.length) return '<div class="fm-empty-preview"><b>空表格</b></div>';
    var clippedRows = rows.slice(0, maxRows || 500);
    var colCount = Math.min(maxCols || 80, clippedRows.reduce(function (maxColsSeen, row) {
      return Math.max(maxColsSeen, (row || []).length);
    }, 0));
    var head = "<tr>";
    for (var c = 0; c < colCount; c += 1) {
      head += "<th>" + esc(columnName(c)) + "</th>";
    }
    head += "</tr>";
    var body = clippedRows.map(function (row) {
      var html = "<tr>";
      for (var c = 0; c < colCount; c += 1) {
        html += "<td>" + esc(row && row[c] != null ? row[c] : "") + "</td>";
      }
      return html + "</tr>";
    }).join("");
    return '<div class="fm-table-wrap"><table class="fm-table"><thead>' + head + "</thead><tbody>" + body + "</tbody></table></div>";
  }

  function columnName(index) {
    var name = "";
    var n = index + 1;
    while (n > 0) {
      var rem = (n - 1) % 26;
      name = String.fromCharCode(65 + rem) + name;
      n = Math.floor((n - rem) / 26);
    }
    return name;
  }

  function parseDelimited(text, delimiter) {
    var rows = [];
    var row = [];
    var cell = "";
    var inQuotes = false;
    for (var i = 0; i < text.length; i += 1) {
      var ch = text[i];
      if (ch === '"') {
        if (inQuotes && text[i + 1] === '"') {
          cell += '"';
          i += 1;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch === delimiter && !inQuotes) {
        row.push(cell);
        cell = "";
      } else if ((ch === "\n" || ch === "\r") && !inQuotes) {
        if (ch === "\r" && text[i + 1] === "\n") i += 1;
        row.push(cell);
        rows.push(row);
        row = [];
        cell = "";
      } else {
        cell += ch;
      }
    }
    row.push(cell);
    rows.push(row);
    return rows;
  }

  function prettyJson(content) {
    try {
      return JSON.stringify(JSON.parse(content), null, 2);
    } catch (_) {
      return content;
    }
  }

  function sanitizeHtml(html) {
    var template = document.createElement("template");
    template.innerHTML = html;
    var blocked = { script: 1, style: 1, iframe: 1, object: 1, embed: 1, link: 1, meta: 1 };
    var walker = document.createTreeWalker(template.content, 1, null);
    var remove = [];
    var node;
    while ((node = walker.nextNode())) {
      var tag = node.tagName.toLowerCase();
      if (blocked[tag]) {
        remove.push(node);
        continue;
      }
      Array.prototype.slice.call(node.attributes).forEach(function (attribute) {
        var name = attribute.name.toLowerCase();
        var value = String(attribute.value || "").trim().toLowerCase();
        if (name.indexOf("on") === 0 || ((name === "href" || name === "src" || name === "xlink:href") && value.indexOf("javascript:") === 0)) {
          node.removeAttribute(attribute.name);
        }
      });
    }
    remove.forEach(function (nodeToRemove) {
      nodeToRemove.remove();
    });
    return template.innerHTML;
  }

  async function saveFile() {
    if (!editing || $("saveButton").disabled) return;
    var content = getEditorText();
    await api("/api/write", { method: "POST", body: { path: editing, content: content } });
    if (textPreviewable) updateTextPreview();
    await refresh();
    status("已保存");
  }

  function getEditorText() {
    if (editorInstance) return editorInstance.getValue();
    var text = $("textEdit");
    return text ? text.value : "";
  }

  function closeEditor() {
    editing = null;
    currentWorkbook = null;
    currentSheet = "";
    destroyAce();
    $("editor").classList.add("hidden");
    $("editor").classList.remove("flex");
  }

  function destroyAce() {
    clearTimeout(previewTimer);
    previewTimer = null;
    textPreviewable = false;
    currentView = "source";
    if (editorInstance) {
      editorInstance.destroy();
      editorInstance = null;
    }
  }

  function setToolbar(canSave, canPreview, canSource) {
    $("saveButton").disabled = !canSave;
    $("saveButton").classList.toggle("hidden", !canSave);
    $("previewTab").classList.toggle("hidden", !canPreview);
    $("sourceTab").classList.toggle("hidden", !canSource);
    $("previewTab").classList.toggle("active", false);
    $("sourceTab").classList.toggle("active", false);
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

  function fileExt(path) {
    var name = String(path || "").split("/").pop().toLowerCase();
    if (name === "dockerfile" || name === "makefile") return name;
    if (name === ".env") return "env";
    if (name === ".gitignore") return "gitignore";
    var index = name.lastIndexOf(".");
    return index >= 0 ? name.slice(index + 1) : "";
  }

  function isSpecialTextName(path) {
    var name = String(path || "").split("/").pop().toLowerCase();
    return ["dockerfile", "makefile", ".env", ".gitignore"].indexOf(name) >= 0;
  }

  function isTextExt(ext) {
    return TEXT_EXTS.indexOf(ext) >= 0;
  }

  function canPreviewText(path) {
    return ["md", "markdown", "html", "htm", "svg", "csv", "tsv", "json", "json5", "xml"].indexOf(fileExt(path)) >= 0;
  }

  function aceModeForPath(path) {
    var ext = fileExt(path);
    var name = String(path || "").split("/").pop().toLowerCase();
    if (name === "dockerfile") return "dockerfile";
    if (name === "makefile") return "makefile";
    var modes = {
      bash: "sh", c: "c_cpp", cc: "c_cpp", conf: "ini", cfg: "ini", cpp: "c_cpp",
      cxx: "c_cpp", env: "sh", fish: "sh", gradle: "java", h: "c_cpp", hpp: "c_cpp",
      go: "golang", htm: "html", js: "javascript", cjs: "javascript", mjs: "javascript",
      json5: "json", jsx: "jsx", kt: "kotlin", kts: "kotlin", lock: "json", markdown: "markdown", md: "markdown",
      less: "css", log: "text", properties: "properties", pyw: "python", rb: "ruby", rs: "rust", scss: "css", sh: "sh",
      py: "python", svg: "svg", text: "text", ts: "typescript", tsx: "tsx", tsv: "csv", txt: "text", yml: "yaml", zsh: "sh",
      gitignore: "text"
    };
    return modes[ext] || ext || "text";
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
