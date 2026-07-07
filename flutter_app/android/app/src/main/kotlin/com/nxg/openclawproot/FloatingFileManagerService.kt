package com.openclaw.cyx

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Environment
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.LinearLayout
import android.widget.TextView
import java.io.BufferedReader
import java.io.File
import java.io.FileInputStream
import java.io.InputStreamReader
import java.io.OutputStream
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.URLDecoder
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID
import kotlin.concurrent.thread
import kotlin.math.max
import kotlin.math.min
import org.json.JSONArray
import org.json.JSONObject

class FloatingFileManagerService : Service() {
    private var windowManager: WindowManager? = null
    private var rootView: LinearLayout? = null
    private var webView: WebView? = null
    private var bottomBar: LinearLayout? = null
    private var params: WindowManager.LayoutParams? = null
    private var server: FloatingFileManagerServer? = null
    private var minimized = false
    private var restoreHeight = 0

    private var dragStartRawX = 0f
    private var dragStartRawY = 0f
    private var dragStartX = 0
    private var dragStartY = 0
    private var resizeStartRawX = 0f
    private var resizeStartRawY = 0f
    private var resizeStartWidth = 0
    private var resizeStartHeight = 0

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        server = FloatingFileManagerServer(applicationContext).also { it.start() }
        startForeground(NOTIFICATION_ID, buildNotification())
        showWindow()
    }

    override fun onDestroy() {
        val manager = windowManager
        val view = rootView
        if (manager != null && view != null) {
            try {
                manager.removeView(view)
            } catch (_: Exception) {
            }
        }
        webView?.destroy()
        server?.stop()
        webView = null
        rootView = null
        bottomBar = null
        params = null
        server = null
        isRunning = false
        super.onDestroy()
    }

    private fun showWindow() {
        isRunning = true
        val manager = getSystemService(WINDOW_SERVICE) as WindowManager
        windowManager = manager
        val metrics = resources.displayMetrics
        val width = min(metrics.widthPixels - dp(12), dp(720))
        val height = min(metrics.heightPixels - dp(58), dp(620))
        restoreHeight = height

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.rgb(18, 18, 18))
        }
        rootView = root

        val title = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(8), 0, dp(2), 0)
            setBackgroundColor(Color.BLACK)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(32)
            )
        }
        val titleText = TextView(this).apply {
            text = "文件管理"
            setTextColor(Color.WHITE)
            textSize = 13f
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f)
        }
        val minimize = titleButton("一") { toggleMinimized() }
        val close = titleButton("X") { stopSelf() }
        title.addView(TextView(this).apply {
            text = "☰"
            setTextColor(Color.LTGRAY)
            textSize = 16f
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(dp(24), LinearLayout.LayoutParams.MATCH_PARENT)
        })
        title.addView(titleText)
        title.addView(minimize)
        title.addView(close)
        title.setOnTouchListener { _, event -> handleDrag(event) }

        val browser = WebView(this).apply {
            setBackgroundColor(Color.rgb(18, 18, 18))
            webViewClient = WebViewClient()
            webChromeClient = WebChromeClient()
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.allowFileAccess = false
            settings.allowContentAccess = false
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f
            )
        }
        webView = browser

        val resize = TextView(this).apply {
            text = "⤡"
            setTextColor(Color.WHITE)
            textSize = 18f
            gravity = Gravity.CENTER
            setBackgroundColor(Color.rgb(28, 28, 28))
            layoutParams = LinearLayout.LayoutParams(dp(54), LinearLayout.LayoutParams.MATCH_PARENT)
            setOnTouchListener { _, event -> handleResize(event) }
        }
        val bar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.RIGHT or Gravity.CENTER_VERTICAL
            setBackgroundColor(Color.BLACK)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(32)
            )
            addView(TextView(this@FloatingFileManagerService).apply {
                text = "拖动右侧调整大小"
                setTextColor(Color.LTGRAY)
                textSize = 11f
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(8), 0, 0, 0)
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f)
            })
            addView(resize)
        }
        bottomBar = bar

        root.addView(title)
        root.addView(browser)
        root.addView(bar)

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val layoutParams = WindowManager.LayoutParams(
            width,
            height,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(8)
            y = dp(48)
        }
        params = layoutParams
        manager.addView(root, layoutParams)

        val currentServer = server ?: return
        browser.loadUrl("http://127.0.0.1:${currentServer.port}/?token=${currentServer.token}")
    }

    private fun handleDrag(event: MotionEvent): Boolean {
        val layoutParams = params ?: return false
        val manager = windowManager ?: return false
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                dragStartRawX = event.rawX
                dragStartRawY = event.rawY
                dragStartX = layoutParams.x
                dragStartY = layoutParams.y
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = (event.rawX - dragStartRawX).toInt()
                val dy = (event.rawY - dragStartRawY).toInt()
                layoutParams.x = clamp(dragStartX + dx, 0, resources.displayMetrics.widthPixels - dp(56))
                layoutParams.y = clamp(dragStartY + dy, 0, resources.displayMetrics.heightPixels - dp(56))
                manager.updateViewLayout(rootView, layoutParams)
                return true
            }
        }
        return false
    }

    private fun handleResize(event: MotionEvent): Boolean {
        val layoutParams = params ?: return false
        val manager = windowManager ?: return false
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                resizeStartRawX = event.rawX
                resizeStartRawY = event.rawY
                resizeStartWidth = layoutParams.width
                resizeStartHeight = layoutParams.height
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = (event.rawX - resizeStartRawX).toInt()
                val dy = (event.rawY - resizeStartRawY).toInt()
                if (kotlin.math.abs(dx) + kotlin.math.abs(dy) < dp(8)) return true
                val maxWidth = resources.displayMetrics.widthPixels - dp(8)
                val maxHeight = resources.displayMetrics.heightPixels - dp(24)
                layoutParams.width = clamp(resizeStartWidth + dx, dp(330), maxWidth)
                layoutParams.height = clamp(resizeStartHeight + dy, dp(360), maxHeight)
                restoreHeight = layoutParams.height
                manager.updateViewLayout(rootView, layoutParams)
                return true
            }
        }
        return false
    }

    private fun toggleMinimized() {
        val layoutParams = params ?: return
        val manager = windowManager ?: return
        minimized = !minimized
        if (minimized) {
            restoreHeight = layoutParams.height
            webView?.visibility = View.GONE
            bottomBar?.visibility = View.GONE
            layoutParams.height = dp(32)
            layoutParams.width = min(layoutParams.width, dp(320))
        } else {
            webView?.visibility = View.VISIBLE
            bottomBar?.visibility = View.VISIBLE
            layoutParams.height = max(restoreHeight, dp(360))
            layoutParams.width = max(layoutParams.width, dp(330))
        }
        manager.updateViewLayout(rootView, layoutParams)
    }

    private fun titleButton(label: String, action: () -> Unit): TextView {
        return TextView(this).apply {
            text = label
            setTextColor(Color.WHITE)
            textSize = 14f
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(dp(36), LinearLayout.LayoutParams.MATCH_PARENT)
            setOnClickListener { action() }
        }
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private fun clamp(value: Int, minValue: Int, maxValue: Int): Int {
        return max(minValue, min(value, maxValue))
    }

    private fun buildNotification(): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "文件管理悬浮窗",
                    NotificationManager.IMPORTANCE_LOW
                )
            )
        }
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_manage)
            .setContentTitle("文件管理悬浮窗")
            .setContentText("正在运行 Web 文件管理器")
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "floating_file_manager"
        private const val NOTIFICATION_ID = 9317
        var isRunning: Boolean = false
            private set

        fun start(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(context)) {
                throw IllegalStateException("Overlay permission is not granted")
            }
            val intent = Intent(context, FloatingFileManagerService::class.java)
            ContextCompatCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, FloatingFileManagerService::class.java))
        }
    }
}

