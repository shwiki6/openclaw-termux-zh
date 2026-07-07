import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../services/app_navigation_service.dart';
import '../services/file_manager_service.dart';
import '../services/native_bridge.dart';

class FileManagerOverlayController {
  FileManagerOverlayController._();

  static final visible = ValueNotifier<bool>(false);
  static OverlayEntry? _entry;
  static bool _systemOverlayActive = false;

  static const _fallbackScreenSize = Size(393, 780);
  static const _overlayMargin = 6.0;
  static const _overlayTopMargin = 42.0;

  static bool get isUsingOverlayEntry => _entry != null;
  static bool get isUsingSystemOverlay => _systemOverlayActive;

  static void show() {
    unawaited(_show());
  }

  static Future<void> _show() async {
    if (Platform.isAndroid) {
      await _closeSystemOverlay();
      try {
        final started = await NativeBridge.startFloatingFileManager();
        _systemOverlayActive = started;
        visible.value = started;
      } catch (_) {
        visible.value = false;
      }
      return;
    }
    if (await _showSystemOverlay()) {
      _systemOverlayActive = true;
      visible.value = true;
      return;
    }
    _showInApp();
  }

  static Future<bool> _showSystemOverlay() async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      var granted = await FlutterOverlayWindow.isPermissionGranted();
      if (!granted) {
        granted = await FlutterOverlayWindow.requestPermission() == true;
      }
      if (!granted) {
        return false;
      }
      final metrics = _initialOverlayMetrics();
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.resizeOverlay(
          metrics.logicalSize.width.round(),
          metrics.logicalSize.height.round(),
          false,
        );
        await FlutterOverlayWindow.moveOverlay(
          OverlayPosition(
            metrics.logicalPosition.dx,
            metrics.logicalPosition.dy,
          ),
        );
        return true;
      }
      await FlutterOverlayWindow.showOverlay(
        width: metrics.physicalSize.width.round(),
        height: metrics.physicalSize.height.round(),
        alignment: OverlayAlignment.topLeft,
        flag: OverlayFlag.focusPointer,
        visibility: NotificationVisibility.visibilityPrivate,
        overlayTitle: '文件管理',
        overlayContent: '全局悬浮文件管理器正在运行',
        enableDrag: false,
        positionGravity: PositionGravity.none,
        startPosition: OverlayPosition(
          metrics.logicalPosition.dx,
          metrics.logicalPosition.dy,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static _SystemOverlayMetrics _initialOverlayMetrics() {
    final context = AppNavigationService.context;
    final mediaQuery = context == null ? null : MediaQuery.maybeOf(context);
    final screen = mediaQuery?.size ?? _fallbackScreenSize;
    final scale = mediaQuery?.devicePixelRatio ?? 1.0;
    final availableWidth = math.max(
      300.0,
      screen.width - (_overlayMargin * 2),
    );
    final width = screen.width >= 700
        ? math.min(720.0, availableWidth)
        : availableWidth;
    final availableHeight = math.max(
      300.0,
      screen.height - _overlayTopMargin - _overlayMargin,
    );
    final height = screen.height >= 720
        ? math.min(620.0, availableHeight)
        : availableHeight;
    final logicalSize = Size(width, height);
    final logicalPosition = Offset(
      _overlayMargin,
      math.min(_overlayTopMargin, math.max(_overlayMargin, screen.height / 10)),
    );
    return _SystemOverlayMetrics(
      logicalSize: logicalSize,
      physicalSize: Size(logicalSize.width * scale, logicalSize.height * scale),
      logicalPosition: logicalPosition,
    );
  }

  static void _showInApp() {
    _systemOverlayActive = false;
    if (_entry != null) {
      visible.value = true;
      return;
    }

    final overlay = AppNavigationService.navigatorKey.currentState?.overlay;
    if (overlay != null) {
      _entry = OverlayEntry(
        builder: (_) => const FloatingFileManagerWindow(),
      );
      overlay.insert(_entry!);
    }
    visible.value = true;
  }

  static void hide() {
    if (Platform.isAndroid) {
      unawaited(_closeSystemOverlay());
      unawaited(NativeBridge.stopFloatingFileManager());
    }
    _entry?.remove();
    _entry = null;
    _systemOverlayActive = false;
    visible.value = false;
  }

  static Future<void> _closeSystemOverlay() async {
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
  }

  static void toggle() {
    if (visible.value) {
      hide();
    } else {
      show();
    }
  }
}

class FileManagerOverlayHost extends StatelessWidget {
  final Widget child;

  const FileManagerOverlayHost({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        ValueListenableBuilder<bool>(
          valueListenable: FileManagerOverlayController.visible,
          builder: (context, visible, _) {
            if (!visible ||
                FileManagerOverlayController.isUsingOverlayEntry ||
                FileManagerOverlayController.isUsingSystemOverlay) {
              return const SizedBox.shrink();
            }
            return const FloatingFileManagerWindow();
          },
        ),
      ],
    );
  }
}

class FloatingFileManagerWindow extends StatefulWidget {
  final bool systemOverlay;

  const FloatingFileManagerWindow({
    super.key,
    this.systemOverlay = false,
  });

  @override
  State<FloatingFileManagerWindow> createState() =>
      _FloatingFileManagerWindowState();
}

