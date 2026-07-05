import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/persistent_terminal_session.dart';
import '../services/screenshot_service.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/terminal_toolbar.dart';

class TerminalScreen extends StatefulWidget {
  final String sessionId;
  final String title;
  final String? initialCommand;
  final bool restartOnOpen;

  const TerminalScreen({
    super.key,
    this.sessionId = 'shell',
    this.title = 'Terminal',
    this.initialCommand,
    this.restartOnOpen = false,
  });

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  late final PersistentTerminalSession _session;
  late final TerminalController _controller;
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _ctrlNotifier = ValueNotifier<bool>(false);
  final _altNotifier = ValueNotifier<bool>(false);
  final _screenshotKey = GlobalKey();
  static final _anyUrlRegex = RegExp(r'https?://[^\s<>\[\]"' "'" r'\)]+');

  /// Box-drawing and other TUI characters that break URLs when copied
  static final _boxDrawing = RegExp(r'[│┤├┬┴┼╮╯╰╭─╌╴╶┌┐└┘◇◆]+');

  static const _fontFallback = [
    'monospace',
    'Noto Sans Mono',
    'Noto Sans Mono CJK SC',
    'Noto Sans Mono CJK TC',
    'Noto Sans Mono CJK JP',
    'Noto Color Emoji',
    'Noto Sans Symbols',
    'Noto Sans Symbols 2',
    'sans-serif',
  ];