private object ContextCompatCompat {
    fun startForegroundService(context: Context, intent: Intent) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }
}

private class FloatingFileManagerServer(private val context: Context) {
    val token: String = UUID.randomUUID().toString()
    var port: Int = 0
        private set
    private var socket: ServerSocket? = null
    @Volatile private var running = false

    fun start() {
        val serverSocket = ServerSocket(0, 50, InetAddress.getByName("127.0.0.1"))
        socket = serverSocket
        port = serverSocket.localPort
        running = true
        thread(name = "FloatingFileManagerServer", isDaemon = true) {
            while (running) {
                try {
                    val client = serverSocket.accept()
                    thread(name = "FloatingFileManagerClient", isDaemon = true) {
                        handleClient(client)
                    }
                } catch (_: Exception) {
                    if (running) break
                }
            }
        }
    }

    fun stop() {
        running = false
        try {
            socket?.close()
        } catch (_: Exception) {
        }
    }

    private fun handleClient(client: Socket) {
        client.use { socket ->
            try {
                val reader = BufferedReader(InputStreamReader(socket.getInputStream()))
                val requestLine = reader.readLine() ?: return
                val requestParts = requestLine.split(" ")
                if (requestParts.size < 2) return
                val method = requestParts[0].uppercase(Locale.US)
                val target = requestParts[1]
                val headers = mutableMapOf<String, String>()
                var line: String?
                while (true) {
                    line = reader.readLine()
                    if (line == null || line!!.isEmpty()) break
                    val index = line!!.indexOf(':')
                    if (index > 0) {
                        headers[line!!.substring(0, index).trim().lowercase(Locale.US)] =
                            line!!.substring(index + 1).trim()
                    }
                }
                val length = headers["content-length"]?.toIntOrNull() ?: 0
                val body = if (length > 0) {
                    val buffer = CharArray(length)
                    var offset = 0
                    while (offset < length) {
                        val read = reader.read(buffer, offset, length - offset)
                        if (read <= 0) break
                        offset += read
                    }
                    String(buffer, 0, offset)
                } else {
                    ""
                }
                val uri = parseTarget(target)
                if (uri.path == "/") {
                    sendText(socket.getOutputStream(), 200, "text/html; charset=utf-8", html())
                    return
                }
                val headerToken = headers["x-openclaw-file-token"]
                val queryToken = uri.query["token"]
                if (headerToken != token && queryToken != token) {
                    sendJson(socket.getOutputStream(), 403, JSONObject().put("error", "Forbidden"))
                    return
                }
                route(socket.getOutputStream(), method, uri, body)
            } catch (e: Exception) {
                sendJson(
                    socket.getOutputStream(),
                    500,
                    JSONObject().put("error", e.message ?: "Internal error")
                )
            }
        }
    }

