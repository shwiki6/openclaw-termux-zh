package com.openclaw.cyx

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.inputmethod.InputMethodManager
import android.widget.FrameLayout
import com.termux.terminal.TerminalEmulator
import com.termux.terminal.TerminalSession
import com.termux.terminal.TerminalSessionClient
import com.termux.view.TerminalView
import com.termux.view.TerminalViewClient
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import kotlin.math.abs
import kotlin.math.roundToInt

class NativeTerminalViewFactory(
    private val messenger: BinaryMessenger,
    private val appContext: Context,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = (args as? Map<*, *>) ?: emptyMap<String, Any?>()
        return NativeTerminalPlatformView(context, appContext, messenger, viewId, params)
    }
}

private data class NativeTerminalSessionHolder(
    val session: TerminalSession,
    val keepAlive: Boolean,
)

class NativeTerminalPlatformView(
    context: Context,
    private val appContext: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    private val params: Map<*, *>,
) : PlatformView, MethodChannel.MethodCallHandler {
    private val container = FrameLayout(context)
    private val terminalView = TerminalView(context, null)
    private val channel = MethodChannel(messenger, "com.openclaw.cyx/native_terminal_$viewId")
    private val sessionId = params.stringValue("sessionId") ?: "native-shell"
    private val keepAlive = params.booleanValue("keepAlive", false)
    private var fontSize = params.intValue("fontSize", 18).coerceIn(MIN_FONT_SIZE, MAX_FONT_SIZE)
    private val client = NativeTerminalClient(
        appContext,
        terminalView,
        channel,
        params.booleanValue("emitOutput", false),
        fontSize,
        ::setFontSize,
        ::focusAndShowKeyboard,
    )
    private var holder: NativeTerminalSessionHolder? = null

    init {
        container.setBackgroundColor(Color.BLACK)
        terminalView.setTerminalViewClient(client)
        terminalView.setTextSize(fontSize)
        terminalView.setTypeface(Typeface.MONOSPACE)
        terminalView.isFocusable = true
        terminalView.isFocusableInTouchMode = true
        container.addView(
            terminalView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
        channel.setMethodCallHandler(this)
        attachOrCreateSession(restart = params.booleanValue("restart", false))
        terminalView.post {
            focusAndShowKeyboard()
        }
    }

    override fun getView(): View = container

    override fun dispose() {
        hideKeyboard()
        channel.setMethodCallHandler(null)
        val current = holder
        if (current != null) {
            if (current.keepAlive) {
                current.session.updateTerminalSessionClient(DetachedTerminalClient)
            } else {
                current.session.finishIfRunning()
                sessions.remove(sessionId)
            }
        }
        holder = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "writeBytes" -> {
                val bytes = call.arguments as? ByteArray
                if (bytes == null) {
                    result.error("INVALID_ARGS", "writeBytes requires Uint8List", null)
                } else {
                    holder?.session?.write(bytes, 0, bytes.size)
                    result.success(true)
                }
            }
            "writeText" -> {
                val text = call.argument<String>("text") ?: ""
                holder?.session?.write(text)
                result.success(true)
            }
            "paste" -> {
                val clipboard = appContext.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                val text = clipboard.primaryClip?.getItemAt(0)?.coerceToText(appContext)?.toString()
                if (!text.isNullOrEmpty()) {
                    holder?.session?.write(text)
                }
                focusAndShowKeyboard()
                result.success(true)
            }
            "showKeyboard" -> {
                focusAndShowKeyboard()
                result.success(true)
            }
            "hideKeyboard" -> {
                hideKeyboard()
                result.success(true)
            }
            "setFontSize" -> {
                val nextFontSize = (call.argument<Number>("fontSize")?.toInt() ?: fontSize)
                    .coerceIn(MIN_FONT_SIZE, MAX_FONT_SIZE)
                setFontSize(nextFontSize)
                result.success(nextFontSize)
            }
            "restart" -> {
                attachOrCreateSession(restart = true)
                focusAndShowKeyboard()
                result.success(true)
            }
            "close" -> {
                hideKeyboard()
                holder?.session?.finishIfRunning()
                sessions.remove(sessionId)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun attachOrCreateSession(restart: Boolean) {
        if (restart) {
            sessions.remove(sessionId)?.session?.finishIfRunning()
        }

        val existing = sessions[sessionId]
        if (existing != null && existing.session.isRunning) {
            existing.session.updateTerminalSessionClient(client)
            holder = existing
            terminalView.attachSession(existing.session)
            terminalView.updateSize()
            return
        }

        val executable = params.stringValue("executable")
            ?: throw IllegalArgumentException("Native terminal requires executable")
        val cwd = params.stringValue("cwd") ?: "/"
        val arguments = params.stringListValue("arguments")
        val env = params.stringMapValue("environment")
            .map { (key, value) -> "$key=$value" }
            .toTypedArray()
        val argv = arrayOf(executable.substringAfterLast('/')) + arguments.toTypedArray()
        val session = TerminalSession(
            executable,
            cwd,
            argv,
            env,
            params.intValue("transcriptRows", 3000),
            client,
        )
        session.mSessionName = sessionId
        val newHolder = NativeTerminalSessionHolder(session, keepAlive)
        holder = newHolder
        if (keepAlive) {
            sessions[sessionId] = newHolder
        }
        terminalView.attachSession(session)
        terminalView.updateSize()
    }

    private fun focusAndShowKeyboard() {
        terminalView.post {
            terminalView.requestFocus()
            val imm = appContext.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
                ?: return@post
            imm.restartInput(terminalView)
            imm.showSoftInput(terminalView, InputMethodManager.SHOW_IMPLICIT)
            terminalView.postDelayed({
                imm.showSoftInput(terminalView, InputMethodManager.SHOW_IMPLICIT)
            }, 80)
        }
    }

    private fun hideKeyboard() {
        val imm = appContext.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
            ?: return
        imm.hideSoftInputFromWindow(terminalView.windowToken, 0)
    }

    private fun setFontSize(nextFontSize: Int) {
        val clamped = nextFontSize.coerceIn(MIN_FONT_SIZE, MAX_FONT_SIZE)
        if (clamped == fontSize) return
        fontSize = clamped
        client.fontSize = clamped
        terminalView.setTextSize(clamped)
        terminalView.updateSize()
    }

    companion object {
        private const val MIN_FONT_SIZE = 12
        private const val MAX_FONT_SIZE = 32
        private val sessions = mutableMapOf<String, NativeTerminalSessionHolder>()
    }
}

private object DetachedTerminalClient : TerminalSessionClient {
    override fun onTextChanged(changedSession: TerminalSession) = Unit
    override fun onTitleChanged(changedSession: TerminalSession) = Unit
    override fun onSessionFinished(finishedSession: TerminalSession) = Unit
    override fun onCopyTextToClipboard(session: TerminalSession, text: String) = Unit
    override fun onPasteTextFromClipboard(session: TerminalSession) = Unit
    override fun onBell(session: TerminalSession) = Unit
    override fun onColorsChanged(session: TerminalSession) = Unit
    override fun onTerminalCursorStateChange(state: Boolean) = Unit
    override fun getTerminalCursorStyle(): Int = TerminalEmulator.DEFAULT_TERMINAL_CURSOR_STYLE
    override fun logError(tag: String, message: String) {
        android.util.Log.e(tag, message)
    }
    override fun logWarn(tag: String, message: String) {
        android.util.Log.w(tag, message)
    }
    override fun logInfo(tag: String, message: String) {
        android.util.Log.i(tag, message)
    }
    override fun logDebug(tag: String, message: String) {
        android.util.Log.d(tag, message)
    }
    override fun logVerbose(tag: String, message: String) {
        android.util.Log.v(tag, message)
    }
    override fun logStackTraceWithMessage(tag: String, message: String, e: Exception) {
        android.util.Log.e(tag, message, e)
    }
    override fun logStackTrace(tag: String, e: Exception) {
        android.util.Log.e(tag, "Detached native terminal error", e)
    }
}

private class NativeTerminalClient(
    private val context: Context,
    private val terminalView: TerminalView,
    private val channel: MethodChannel,
    private val emitOutput: Boolean,
    var fontSize: Int,
    private val setFontSize: (Int) -> Unit,
    private val showKeyboard: () -> Unit,
) : TerminalSessionClient, TerminalViewClient {
    private var controlDown = false
    private var altDown = false
    private var lastTranscript = ""

    override fun onTextChanged(changedSession: TerminalSession) {
        terminalView.onScreenUpdated()
        if (emitOutput) {
            val transcript = changedSession.emulator?.screen?.getTranscriptTextWithFullLinesJoined() ?: ""
            val delta = if (transcript.startsWith(lastTranscript)) {
                transcript.substring(lastTranscript.length)
            } else {
                transcript
            }
            lastTranscript = transcript
            if (delta.isNotEmpty()) {
                channel.invokeMethod("onOutput", delta)
            }
        }
    }

    override fun onTitleChanged(changedSession: TerminalSession) {
        channel.invokeMethod("onTitleChanged", changedSession.title ?: "")
    }

    override fun onSessionFinished(finishedSession: TerminalSession) {
        terminalView.onScreenUpdated()
        channel.invokeMethod("onSessionFinished", finishedSession.exitStatus)
    }

    override fun onCopyTextToClipboard(session: TerminalSession, text: String) {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText("terminal", text))
    }

    override fun onPasteTextFromClipboard(session: TerminalSession) {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val text = clipboard.primaryClip?.getItemAt(0)?.coerceToText(context)?.toString()
        if (!text.isNullOrEmpty()) {
            session.write(text)
        }
    }

    override fun onBell(session: TerminalSession) = Unit

    override fun onColorsChanged(session: TerminalSession) {
        terminalView.onScreenUpdated()
    }

    override fun onTerminalCursorStateChange(state: Boolean) {
        terminalView.setTerminalCursorBlinkerState(state, true)
    }

    override fun getTerminalCursorStyle(): Int = TerminalEmulator.DEFAULT_TERMINAL_CURSOR_STYLE

    override fun onScale(scale: Float): Float {
        if (scale.isNaN() || scale.isInfinite()) return 1.0f
        val nextFontSize = (fontSize * scale).roundToInt().coerceIn(12, 32)
        if (abs(nextFontSize - fontSize) >= 1) {
            setFontSize(nextFontSize)
        }
        return 1.0f
    }

    override fun onSingleTapUp(e: MotionEvent) {
        showKeyboard()
    }

    override fun shouldBackButtonBeMappedToEscape(): Boolean = false

    override fun shouldEnforceCharBasedInput(): Boolean = false

    override fun shouldUseCtrlSpaceWorkaround(): Boolean = true

    override fun isTerminalViewSelected(): Boolean = terminalView.hasFocus()

    override fun copyModeChanged(copyMode: Boolean) = Unit

    override fun onKeyDown(keyCode: Int, e: KeyEvent, session: TerminalSession): Boolean = false

    override fun onKeyUp(keyCode: Int, e: KeyEvent): Boolean = false

    override fun onLongPress(event: MotionEvent): Boolean = false

    override fun readControlKey(): Boolean {
        val value = controlDown
        controlDown = false
        return value
    }

    override fun readAltKey(): Boolean {
        val value = altDown
        altDown = false
        return value
    }

    override fun readShiftKey(): Boolean = false

    override fun readFnKey(): Boolean = false

    override fun onCodePoint(codePoint: Int, ctrlDown: Boolean, session: TerminalSession): Boolean = false

    override fun onEmulatorSet() {
        terminalView.setTerminalCursorBlinkerRate(700)
        terminalView.setTerminalCursorBlinkerState(true, true)
    }

    override fun logError(tag: String, message: String) {
        android.util.Log.e(tag, message)
    }
    override fun logWarn(tag: String, message: String) {
        android.util.Log.w(tag, message)
    }
    override fun logInfo(tag: String, message: String) {
        android.util.Log.i(tag, message)
    }
    override fun logDebug(tag: String, message: String) {
        android.util.Log.d(tag, message)
    }
    override fun logVerbose(tag: String, message: String) {
        android.util.Log.v(tag, message)
    }
    override fun logStackTraceWithMessage(tag: String, message: String, e: Exception) {
        android.util.Log.e(tag, message, e)
    }
    override fun logStackTrace(tag: String, e: Exception) {
        android.util.Log.e(tag, "Native terminal error", e)
    }
}

private fun Map<*, *>.stringValue(key: String): String? = this[key] as? String

private fun Map<*, *>.booleanValue(key: String, defaultValue: Boolean): Boolean =
    this[key] as? Boolean ?: defaultValue

private fun Map<*, *>.intValue(key: String, defaultValue: Int): Int =
    (this[key] as? Number)?.toInt() ?: defaultValue

private fun Map<*, *>.stringListValue(key: String): List<String> =
    (this[key] as? List<*>)?.mapNotNull { it as? String } ?: emptyList()

private fun Map<*, *>.stringMapValue(key: String): Map<String, String> =
    (this[key] as? Map<*, *>)
        ?.mapNotNull { (key, value) ->
            val stringKey = key as? String
            val stringValue = value as? String
            if (stringKey != null && stringValue != null) stringKey to stringValue else null
        }
        ?.toMap()
        ?: emptyMap()