  @override
  void initState() {
    super.initState();
    _session = PersistentTerminalSessions.getOrCreate(
      id: widget.sessionId,
      title: widget.title,
      initialCommand: widget.initialCommand,
    );
    _session.addListener(_onSessionChanged);
    _controller = TerminalController();
    _session.terminal.onOutput = _handleTerminalInput;
    _session.terminal.onResize = (w, h, pw, ph) {
      _session.resize(w, h);
    };
    // Defer PTY start until after the first frame so TerminalView has been
    // laid out and _terminal.viewWidth/viewHeight reflect real screen
    // dimensions instead of the 80×24 default.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPty(restart: widget.restartOnOpen);
    });
  }

  void _onSessionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _startPty({bool restart = false}) {
    return _session.start(
      columns: _session.terminal.viewWidth,
      rows: _session.terminal.viewHeight,
      restart: restart,
    );
  }

  void _handleTerminalInput(String data) {
    // Intercept keyboard input when CTRL/ALT toolbar modifiers are active.
    if (_ctrlNotifier.value && data.length == 1) {
      final code = data.toLowerCase().codeUnitAt(0);
      if (code >= 97 && code <= 122) {
        _session.writeBytes([code - 96]);
        _ctrlNotifier.value = false;
        return;
      }
    }
    if (_altNotifier.value && data.isNotEmpty) {
      _session.writeInput('\x1b$data');
      _altNotifier.value = false;
      return;
    }
    _session.writeInput(data);
  }

  @override
  void dispose() {
    _session.terminal.onOutput = _session.writeInput;
    _session.removeListener(_onSessionChanged);
    _inputController.dispose();
    _inputFocusNode.dispose();
    _ctrlNotifier.dispose();
    _altNotifier.dispose();
    _controller.dispose();
    super.dispose();
  }

  String? _getSelectedText() {
    final selection = _controller.selection;
    if (selection == null || selection.isCollapsed) return null;

    final range = selection.normalized;
    final sb = StringBuffer();
    for (int y = range.begin.y; y <= range.end.y; y++) {
      if (y >= _session.terminal.buffer.lines.length) break;
      final line = _session.terminal.buffer.lines[y];
      final from = (y == range.begin.y) ? range.begin.x : 0;
      final to = (y == range.end.y) ? range.end.x : null;
      sb.write(line.getText(from, to));
      if (y < range.end.y) sb.writeln();
    }
    final text = sb.toString().trim();
    return text.isEmpty ? null : text;
  }

  String _getAllText() {
    final sb = StringBuffer();
    for (final line in _session.terminal.buffer.lines) {
      sb.writeln(line.getText().trimRight());
    }
    return sb.toString().trimRight();
  }

  /// Extract a clean URL from selected text by stripping box-drawing
  /// chars and rejoining lines, but splitting on `http` boundaries
  /// so concatenated URLs don't merge into one.
  String? _extractUrl(String text) {
    final clean =
        text.replaceAll(_boxDrawing, '').replaceAll(RegExp(r'\s+'), '');
    // Split before each http(s):// so concatenated URLs become separate
    final parts = clean.split(RegExp(r'(?=https?://)'));
    // Return the longest URL match (token URLs are longest)
    String? best;
    for (final part in parts) {
      final match = _anyUrlRegex.firstMatch(part);
      if (match != null) {
        final url = match.group(0)!;
        if (best == null || url.length > best.length) {
          best = url;
        }
      }
    }
    return best;
  }

  void _copySelection() {
    final text = _getSelectedText();
    if (text == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No terminal text selected'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    Clipboard.setData(ClipboardData(text: text));

    // If the copied text contains a URL, offer "Open" action
    final url = _extractUrl(text);
    if (url != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Copied to clipboard'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () {
              final uri = Uri.tryParse(url);
              if (uri != null) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _copyAll() {
    final text = _getAllText();
    if (text.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Terminal output copied'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _openSelection() {
    final text = _getSelectedText();
    if (text == null) return;

    final url = _extractUrl(text);
    if (url != null) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No URL found in selection'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      final current = _inputController.text;
      _inputController.text = '$current${data.text!}';
      _inputController.selection = TextSelection.collapsed(
        offset: _inputController.text.length,
      );
      _inputFocusNode.requestFocus();
    }
  }

  void _sendInputLine() {
    final text = _inputController.text;
    _session.writeInput('$text\r');
    _inputController.clear();
    _inputFocusNode.requestFocus();
  }

  Future<void> _takeScreenshot() async {
    final path = await ScreenshotService.capture(_screenshotKey);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(path != null
            ? 'Screenshot saved: ${path.split('/').last}'
            : 'Failed to capture screenshot'),
      ),
    );
  }

  /// Detect URLs in terminal at tap position. Joins adjacent lines
  /// and strips box-drawing chars to handle wrapped URLs.
  void _handleTap(TapUpDetails details, CellOffset offset) {
    final totalLines = _session.terminal.buffer.lines.length;
    final startRow = (offset.y - 2).clamp(0, totalLines - 1);
    final endRow = (offset.y + 2).clamp(0, totalLines - 1);

    final sb = StringBuffer();
    for (int row = startRow; row <= endRow; row++) {
      sb.write(_getLineText(row).trimRight());
    }
    final url = _extractUrl(sb.toString());
    if (url != null) {
      _openUrl(url);
    }
  }

  String _getLineText(int row) {
    try {
      final line = _session.terminal.buffer.lines[row];
      final sb = StringBuffer();
      for (int i = 0; i < line.length; i++) {
        final char = line.getCodePoint(i);
        if (char != 0) {
          sb.writeCharCode(char);
        }
      }
      return sb.toString();
    } catch (_) {
      return '';
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open Link'),
        content: Text(url),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Link copied'),
                  duration: Duration(seconds: 1),
                ),
              );
              Navigator.pop(ctx, false);
            },
            child: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open'),
          ),
        ],
      ),
    );

    if (shouldOpen == true) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compactActions = MediaQuery.sizeOf(context).width < 380;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: compactActions ? [_buildOverflowMenu()] : _buildToolbarActions(),
      ),
      body: _buildBody(),
    );
  }

  List<Widget> _buildToolbarActions() {
    return [
      IconButton(
        icon: const Icon(Icons.camera_alt_outlined),
        tooltip: 'Screenshot',
        onPressed: _takeScreenshot,
      ),
      IconButton(
        icon: const Icon(Icons.copy),
        tooltip: 'Copy selection',
        onPressed: _copySelection,
      ),
      IconButton(
        icon: const Icon(Icons.select_all),
        tooltip: 'Copy all',
        onPressed: _copyAll,
      ),
      IconButton(
        icon: const Icon(Icons.open_in_browser),
        tooltip: 'Open URL',
        onPressed: _openSelection,
      ),
      IconButton(
        icon: const Icon(Icons.paste),
        tooltip: 'Paste',
        onPressed: _paste,
      ),
      IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: 'Restart',
        onPressed: () {
          _startPty(restart: true);
        },
      ),
      IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Close session',
        onPressed: _closeSession,
      ),
    ];
  }

  Widget _buildOverflowMenu() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'screenshot':
            _takeScreenshot();
            break;
          case 'copy':
            _copySelection();
            break;
          case 'copyAll':
            _copyAll();
            break;
          case 'open':
            _openSelection();
            break;
          case 'paste':
            _paste();
            break;
          case 'restart':
            _startPty(restart: true);
            break;
          case 'close':
            _closeSession();
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'screenshot', child: Text('Screenshot')),
        PopupMenuItem(value: 'copy', child: Text('Copy selection')),
        PopupMenuItem(value: 'copyAll', child: Text('Copy all')),
        PopupMenuItem(value: 'open', child: Text('Open URL')),
        PopupMenuItem(value: 'paste', child: Text('Paste')),
        PopupMenuItem(value: 'restart', child: Text('Restart')),
        PopupMenuItem(value: 'close', child: Text('Close session')),
      ],
    );
  }

  Future<void> _closeSession() async {
    await _session.close();
    if (context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Widget _buildBody() {
    if (_session.loading) {
      return ResponsiveLayout.scrollableCenter(
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Starting terminal...'),
          ],
        ),
      );
    }

    if (_session.error != null) {
      return ResponsiveLayout.scrollableCenter(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _session.error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                _startPty(restart: true);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: RepaintBoundary(
            key: _screenshotKey,
            child: TerminalView(
              _session.terminal,
              controller: _controller,
              textStyle: const TerminalStyle(
                fontSize: 11,
                height: 1.0,
                fontFamily: 'DejaVuSansMono',
                fontFamilyFallback: _fontFallback,
              ),
              onTapUp: _handleTap,
            ),
          ),
        ),
        TerminalToolbar(
          pty: _session.pty,
          ctrlNotifier: _ctrlNotifier,
          altNotifier: _altNotifier,
        ),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildInputBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark ? const Color(0xFF151923) : const Color(0xFFF3F4F6);

    return SafeArea(
      top: false,
      child: Container(
        color: theme.colorScheme.surface,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                focusNode: _inputFocusNode,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                keyboardType: TextInputType.text,
                enableSuggestions: true,
                autocorrect: false,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: fillColor,
                  hintText: '输入命令或消息，点发送写入终端',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => _sendInputLine(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Send',
              onPressed: _session.isRunning ? _sendInputLine : null,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