    private fun route(out: OutputStream, method: String, uri: ParsedTarget, body: String) {
        when {
            method == "GET" && uri.path == "/api/roots" -> sendJson(out, 200, roots())
            method == "GET" && uri.path == "/api/list" -> {
                val path = uri.query["path"] ?: context.filesDir.absolutePath
                sendJson(out, 200, listDirectory(path))
            }
            method == "GET" && uri.path == "/api/read" -> {
                val file = requireFile(uri.query["path"])
                if (file.length() > 1024 * 1024) {
                    sendJson(out, 413, JSONObject().put("error", "文件超过 1 MB，请使用下载或外部工具打开"))
                } else {
                    sendJson(out, 200, JSONObject().put("content", file.readText()))
                }
            }
            method == "GET" && uri.path == "/api/file" -> {
                val file = requireFile(uri.query["path"])
                sendFile(out, file)
            }
            method == "POST" && uri.path == "/api/write" -> {
                val json = JSONObject(body)
                requireFile(json.optString("path")).writeText(json.optString("content"))
                sendOk(out)
            }
            method == "POST" && uri.path == "/api/mkdir" -> {
                val json = JSONObject(body)
                File(requirePath(json.optString("parent")), cleanName(json.optString("name"))).mkdirs()
                sendOk(out)
            }
            method == "POST" && uri.path == "/api/touch" -> {
                val json = JSONObject(body)
                val file = File(requirePath(json.optString("parent")), cleanName(json.optString("name")))
                if (!file.exists()) file.createNewFile()
                sendOk(out)
            }
            method == "POST" && uri.path == "/api/rename" -> {
                val json = JSONObject(body)
                val source = requirePath(json.optString("path"))
                val target = File(source.parentFile, cleanName(json.optString("name")))
                if (!source.renameTo(target)) error("重命名失败")
                sendOk(out)
            }
            method == "POST" && uri.path == "/api/delete" -> {
                val json = JSONObject(body)
                val source = requirePath(json.optString("path"))
                val ok = if (source.isDirectory) source.deleteRecursively() else source.delete()
                if (!ok) error("删除失败")
                sendOk(out)
            }
            method == "POST" && (uri.path == "/api/copy" || uri.path == "/api/move") -> {
                val json = JSONObject(body)
                val source = requirePath(json.optString("source"))
                val targetDir = requirePath(json.optString("targetDir"))
                val target = availableTarget(File(targetDir, source.name))
                copyRecursively(source, target)
                if (uri.path == "/api/move") {
                    val ok = if (source.isDirectory) source.deleteRecursively() else source.delete()
                    if (!ok) error("移动后删除源文件失败")
                }
                sendOk(out)
            }
            else -> sendJson(out, 404, JSONObject().put("error", "Not found"))
        }
    }