class _FloatingFileManagerWindowState extends State<FloatingFileManagerWindow> {
  static const _accentColor = Color(0xFFDC2626);
  static const _folderColor = Color(0xFFF59E0B);
  static const _fontScale = 0.82;
  static const _titleBarHeight = 30.0;
  static const _tabStripHeight = 30.0;
  static const _bottomBarHeight = 38.0;
  static const _paneHeaderHeight = 48.0;
  static const _smallTextSize = 10.0;
  static const _tabTextSize = 10.5;
  static const _editorTextSize = 12.0;
  static const _systemMoveInterval = Duration(milliseconds: 72);
  static const _systemResizeInterval = Duration(milliseconds: 72);
  static const _minimizedWindowSize = Size(300, _titleBarHeight);

  final _service = FileManagerService();
  final _left = _FilePaneState(
    title: '智能体工具',
    rootPath: FileManagerService.agentToolsPath,
    currentPath: FileManagerService.agentToolsPath,
  );
  final _right = _FilePaneState(title: '私有目录');
  final _agentRoots = <String>{};

  late Offset _offset;
  Offset _systemOverlayPosition = const Offset(12, 56);
  Size _windowSize = const Size(720, 520);
  Size? _restoreWindowSize;
  _SelectedEntry? _selection;
  _SelectedEntry? _inlineMenuSelection;
  Timer? _systemMoveTimer;
  Timer? _systemResizeTimer;
  Offset? _pendingSystemOverlayPosition;
  Size? _pendingSystemOverlaySize;
  Offset? _dragStartGlobalPosition;
  Offset? _dragStartWindowOffset;
  Offset? _resizeStartGlobalPosition;
  Size? _resizeStartWindowSize;
  Size? _systemMaxWindowSize;
  bool _systemMoveInFlight = false;
  bool _systemResizeInFlight = false;
  bool _systemWindowSizeSynced = false;
  Offset? _queuedSystemOverlayPosition;
  Size? _queuedSystemOverlaySize;
  DateTime _lastSystemOverlayMove = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastSystemOverlayResize = DateTime.fromMillisecondsSinceEpoch(0);
  final _openFileTabs = <_OpenFileTab>[];
  int? _activeFileIndex;
  bool _externalPermission = false;
  bool _initializing = true;
  bool _minimized = false;
  bool _rightExternalMode = false;

  @override
  void initState() {
    super.initState();
    _offset = widget.systemOverlay ? Offset.zero : const Offset(18, 72);
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _systemMoveTimer?.cancel();
    _systemResizeTimer?.cancel();
    for (final tab in _openFileTabs) {
      tab.controller.dispose();
    }
    super.dispose();
  }

  _OpenFileTab? get _activeFileTab {
    final index = _activeFileIndex;
    if (index == null || index < 0 || index >= _openFileTabs.length) {
      return null;
    }
    return _openFileTabs[index];
  }

  void _closeWindow() {
    if (widget.systemOverlay) {
      unawaited(FileManagerOverlayController._closeSystemOverlay());
      return;
    }
    FileManagerOverlayController.hide();
  }

  void _startWindowMove(DragStartDetails details) {
    _dragStartGlobalPosition = details.globalPosition;
    _dragStartWindowOffset =
        widget.systemOverlay ? _systemOverlayPosition : _offset;
  }

  void _moveWindow(DragUpdateDetails details) {
    final dragStart = _dragStartGlobalPosition;
    final windowStart = _dragStartWindowOffset;
    final nextOffset = dragStart == null || windowStart == null
        ? null
        : windowStart + (details.globalPosition - dragStart);
    if (widget.systemOverlay) {
      _systemOverlayPosition =
          nextOffset ?? (_systemOverlayPosition + details.delta);
      _scheduleSystemOverlayMove(_systemOverlayPosition);
      return;
    }
    setState(() {
      _offset = nextOffset ?? (_offset + details.delta);
    });
  }

  void _finishWindowMove() {
    _dragStartGlobalPosition = null;
    _dragStartWindowOffset = null;
    _flushSystemOverlayMove();
  }

  void _flushSystemOverlayMove() {
    final position = _pendingSystemOverlayPosition;
    if (position == null) return;
    _pendingSystemOverlayPosition = null;
    _systemMoveTimer?.cancel();
    _systemMoveTimer = null;
    _lastSystemOverlayMove = DateTime.now();
    unawaited(_moveSystemOverlay(position));
  }

  void _scheduleSystemOverlayMove(Offset position) {
    _pendingSystemOverlayPosition = position;
    final elapsed = DateTime.now().difference(_lastSystemOverlayMove);
    if (elapsed >= _systemMoveInterval) {
      _flushSystemOverlayMove();
      return;
    }
    _systemMoveTimer ??= Timer(
      _systemMoveInterval - elapsed,
      _flushSystemOverlayMove,
    );
  }

  Future<void> _moveSystemOverlay(Offset logicalOffset) async {
    if (_systemMoveInFlight) {
      _queuedSystemOverlayPosition = logicalOffset;
      return;
    }
    _systemMoveInFlight = true;
    var next = logicalOffset;
    while (true) {
      await _moveSystemOverlayOnce(next);
      final queued = _queuedSystemOverlayPosition;
      _queuedSystemOverlayPosition = null;
      if (queued == null || (queued - next).distance < 0.5) {
        break;
      }
      next = queued;
    }
    _systemMoveInFlight = false;
  }

  Future<void> _moveSystemOverlayOnce(Offset logicalOffset) async {
    try {
      await FlutterOverlayWindow.moveOverlay(
        OverlayPosition(logicalOffset.dx, logicalOffset.dy),
      );
    } catch (_) {}
  }

  void _toggleMinimized() {
    if (_minimized) {
      _restoreWindow();
    } else {
      _minimizeWindow();
    }
  }