    private fun roots(): JSONObject {
        val roots = JSONArray()
        roots.put(rootItem("应用私有", context.filesDir.absolutePath))
        roots.put(rootItem("应用缓存", context.cacheDir.absolutePath))
        val ubuntuRoot = File(context.filesDir, "rootfs/ubuntu/root")
        if (ubuntuRoot.exists()) roots.put(rootItem("Ubuntu /root", ubuntuRoot.absolutePath))
        listOf(".codex", ".openclaw", ".claude", ".qwen", ".gemini").forEach { name ->
            val dir = File(ubuntuRoot, name)
            if (dir.exists()) roots.put(rootItem(name, dir.absolutePath))
        }
        val external = Environment.getExternalStorageDirectory()
        if (external.exists()) roots.put(rootItem("外部存储", external.absolutePath))
        return JSONObject().put("roots", roots)
    }

    private fun rootItem(label: String, path: String): JSONObject {
        return JSONObject().put("label", label).put("path", path)
    }

    private fun listDirectory(path: String): JSONObject {
        val dir = requirePath(path)
        if (!dir.isDirectory) error("不是目录")
        val entries = JSONArray()
        dir.listFiles()
            ?.sortedWith(compareBy<File> { !it.isDirectory }.thenBy { it.name.lowercase(Locale.US) })
            ?.forEach { file ->
                entries.put(
                    JSONObject()
                        .put("name", file.name)
                        .put("path", file.absolutePath)
                        .put("dir", file.isDirectory)
                        .put("size", file.length())
                        .put("modified", DATE_FORMAT.format(Date(file.lastModified())))
                        .put("read", file.canRead())
                        .put("write", file.canWrite())
                        .put("hidden", file.isHidden)
                )
            }
        return JSONObject()
            .put("path", dir.absolutePath)
            .put("parent", dir.parentFile?.absolutePath ?: dir.absolutePath)
            .put("entries", entries)
    }

    private fun requireFile(path: String?): File {
        val file = requirePath(path)
        if (!file.isFile) error("不是文件")
        return file
    }

    private fun requirePath(path: String?): File {
        if (path.isNullOrBlank()) error("路径为空")
        return File(path).canonicalFile
    }

    private fun cleanName(name: String): String {
        val value = name.trim().replace("/", "")
        if (value.isBlank() || value == "." || value == "..") error("名称无效")
        return value
    }

    private fun availableTarget(initial: File): File {
        if (!initial.exists()) return initial
        val parent = initial.parentFile ?: return initial
        val name = initial.name
        val dot = name.lastIndexOf('.')
        val stem = if (dot > 0) name.substring(0, dot) else name
        val suffix = if (dot > 0) name.substring(dot) else ""
        for (i in 1..999) {
            val candidate = File(parent, "${stem}_copy$i$suffix")
            if (!candidate.exists()) return candidate
        }
        error("无法生成目标文件名")
    }

    private fun copyRecursively(source: File, target: File) {
        if (source.isDirectory) {
            target.mkdirs()
            source.listFiles()?.forEach { child ->
                copyRecursively(child, File(target, child.name))
            }
        } else {
            target.parentFile?.mkdirs()
            source.copyTo(target, overwrite = false)
        }
    }

    private fun sendOk(out: OutputStream) {
        sendJson(out, 200, JSONObject().put("ok", true))
    }

    private fun sendJson(out: OutputStream, status: Int, json: JSONObject) {
        sendText(out, status, "application/json; charset=utf-8", json.toString())
    }

    private fun sendText(out: OutputStream, status: Int, contentType: String, text: String) {
        val bytes = text.toByteArray(Charsets.UTF_8)
        out.write(
            "HTTP/1.1 $status ${statusText(status)}\r\nContent-Type: $contentType\r\nContent-Length: ${bytes.size}\r\nConnection: close\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
                .toByteArray(Charsets.UTF_8)
        )
        out.write(bytes)
        out.flush()
    }

    private fun sendFile(out: OutputStream, file: File) {
        val type = when (file.extension.lowercase(Locale.US)) {
            "png" -> "image/png"
            "jpg", "jpeg" -> "image/jpeg"
            "gif" -> "image/gif"
            "webp" -> "image/webp"
            "svg" -> "image/svg+xml"
            "txt", "md", "json", "yaml", "yml", "toml", "xml", "html", "css", "js", "dart", "kt", "java", "py", "sh", "log" -> "text/plain; charset=utf-8"
            else -> "application/octet-stream"
        }
        out.write(
            "HTTP/1.1 200 OK\r\nContent-Type: $type\r\nContent-Length: ${file.length()}\r\nConnection: close\r\n\r\n"
                .toByteArray(Charsets.UTF_8)
        )
        FileInputStream(file).use { input -> input.copyTo(out) }
        out.flush()
    }

    private fun parseTarget(target: String): ParsedTarget {
        val split = target.split("?", limit = 2)
        val path = URLDecoder.decode(split[0], "UTF-8")
        val query = mutableMapOf<String, String>()
        if (split.size > 1) {
            split[1].split("&").forEach { pair ->
                val index = pair.indexOf('=')
                if (index >= 0) {
                    query[URLDecoder.decode(pair.substring(0, index), "UTF-8")] =
                        URLDecoder.decode(pair.substring(index + 1), "UTF-8")
                }
            }
        }
        return ParsedTarget(path, query)
    }

    private fun statusText(status: Int): String = when (status) {
        200 -> "OK"
        403 -> "Forbidden"
        404 -> "Not Found"
        413 -> "Payload Too Large"
        else -> "Error"
    }