  void _minimizeWindow() {
    final previous = _windowSize;
    setState(() {
      _restoreWindowSize = previous;
      _windowSize = _minimizedWindowSize;
      _minimized = true;
      _inlineMenuSelection = null;
    });
    if (widget.systemOverlay) {
      unawaited(_resizeSystemOverlay(
        _minimizedWindowSize.width.round(),
        _minimizedWindowSize.height.round(),
      ));
    }
  }

  void _restoreWindow() {
    final restored = _restoreWindowSize ?? const Size(720, 520);
    setState(() {
      _windowSize = restored;
      _minimized = false;
    });
    if (widget.systemOverlay) {
      _scheduleSystemOverlayResize(restored);
    }
  }

  void _resizeWindow(Size screen, double width, double height) {
    if (_minimized) return;
    final nextWidth = _clampWindowWidth(screen, width);
    final nextHeight = _clampWindowHeight(screen, height);
    setState(() {
      _windowSize = Size(nextWidth, nextHeight);
    });
    if (widget.systemOverlay) {
      _scheduleSystemOverlayResize(Size(nextWidth, nextHeight));
    }
  }

  void _startWindowResize(DragStartDetails details) {
    _resizeStartGlobalPosition = details.globalPosition;
    _resizeStartWindowSize = _windowSize;
  }

  void _updateWindowResize(Size screen, DragUpdateDetails details) {
    final startPosition = _resizeStartGlobalPosition;
    final startSize = _resizeStartWindowSize;
    if (startPosition == null || startSize == null) return;
    final delta = details.globalPosition - startPosition;
    if (delta.distance < 8) return;
    _resizeWindow(
      screen,
      startSize.width + delta.dx,
      startSize.height + delta.dy,
    );
  }

  void _finishWindowResize() {
    _resizeStartGlobalPosition = null;
    _resizeStartWindowSize = null;
    _flushSystemOverlayResize();
  }

  void _scheduleSystemOverlayResize(Size size) {
    _pendingSystemOverlaySize = size;
    final elapsed = DateTime.now().difference(_lastSystemOverlayResize);
    if (elapsed >= _systemResizeInterval) {
      _flushSystemOverlayResize();
      return;
    }
    _systemResizeTimer ??= Timer(
      _systemResizeInterval - elapsed,
      _flushSystemOverlayResize,
    );
  }

  void _flushSystemOverlayResize() {
    final size = _pendingSystemOverlaySize;
    if (size == null) return;
    _pendingSystemOverlaySize = null;
    _systemResizeTimer?.cancel();
    _systemResizeTimer = null;
    _lastSystemOverlayResize = DateTime.now();
    unawaited(_resizeSystemOverlay(
      size.width.round(),
      size.height.round(),
    ));
  }

  Future<void> _resizeSystemOverlay(int width, int height) async {
    final logicalSize = Size(width.toDouble(), height.toDouble());
    if (_systemResizeInFlight) {
      _queuedSystemOverlaySize = logicalSize;
      return;
    }
    _systemResizeInFlight = true;
    var next = logicalSize;
    while (true) {
      await _resizeSystemOverlayOnce(
        next.width.round(),
        next.height.round(),
      );
      final queued = _queuedSystemOverlaySize;
      _queuedSystemOverlaySize = null;
      if (queued == null ||
          ((queued.width - next.width).abs() < 0.5 &&
              (queued.height - next.height).abs() < 0.5)) {
        break;
      }
      next = queued;
    }
    _systemResizeInFlight = false;
  }

  Future<void> _resizeSystemOverlayOnce(int width, int height) async {
    try {
      await FlutterOverlayWindow.resizeOverlay(
        width,
        height,
        false,
      );
    } catch (_) {}
  }

  Future<void> _initialize() async {
    try {
      final privateRoot = await _service.getPrivateRoot();
      final hasExternal = await _service.hasExternalPermission();
      _right
        ..title = '私有目录'
        ..rootPath = privateRoot
        ..currentPath = privateRoot;
      if (!mounted) return;
      setState(() {
        _externalPermission = hasExternal;
        _initializing = false;
      });
      await Future.wait([
        _loadPane(_left),
        _loadPane(_right),
      ]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _right.error = '$e';
      });
    }
  }

  Future<void> _loadPane(_FilePaneState pane) async {
    if (!mounted) return;
    setState(() {
      pane.loading = true;
      pane.error = null;
    });
    try {
      final entries = await _service.listDirectory(pane.currentPath);
      if (!mounted) return;
      setState(() {
        pane.entries = entries;
        pane.loading = false;
        if (pane.currentPath == FileManagerService.agentToolsPath) {
          _agentRoots
            ..clear()
            ..addAll(entries.map((entry) => entry.path));
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        pane.entries = const [];
        pane.error = '$e';
        pane.loading = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadPane(_left),
      _loadPane(_right),
    ]);
  }

  Future<void> _requestStoragePermission() async {
    final granted = await _service.requestExternalPermission();
    if (!mounted) return;
    setState(() => _externalPermission = granted);
    if (granted) {
      await _switchRightMode(external: true);
    }
  }

  Future<void> _switchRightMode({required bool external}) async {
    if (external && !_externalPermission) {
      await _requestStoragePermission();
      return;
    }
    final root = external
        ? await _service.getExternalRoot()
        : await _service.getPrivateRoot();
    if (!mounted) return;
    setState(() {
      _rightExternalMode = external;
      _inlineMenuSelection = null;
      _right
        ..title = external ? '外部目录' : '私有目录'
        ..rootPath = root
        ..currentPath = root;
      _clearSelectionIfPane(_right);
    });
    await _loadPane(_right);
  }

  void _openEntry(_FilePaneState pane, FileManagerEntry entry) {
    if (entry.isDirectory) {
      setState(() {
        pane.currentPath = entry.path;
        _inlineMenuSelection = null;
        _clearSelectionIfPane(pane);
      });
      unawaited(_loadPane(pane));
      return;
    }
    setState(() {
      _selection = _SelectedEntry(pane: pane, entry: entry);
      _inlineMenuSelection = null;
    });
    unawaited(_openFileTab(entry));
  }

  Future<void> _goUp(_FilePaneState pane) async {
    final current = pane.currentPath;
    if (current == FileManagerService.agentToolsPath) return;
    if (current == pane.rootPath) return;
    var parent = FileManagerService.parentPath(current);
    if (pane == _left && _agentRoots.contains(current)) {
      parent = FileManagerService.agentToolsPath;
    }
    if (parent == null) return;
    setState(() {
      pane.currentPath = parent!;
      _clearSelectionIfPane(pane);
    });
    await _loadPane(pane);
  }

  Future<void> _goHome(_FilePaneState pane) async {
    setState(() {
      pane.currentPath = pane.rootPath;
      _clearSelectionIfPane(pane);
    });
    await _loadPane(pane);
  }

  Future<void> _create(_FilePaneState pane, {required bool directory}) async {
    if (!_service.canCreateIn(pane.currentPath)) return;
    final name = await _promptText(
      title: directory ? '新建文件夹' : '新建文件',
      label: directory ? '文件夹名称' : '文件名称',
    );
    if (name == null) return;
    try {
      if (directory) {
        await _service.createDirectory(pane.currentPath, name);
      } else {
        await _service.createFile(pane.currentPath, name);
      }
      await _loadPane(pane);
    } catch (e) {
      _showSnack('创建失败：$e');
    }
  }

  Future<void> _renameSelected() async {
    final selected = _selection;
    if (selected == null) return;
    final name = await _promptText(
      title: '重命名',
      label: '新名称',
      initialValue: selected.entry.name,
    );
    if (name == null) return;
    try {
      await _service.renameEntry(selected.entry.path, name);
      setState(() {
        _selection = null;
        _inlineMenuSelection = null;
      });
      await _loadPane(selected.pane);
    } catch (e) {
      _showSnack('重命名失败：$e');
    }
  }

  Future<void> _deleteSelected() async {
    final selected = _selection;
    if (selected == null) return;
    final confirmed = await _confirm(
      title: '删除 ${selected.entry.name}？',
      body: selected.entry.isDirectory
          ? '将递归删除该文件夹内的所有内容。'
          : '将永久删除该文件。',
      action: '删除',
    );
    if (!confirmed) return;
    try {
      await _service.deleteEntry(selected.entry.path);
      setState(() {
        _selection = null;
        _inlineMenuSelection = null;
      });
      await _loadPane(selected.pane);
    } catch (e) {
      _showSnack('删除失败：$e');
    }
  }

  Future<void> _copyOrMoveSelected({required bool move}) async {
    final selected = _selection;
    if (selected == null) return;
    final targetPane = selected.pane == _left ? _right : _left;
    if (targetPane.currentPath == FileManagerService.agentToolsPath) {
      _showSnack('请先在目标列进入一个真实目录');
      return;
    }
    try {
      if (move) {
        await _service.moveEntry(selected.entry.path, targetPane.currentPath);
      } else {
        await _service.copyEntry(selected.entry.path, targetPane.currentPath);
      }
      setState(() {
        if (move) _selection = null;
        _inlineMenuSelection = null;
      });
      await Future.wait([
        _loadPane(selected.pane),
        _loadPane(targetPane),
      ]);
    } catch (e) {
      _showSnack('${move ? '移动' : '复制'}失败：$e');
    }
  }

  Future<void> _openFileTab(FileManagerEntry entry) async {
    if (entry.isDirectory) return;
    final existingIndex =
        _openFileTabs.indexWhere((tab) => tab.path == entry.path);
    if (existingIndex >= 0) {
      setState(() => _activeFileIndex = existingIndex);
      return;
    }

    final tab = _OpenFileTab(entry: entry);
    setState(() {
      _openFileTabs.add(tab);
      _activeFileIndex = _openFileTabs.length - 1;
    });

    if (_isImageFile(entry.name)) {
      setState(() {
        tab.kind = _OpenFileKind.image;
        tab.loading = false;
      });
      return;
    }

    try {
      final isText = await _service.isLikelyTextFile(
        entry.path,
        name: entry.name,
      );
      if (!mounted || !_openFileTabs.contains(tab)) return;
      if (!isText) {
        final preview = await _service.readHexPreview(entry.path);
        if (!mounted || !_openFileTabs.contains(tab)) return;
        setState(() {
          tab.content = preview;
          tab.controller.text = preview;
          tab.kind = _OpenFileKind.binary;
          tab.loading = false;
        });
        return;
      }
      final content = await _service.readTextFile(entry.path);
      if (!mounted || !_openFileTabs.contains(tab)) return;
      setState(() {
        tab.content = content;
        tab.controller.text = content;
        tab.loading = false;
      });
    } catch (e) {
      if (!mounted || !_openFileTabs.contains(tab)) return;
      setState(() {
        tab.loading = false;
        tab.error = '$e';
      });
    }
  }

  bool _isImageFile(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp');
  }

  Future<void> _retryOpenFile(_OpenFileTab tab) async {
    setState(() {
      tab.loading = true;
      tab.error = null;
    });
    try {
      if (tab.kind == _OpenFileKind.binary) {
        final preview = await _service.readHexPreview(tab.path);
        if (!mounted || !_openFileTabs.contains(tab)) return;
        setState(() {
          tab.content = preview;
          tab.controller.text = preview;
          tab.dirty = false;
          tab.loading = false;
        });
        return;
      }
      final content = await _service.readTextFile(tab.path);
      if (!mounted || !_openFileTabs.contains(tab)) return;
      setState(() {
        tab.content = content;
        tab.controller.text = content;
        tab.dirty = false;
        tab.loading = false;
      });
    } catch (e) {
      if (!mounted || !_openFileTabs.contains(tab)) return;
      setState(() {
        tab.error = '$e';
        tab.loading = false;
      });
    }
  }

  Future<void> _saveActiveFile() async {
    final tab = _activeFileTab;
    if (tab == null ||
        tab.kind != _OpenFileKind.text ||
        tab.loading ||
        tab.error != null) {
      return;
    }
    setState(() => tab.saving = true);
    try {
      await _service.writeTextFile(tab.path, tab.controller.text);
      if (!mounted || !_openFileTabs.contains(tab)) return;
      setState(() {
        tab.content = tab.controller.text;
        tab.dirty = false;
        tab.saving = false;
      });
      await _refreshSelectedPane();
      _showSnack('已保存');
    } catch (e) {
      if (!mounted || !_openFileTabs.contains(tab)) return;
      setState(() => tab.saving = false);
      _showSnack('保存失败：$e');
    }
  }

  Future<void> _closeFileTab(int index) async {
    if (index < 0 || index >= _openFileTabs.length) return;
    final tab = _openFileTabs[index];
    if (tab.dirty) {
      final confirmed = await _confirm(
        title: '关闭 ${tab.name}？',
        body: '文件有未保存修改，关闭后这些修改会丢失。',
        action: '关闭',
      );
      if (!confirmed) return;
    }

    setState(() {
      final wasActive = _activeFileIndex == index;
      _openFileTabs.removeAt(index);
      tab.controller.dispose();
      final active = _activeFileIndex;
      if (_openFileTabs.isEmpty) {
        _activeFileIndex = null;
      } else if (wasActive) {
        _activeFileIndex = index >= _openFileTabs.length
            ? _openFileTabs.length - 1
            : index;
      } else if (active != null && active > index) {
        _activeFileIndex = active - 1;
      }
    });
  }

  Future<void> _closeActiveFileTab() async {
    final index = _activeFileIndex;
    if (index == null) return;
    await _closeFileTab(index);
  }

  void _showFileManagerTab() {
    setState(() => _activeFileIndex = null);
  }

  void _showFileTab(int index) {
    if (index < 0 || index >= _openFileTabs.length) return;
    setState(() => _activeFileIndex = index);
  }

  void _markActiveFileDirty(_OpenFileTab tab) {
    if (tab.loading || tab.saving) return;
    final dirty = tab.controller.text != tab.content;
    if (tab.dirty == dirty) return;
    setState(() => tab.dirty = dirty);
  }

  Future<void> _renameActiveFile() async {
    final tab = _activeFileTab;
    if (tab == null) return;
    final name = await _promptText(
      title: '重命名',
      label: '新名称',
      initialValue: tab.name,
    );
    if (name == null) return;
    try {
      final newPath = await _service.renameEntry(tab.path, name);
      if (!mounted || !_openFileTabs.contains(tab)) return;
      setState(() {
        tab.path = newPath;
        tab.name = FileManagerService.basename(newPath);
        tab.entry = FileManagerEntry(
          name: tab.name,
          path: newPath,
          isDirectory: false,
          size: tab.controller.text.length,
          modified: DateTime.now(),
          isHidden: tab.name.startsWith('.'),
          canRead: true,
          canWrite: true,
        );
      });
      await _refreshSelectedPane();
    } catch (e) {
      _showSnack('重命名失败：$e');
    }
  }

  Future<void> _refreshSelectedPane() async {
    final selected = _selection;
    if (selected == null) return;
    await _loadPane(selected.pane);
  }

  void _select(_FilePaneState pane, FileManagerEntry entry) {
    setState(() {
      _selection = _SelectedEntry(pane: pane, entry: entry);
      _inlineMenuSelection = null;
    });
  }

  void _showEntryMenu(_FilePaneState pane, FileManagerEntry entry) {
    setState(() {
      final selected = _SelectedEntry(pane: pane, entry: entry);
      _selection = selected;
      _inlineMenuSelection = selected;
    });
  }

  void _clearSelectionIfPane(_FilePaneState pane) {
    if (_selection?.pane == pane) {
      _selection = null;
    }
    if (_inlineMenuSelection?.pane == pane) {
      _inlineMenuSelection = null;
    }
  }

  Future<String?> _promptText({
    required String title,
    required String label,
    String initialValue = '',
  }) async {
    final dialogContext = AppNavigationService.context ?? context;
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: dialogContext,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: label),
            onSubmitted: (_) {
              Navigator.of(context).pop(controller.text.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('确定'),
            ),
          ],
        );
      },
    ).then((value) {
      if (value == null || value.trim().isEmpty) return null;
      return value.trim();
    });
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
  }) async {
    final dialogContext = AppNavigationService.context ?? context;
    final result = await showDialog<bool>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    final targetContext = AppNavigationService.context ?? context;
    ScaffoldMessenger.maybeOf(targetContext)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final screen = MediaQuery.sizeOf(context);
    if (widget.systemOverlay && !_systemWindowSizeSynced && !_minimized) {
      _systemMaxWindowSize = screen;
      _windowSize = screen;
      _restoreWindowSize = screen;
      _systemWindowSizeSynced = true;
    }
    final width = widget.systemOverlay
        ? _windowSize.width
        : (_minimized
            ? _windowSize.width
            : _clampWindowWidth(screen, _windowSize.width));
    final height = widget.systemOverlay
        ? _windowSize.height
        : (_minimized
            ? _windowSize.height
            : _clampWindowHeight(screen, _windowSize.height));
    final inset = widget.systemOverlay ? 0.0 : 8.0;
    final maxLeft = screen.width - width - inset;
    final maxTop = screen.height - height - inset;
    final leftUpper = maxLeft < inset ? inset : maxLeft;
    final topUpper = maxTop < inset ? inset : maxTop;
    final left = widget.systemOverlay
        ? 0.0
        : _offset.dx.clamp(inset, leftUpper).toDouble();
    final top = widget.systemOverlay
        ? 0.0
        : _offset.dy.clamp(inset, topUpper).toDouble();
    final compactTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontSizeFactor: _fontScale),
    );

    return Positioned(
      left: left,
      top: top,
      child: Theme(
        data: compactTheme,
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: width,
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: baseTheme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: baseTheme.colorScheme.outline),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 24,
                    color: Color(0x66000000),
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        _buildTitleBar(),
                        if (!_minimized) ...[
                          _buildTabStrip(),
                          Expanded(
                            child: _activeFileTab == null
                                ? _buildBody()
                                : _buildFileEditor(_activeFileTab!),
                          ),
                          _activeFileTab == null
                              ? _buildSelectionBar(screen)
                              : _buildFileEditorBar(_activeFileTab!, screen),
                        ],
                      ],
                    ),
                    if (!_minimized &&
                        _inlineMenuSelection != null &&
                        _activeFileTab == null)
                      Positioned(
                        right: 8,
                        bottom: _bottomBarHeight + 8,
                        child: _buildInlineEntryMenu(_inlineMenuSelection!),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBar() {
    return Container(
      height: _titleBarHeight,
      color: Colors.black,
      padding: const EdgeInsets.only(left: 7, right: 2),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: _startWindowMove,
              onPanUpdate: _moveWindow,
              onPanEnd: (_) => _finishWindowMove(),
              onPanCancel: _finishWindowMove,
              child: Row(
                children: [
                  const Icon(
                    Icons.drag_indicator,
                    color: Colors.white70,
                    size: 17,
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.folder_copy_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      _minimized ? '文件管理 - 已最小化' : '文件管理',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: '刷新',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
            onPressed: _minimized ? null : _refreshAll,
          ),
          IconButton(
            tooltip: _minimized ? '还原' : '最小化',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: Icon(
              _minimized ? Icons.open_in_full : Icons.minimize,
              color: Colors.white,
              size: 16,
            ),
            onPressed: _toggleMinimized,
          ),
          IconButton(
            tooltip: '关闭',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(Icons.close, color: Colors.white, size: 16),
            onPressed: _closeWindow,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
    Color color = Colors.white,
    bool selected = false,
    double size = 16,
  }) {
    return Padding(
      padding: EdgeInsets.zero,
      child: IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        style: IconButton.styleFrom(
          backgroundColor: selected ? _accentColor : Colors.transparent,
          disabledForegroundColor: Colors.white38,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: size),
      ),
    );
  }

  Widget _buildPaneModeButton({
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 1),
      child: SizedBox(
        width: 22,
        height: 22,
        child: TextButton(
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            backgroundColor: selected ? _accentColor : const Color(0xFF1F1F1F),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            textStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          onPressed: onPressed,
          child: Text(label, overflow: TextOverflow.clip),
        ),
      ),
    );
  }

  Widget _buildPathText(_FilePaneState pane) {
    return Text(
      pane.currentPath == FileManagerService.agentToolsPath
          ? '智能体工具目录'
          : pane.currentPath,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 9.5,
        height: 1.1,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildPaneHeader(_FilePaneState pane) {
    return Container(
      height: _paneHeaderHeight,
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 27,
            child: Row(
              children: [
                _buildCompactIconButton(
                  tooltip: '返回上级',
                  icon: Icons.arrow_upward,
                  onPressed: () => _goUp(pane),
                ),
                _buildCompactIconButton(
                  tooltip: '回到根目录',
                  icon: Icons.home_outlined,
                  onPressed: () => _goHome(pane),
                ),
                Expanded(
                  child: Text(
                    pane.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (pane == _right) ...[
                  _buildPaneModeButton(
                    label: '私',
                    selected: !_rightExternalMode,
                    onPressed: () => _switchRightMode(external: false),
                  ),
                  _buildPaneModeButton(
                    label: '外',
                    selected: _rightExternalMode,
                    onPressed: () => _switchRightMode(external: true),
                  ),
                  if (!_externalPermission)
                    _buildCompactIconButton(
                      tooltip: '授权外部存储',
                      icon: Icons.security,
                      onPressed: _requestStoragePermission,
                      size: 15,
                    ),
                ],
                _buildCompactIconButton(
                  tooltip: '新建文件夹',
                  icon: Icons.create_new_folder_outlined,
                  onPressed: () => _create(pane, directory: true),
                ),
                _buildCompactIconButton(
                  tooltip: '新建文件',
                  icon: Icons.note_add_outlined,
                  onPressed: () => _create(pane, directory: false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          _buildPathText(pane),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }

    return Row(
      children: [
        Expanded(child: _buildPane(_left)),
        VerticalDivider(width: 1, color: Theme.of(context).colorScheme.outline),
        Expanded(child: _buildPane(_right)),
      ],
    );
  }

  Widget _buildTabStrip() {
    final managerActive = _activeFileIndex == null;
    return Container(
      height: _tabStripHeight,
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildTabChip(
            title: '文件管理',
            icon: Icons.folder_copy_outlined,
            active: managerActive,
            onTap: _showFileManagerTab,
          ),
          const SizedBox(width: 6),
          for (var i = 0; i < _openFileTabs.length; i++) ...[
            _buildTabChip(
              title: _openFileTabs[i].dirty
                  ? '${_openFileTabs[i].name} *'
                  : _openFileTabs[i].name,
              icon: Icons.description_outlined,
              active: _activeFileIndex == i,
              onTap: () => _showFileTab(i),
              onClose: () => _closeFileTab(i),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildTabChip({
    required String title,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
    VoidCallback? onClose,
  }) {
    return Material(
      color: active ? _accentColor : const Color(0xFF1F1F1F),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 26,
          constraints: const BoxConstraints(minWidth: 82, maxWidth: 190),
          padding: EdgeInsets.only(
            left: 8,
            right: onClose == null ? 8 : 0,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: _tabTextSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onClose != null)
                IconButton(
                  tooltip: '关闭标签',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 14),
                  color: Colors.white,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileEditor(_OpenFileTab tab) {
    final theme = Theme.of(context);
    if (tab.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = tab.error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.error,
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                '无法打开文件',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _retryOpenFile(tab),
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (tab.kind == _OpenFileKind.image) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5,
            child: Image.file(
              File(tab.path),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '无法预览图片：$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    if (tab.kind == _OpenFileKind.binary) {
      return ColoredBox(
        color: theme.colorScheme.surface,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(10),
          child: SelectableText(
            tab.content,
            style: const TextStyle(
              fontFamily: 'DejaVuSansMono',
              fontSize: _editorTextSize,
              height: 1.3,
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: theme.colorScheme.surface,
      child: TextField(
        controller: tab.controller,
        expands: true,
        keyboardType: TextInputType.multiline,
        maxLines: null,
        minLines: null,
        textAlignVertical: TextAlignVertical.top,
        onChanged: (_) => _markActiveFileDirty(tab),
        style: const TextStyle(
          fontFamily: 'DejaVuSansMono',
          fontSize: _editorTextSize,
          height: 1.35,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(12),
        ),
      ),
    );
  }

  Widget _buildFileEditorBar(_OpenFileTab tab, Size screen) {
    return Container(
      height: _bottomBarHeight,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tab.path,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: _smallTextSize,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: '保存',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: tab.kind != _OpenFileKind.text ||
                    tab.loading ||
                    tab.saving ||
                    tab.error != null
                ? null
                : _saveActiveFile,
            icon: tab.saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            color: Colors.white,
            disabledColor: Colors.white38,
          ),
          IconButton(
            tooltip: '重命名',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: tab.loading ? null : _renameActiveFile,
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: Colors.white,
            disabledColor: Colors.white38,
          ),
          IconButton(
            tooltip: '关闭',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: _closeActiveFileTab,
            icon: const Icon(Icons.close, size: 18),
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          _buildResizeHandle(screen),
        ],
      ),
    );
  }

  Widget _buildPane(_FilePaneState pane) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPaneHeader(pane),
        if (pane.error != null)
          MaterialBanner(
            content: Text(
              pane.error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              TextButton(
                onPressed: () => _loadPane(pane),
                child: const Text('重试'),
              ),
            ],
          ),
        Expanded(
          child: pane.loading
              ? const Center(child: CircularProgressIndicator())
              : pane.entries.isEmpty
                  ? Center(
                      child: Text(
                        '空目录',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: pane.entries.length,
                      itemBuilder: (context, index) {
                        final entry = pane.entries[index];
                        final selected = _selection?.entry.path == entry.path;
                        return _buildEntryTile(pane, entry, selected);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildEntryTile(
    _FilePaneState pane,
    FileManagerEntry entry,
    bool selected,
  ) {
    final theme = Theme.of(context);
    final entryType =
        entry.isDirectory ? '文件夹' : FileManagerService.formatSize(entry.size);
    final access = [
      if (!entry.canRead) '不可读',
      if (!entry.canWrite) '只读',
    ].join(' · ');
    final modified = entry.isDirectory ? '' : _formatDate(entry.modified);
    final subtitleParts = [
      entryType,
      if (modified.isNotEmpty) modified,
      if (access.isNotEmpty) access,
    ];
    final subtitle = subtitleParts.join(' · ');
    return Material(
      color: selected ? _accentColor.withAlpha(36) : Colors.transparent,
      child: InkWell(
        onTap: () => _openEntry(pane, entry),
        onLongPress: () => _select(pane, entry),
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              const SizedBox(width: 5),
              Icon(
                entry.isDirectory
                    ? Icons.folder_outlined
                    : Icons.description_outlined,
                size: 19,
                color: !entry.canRead
                    ? theme.disabledColor
                    : entry.isDirectory
                        ? _folderColor
                        : theme.iconTheme.color,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.05,
                        color: entry.isHidden
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        height: 1,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '更多',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 40),
                onPressed: () => _showEntryMenu(pane, entry),
                icon: const Icon(Icons.more_vert, size: 17),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineEntryMenu(_SelectedEntry selected) {
    final theme = Theme.of(context);
    return Material(
      elevation: 10,
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: 238,
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selected.entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭菜单',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 26, minHeight: 26),
                    onPressed: () => setState(() {
                      _inlineMenuSelection = null;
                    }),
                    icon: const Icon(Icons.close, size: 15),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Wrap(
              spacing: 2,
              runSpacing: 2,
              children: [
                _buildInlineMenuAction(
                  icon: Icons.open_in_new,
                  label: '打开',
                  onTap: () => _runInlineMenuAction(() {
                    _openEntry(selected.pane, selected.entry);
                  }),
                ),
                _buildInlineMenuAction(
                  icon: Icons.edit_outlined,
                  label: '重命名',
                  onTap: () => _runInlineMenuAction(_renameSelected),
                ),
                _buildInlineMenuAction(
                  icon: Icons.copy,
                  label: '复制',
                  onTap: () => _runInlineMenuAction(
                    () => _copyOrMoveSelected(move: false),
                  ),
                ),
                _buildInlineMenuAction(
                  icon: Icons.drive_file_move_outline,
                  label: '移动',
                  onTap: () => _runInlineMenuAction(
                    () => _copyOrMoveSelected(move: true),
                  ),
                ),
                _buildInlineMenuAction(
                  icon: Icons.delete_outline,
                  label: '删除',
                  danger: true,
                  onTap: () => _runInlineMenuAction(_deleteSelected),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineMenuAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? Theme.of(context).colorScheme.error : null;
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: color,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label),
    );
  }

  void _runInlineMenuAction(FutureOr<void> Function() action) {
    setState(() {
      _inlineMenuSelection = null;
    });
    unawaited(Future<void>.sync(action));
  }

  Widget _buildSelectionBar(Size screen) {
    final selected = _selection;
    return Container(
      height: _bottomBarHeight,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              selected == null ? '未选择文件' : selected.entry.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: _smallTextSize,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: '复制到另一列',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed:
                selected == null ? null : () => _copyOrMoveSelected(move: false),
            icon: const Icon(Icons.copy, size: 18),
            color: Colors.white,
            disabledColor: Colors.white38,
          ),
          IconButton(
            tooltip: '移动到另一列',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed:
                selected == null ? null : () => _copyOrMoveSelected(move: true),
            icon: const Icon(Icons.drive_file_move_outline, size: 18),
            color: Colors.white,
            disabledColor: Colors.white38,
          ),
          IconButton(
            tooltip: '重命名',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: selected == null ? null : _renameSelected,
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: Colors.white,
            disabledColor: Colors.white38,
          ),
          IconButton(
            tooltip: '删除',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: selected == null ? null : _deleteSelected,
            icon: const Icon(Icons.delete_outline, size: 18),
            color: Colors.white,
            disabledColor: Colors.white38,
          ),
          const SizedBox(width: 4),
          _buildResizeHandle(screen),
        ],
      ),
    );
  }

  Widget _buildResizeHandle(Size screen) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: _startWindowResize,
      onPanUpdate: (details) => _updateWindowResize(screen, details),
      onPanEnd: (_) => _finishWindowResize(),
      onPanCancel: _finishWindowResize,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Transform.rotate(
          angle: math.pi / 2,
          child: const Icon(
            Icons.open_in_full,
            size: 17,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return '';
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  double _clampWindowWidth(Size screen, double value) {
    if (widget.systemOverlay) {
      final maxWidth = math.max(
        260.0,
        _systemMaxWindowSize?.width ?? screen.width,
      );
      final minWidth = math.min(300.0, maxWidth);
      return value.clamp(minWidth, maxWidth).toDouble();
    }
    final maxWidth = screen.width > 336 ? screen.width - 16 : screen.width;
    final minWidth = maxWidth < 320 ? maxWidth : 320.0;
    return value.clamp(minWidth, maxWidth).toDouble();
  }

  double _clampWindowHeight(Size screen, double value) {
    if (widget.systemOverlay) {
      final maxHeight =
          math.max(320.0, _systemMaxWindowSize?.height ?? screen.height);
      final minHeight = math.min(340.0, maxHeight);
      return value.clamp(minHeight, maxHeight).toDouble();
    }
    final maxHeight = screen.height > 376 ? screen.height - 16 : screen.height;
    final minHeight = maxHeight < 360 ? maxHeight : 360.0;
    return value.clamp(minHeight, maxHeight).toDouble();
  }
}

class _FilePaneState {
  String title;
  String rootPath;
  String currentPath;
  List<FileManagerEntry> entries;
  bool loading;
  String? error;

  _FilePaneState({
    required this.title,
    this.rootPath = '',
    this.currentPath = '',
    this.entries = const [],
    this.loading = false,
    this.error,
  });
}

class _SelectedEntry {
  final _FilePaneState pane;
  final FileManagerEntry entry;

  const _SelectedEntry({
    required this.pane,
    required this.entry,
  });
}

class _SystemOverlayMetrics {
  final Size logicalSize;
  final Size physicalSize;
  final Offset logicalPosition;

  const _SystemOverlayMetrics({
    required this.logicalSize,
    required this.physicalSize,
    required this.logicalPosition,
  });
}

class _OpenFileTab {
  FileManagerEntry entry;
  String path;
  String name;
  String content;
  String? error;
  _OpenFileKind kind;
  bool loading;
  bool saving;
  bool dirty;
  final TextEditingController controller;

  _OpenFileTab({
    required this.entry,
  })  : path = entry.path,
        name = entry.name,
        content = '',
        kind = _OpenFileKind.text,
        loading = true,
        saving = false,
        dirty = false,
        controller = TextEditingController();
}

enum _OpenFileKind { text, image, binary }