    private fun html(): String {
        return """
<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>文件管理</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#121212;color:#eee;font:12px system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;overflow:hidden}
.app{height:100vh;display:flex;flex-direction:column}.toolbar{height:34px;background:#000;display:flex;align-items:center;gap:4px;padding:3px 5px;border-bottom:1px solid #2a2a2a}
button{background:#1f1f1f;color:#fff;border:1px solid #333;border-radius:5px;height:26px;padding:0 8px;font-size:11px}button.primary{background:#dc2626;border-color:#dc2626}.path{flex:1;min-width:0;color:#bbb;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.cols{flex:1;min-height:0;display:grid;grid-template-columns:1fr 1fr}.pane{min-width:0;display:flex;flex-direction:column;border-right:1px solid #2a2a2a}.pane:last-child{border-right:0}
.paneHead{height:56px;background:#050505;padding:4px;border-bottom:1px solid #2a2a2a}.roots{display:flex;gap:4px;overflow:auto;padding-bottom:3px}.roots button{height:23px;white-space:nowrap}
.list{flex:1;min-height:0;overflow:auto}.row{height:38px;display:flex;align-items:center;gap:5px;padding:3px 5px;border-bottom:1px solid #202020}.row.sel{background:#451818}.icon{width:18px;text-align:center}.name{flex:1;min-width:0}.name b{display:block;font-size:11.5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.name span{display:block;color:#999;font-size:9.5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.editor{height:38vh;border-top:1px solid #2a2a2a;background:#151515;display:flex;flex-direction:column}.tabs{height:28px;background:#050505;display:flex;align-items:center;gap:4px;padding:3px 5px}.editBody{flex:1;min-height:0}textarea{width:100%;height:100%;resize:none;background:#101010;color:#eee;border:0;padding:8px;font:12px ui-monospace,monospace;outline:none}img{max-width:100%;max-height:100%;object-fit:contain;display:block;margin:auto}.preview{height:100%;overflow:auto;padding:8px;white-space:pre-wrap;font:12px ui-monospace,monospace}
</style></head><body><div class="app">
<div class="toolbar"><button onclick="refresh()">刷新</button><button onclick="mkdir()">新建夹</button><button onclick="touch()">新建文件</button><button onclick="renameSel()">重命名</button><button onclick="deleteSel()">删除</button><button onclick="copyMove(false)">复制到对侧</button><button onclick="copyMove(true)">移动到对侧</button><div class="path" id="status">加载中</div></div>
<div class="cols"><div class="pane" id="left"></div><div class="pane" id="right"></div></div>
<div class="editor" id="editor" style="display:none"><div class="tabs"><button class="primary" onclick="saveFile()">保存</button><button onclick="closeEditor()">关闭</button><div class="path" id="editPath"></div></div><div class="editBody" id="editBody"></div></div>
</div><script>
const TOKEN="$token";let roots=[],panes={left:{path:"",entries:[]},right:{path:"",entries:[]}},active="left",selected=null,editing=null;
async function api(path,opt={}){opt.headers=Object.assign({"X-OpenClaw-File-Token":TOKEN},opt.headers||{});if(opt.body&&typeof opt.body!=="string"){opt.headers["Content-Type"]="application/json";opt.body=JSON.stringify(opt.body)}let r=await fetch(path,opt);let t=await r.text();let j;try{j=JSON.parse(t)}catch(e){j={error:t}}if(!r.ok)throw Error(j.error||r.status);return j}
function qs(v){return encodeURIComponent(v||"")}async function init(){let r=await api("/api/roots");roots=r.roots||[];panes.left.path=(roots[0]&&roots[0].path)||"/";panes.right.path=(roots[2]&&roots[2].path)||(roots[0]&&roots[0].path)||"/";await Promise.all([load("left"),load("right")])}
async function load(id,path){if(path)panes[id].path=path;try{let r=await api("/api/list?path="+qs(panes[id].path));panes[id].path=r.path;panes[id].entries=r.entries||[];render(id);stat(r.path)}catch(e){stat(e.message)}}
function render(id){let p=panes[id],el=document.getElementById(id);let rootButtons=roots.map(x=>'<button data-pane="'+id+'" data-path="'+attr(x.path)+'" onclick="load(this.dataset.pane,this.dataset.path)">'+htmlEsc(x.label)+'</button>').join("");let up='<div class="row" data-pane="'+id+'" data-path="'+attr(parent(p.path))+'" onclick="load(this.dataset.pane,this.dataset.path)"><div class="icon">↥</div><div class="name"><b>..</b><span>上级目录</span></div></div>';el.innerHTML='<div class="paneHead"><div class="roots">'+rootButtons+'</div><div class="path">'+htmlEsc(p.path)+'</div></div><div class="list">'+[up].concat(p.entries.map(e=>row(id,e))).join("")+'</div>'}
function row(id,e){let isSel=selected&&selected.path===e.path;return '<div class="row '+(isSel?'sel':'')+'" data-pane="'+id+'" data-path="'+attr(e.path)+'" data-dir="'+(e.dir?'1':'0')+'" onclick="openEntry(this.dataset.pane,this.dataset.path,this.dataset.dir===\'1\')"><div class="icon">'+(e.dir?'▣':'□')+'</div><div class="name"><b>'+htmlEsc(e.name)+'</b><span>'+(e.dir?'文件夹':fmt(e.size))+' · '+htmlEsc(e.modified)+'</span></div><button data-pane="'+id+'" data-path="'+attr(e.path)+'" onclick="event.stopPropagation();select(this.dataset.pane,this.dataset.path)">更多</button></div>'}
function select(id,path){active=id;selected=panes[id].entries.find(e=>e.path===path);render("left");render("right");stat(selected?selected.path:"未选择")}
function openEntry(id,path,isDir){active=id;if(isDir){load(id,path);return}selected=panes[id].entries.find(e=>e.path===path);openFile(path)}
async function openFile(path){editing=path;document.getElementById("editor").style.display="flex";document.getElementById("editPath").textContent=path;let ext=path.split(".").pop().toLowerCase();if(["png","jpg","jpeg","gif","webp","bmp","svg"].includes(ext)){document.getElementById("editBody").innerHTML='<img src="/api/file?token='+TOKEN+'&path='+qs(path)+'">';return}try{let r=await api("/api/read?path="+qs(path));document.getElementById("editBody").innerHTML='<textarea id="textEdit"></textarea>';document.getElementById("textEdit").value=r.content||""}catch(e){document.getElementById("editBody").innerHTML='<div class="preview">'+htmlEsc(e.message)+'</div>'}}
async function saveFile(){let t=document.getElementById("textEdit");if(!editing||!t)return;await api("/api/write",{method:"POST",body:{path:editing,content:t.value}});refresh();stat("已保存")}
function closeEditor(){editing=null;document.getElementById("editor").style.display="none"}function refresh(){load("left");load("right")}function cur(){return panes[active]}function other(){return active==="left"?panes.right:panes.left}
async function mkdir(){let n=prompt("文件夹名称");if(!n)return;await api("/api/mkdir",{method:"POST",body:{parent:cur().path,name:n}});load(active)}
async function touch(){let n=prompt("文件名称");if(!n)return;await api("/api/touch",{method:"POST",body:{parent:cur().path,name:n}});load(active)}
async function renameSel(){if(!selected)return alert("未选择");let n=prompt("新名称",selected.name);if(!n)return;await api("/api/rename",{method:"POST",body:{path:selected.path,name:n}});selected=null;refresh()}
async function deleteSel(){if(!selected)return alert("未选择");if(!confirm("删除 "+selected.name+"？"))return;await api("/api/delete",{method:"POST",body:{path:selected.path}});selected=null;refresh()}
async function copyMove(move){if(!selected)return alert("未选择");await api(move?"/api/move":"/api/copy",{method:"POST",body:{source:selected.path,targetDir:other().path}});if(move)selected=null;refresh()}
function parent(p){let i=p.replace(/\/+$/,'').lastIndexOf('/');return i<=0?"/":p.slice(0,i)}function fmt(s){if(s<1024)return s+" B";if(s<1048576)return(s/1024).toFixed(1)+" KB";return(s/1048576).toFixed(1)+" MB"}function stat(s){document.getElementById("status").textContent=s}function htmlEsc(s){return String(s).replace(/[&<>"]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;"}[c]))}function attr(s){return htmlEsc(s).replace(/'/g,"&#39;")}
init().catch(e=>stat(e.message));
</script></body></html>
        """.trimIndent()
    }

    companion object {
        private val DATE_FORMAT = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.US)
    }
}

private data class ParsedTarget(
    val path: String,
    val query: Map<String, String>
)
