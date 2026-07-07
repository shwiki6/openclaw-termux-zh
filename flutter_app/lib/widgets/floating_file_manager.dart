import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_navigation_service.dart';
import '../services/file_manager_service.dart';

class FileManagerOverlayController {
  FileManagerOverlayController._();

  static final visible = ValueNotifier<bool>(false);
  static OverlayEntry? _entry;

  static bool get isUsingOverlayEntry => _entry != null;

  static void show() {
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
    _entry?.remove();
    _entry = null;
    visible.value = false;
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
            if (!visible || FileManagerOverlayController.isUsingOverlayEntry) {
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
  const FloatingFileManagerWindow({super.key});

  @override
  State<FloatingFileManagerWindow> createState() =>
      _FloatingFileManagerWindowState();
}

class _FloatingFileManagerWindowState extends State<FloatingFileManagerWindow> {
  static const _accentColor = Color(0xFFDC2626);
  static const _folderColor = Color(0xFFF59E0B);

  final _service = FileManagerService();
  final _left = _FilePaneState(
    title: '智能体工具',
    rootPath: FileManagerService.agentToolsPath,
    currentPath: FileManagerService.agentToolsPath,
  );
  final _right = _FilePaneState(title: '私有目录');
  final _agentRoots = <String>{};

  Offset _offset = const Offset(18, 72);
  Size _windowSize = const Size(720, 520);
  _SelectedEntry? _selection;
  bool _externalPermission = false;
  bool _initializing = true;
  bool _rightExternalMode = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
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
        _clearSelectionIfPane(pane);
      });
      unawaited(_loadPane(pane));
      return;
    }
    setState(() {
      _selection = _SelectedEntry(pane: pane, entry: entry);
    });
    unawaited(_editTextFile(entry));
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
      setState(() => _selection = null);
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
      setState(() => _selection = null);
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
      });
      await Future.wait([
        _loadPane(selected.pane),
        _loadPane(targetPane),
      ]);
    } catch (e) {
      _showSnack('${move ? '移动' : '复制'}失败：$e');
    }
  }

  Future<void> _editTextFile(FileManagerEntry entry) async {
    if (entry.isDirectory) return;
    String content;
    try {
      content = await _service.readTextFile(entry.path);
    } catch (e) {
      _showSnack('无法读取文件：$e');
      return;
    }
    if (!mounted) return;
    final dialogContext = AppNavigationService.context ?? context;
    final controller = TextEditingController(text: content);
    final saved = await showDialog<bool>(
      context: dialogContext,
      builder: (context) {
        return AlertDialog(
          title: Text(entry.name),
          content: SizedBox(
            width: 640,
            height: 420,
            child: TextField(
              controller: controller,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontFamily: 'DejaVuSansMono'),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    if (saved != true) return;
    try {
      await _service.writeTextFile(entry.path, controller.text);
      await _refreshSelectedPane();
      _showSnack('已保存');
    } catch (e) {
      _showSnack('保存失败：$e');
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
    });
  }

  void _clearSelectionIfPane(_FilePaneState pane) {
    if (_selection?.pane == pane) {
      _selection = null;
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
    final screen = MediaQuery.sizeOf(context);
    final width = _clampWindowWidth(screen, _windowSize.width);
    final height = _clampWindowHeight(screen, _windowSize.height);
    final maxLeft = screen.width - width - 8;
    final maxTop = screen.height - height - 8;
    final leftUpper = maxLeft < 8 ? 8.0 : maxLeft;
    final topUpper = maxTop < 8 ? 8.0 : maxTop;
    final left = _offset.dx.clamp(8.0, leftUpper).toDouble();
    final top = _offset.dy.clamp(8.0, topUpper).toDouble();

    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
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
                      Expanded(child: _buildBody()),
                      _buildSelectionBar(),
                    ],
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: _buildResizeHandle(screen),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBar() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) {
        setState(() {
          _offset += details.delta;
        });
      },
      child: Container(
        height: 44,
        color: Colors.black,
        padding: const EdgeInsets.only(left: 12, right: 4),
        child: Row(
          children: [
            const Icon(Icons.folder_copy_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '文件管理',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: '刷新',
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _refreshAll,
            ),
            IconButton(
              tooltip: '关闭',
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: FileManagerOverlayController.hide,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }

    final narrow = _windowSize.width < 560;
    if (narrow) {
      return DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const Material(
              color: Colors.black,
              child: TabBar(
                tabs: [
                  Tab(text: '智能体'),
                  Tab(text: '目录'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPane(_left),
                  _buildPane(_right),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(child: _buildPane(_left)),
        VerticalDivider(width: 1, color: Theme.of(context).colorScheme.outline),
        Expanded(child: _buildPane(_right)),
      ],
    );
  }

  Widget _buildPane(_FilePaneState pane) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.black,
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: '返回上级',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _goUp(pane),
                    icon: const Icon(Icons.arrow_upward, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: '回到根目录',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _goHome(pane),
                    icon: const Icon(Icons.home_outlined, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      pane.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: '新建',
                    icon: const Icon(Icons.add, color: Colors.white),
                    onSelected: (value) {
                      if (value == 'folder') {
                        _create(pane, directory: true);
                      } else if (value == 'file') {
                        _create(pane, directory: false);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'folder', child: Text('新建文件夹')),
                      PopupMenuItem(value: 'file', child: Text('新建文件')),
                    ],
                  ),
                ],
              ),
              Text(
                pane.currentPath == FileManagerService.agentToolsPath
                    ? '智能体工具目录'
                    : pane.currentPath,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
              if (pane == _right)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('私有'),
                        selected: !_rightExternalMode,
                        onSelected: (_) => _switchRightMode(external: false),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('外部'),
                        selected: _rightExternalMode,
                        onSelected: (_) => _switchRightMode(external: true),
                      ),
                      const Spacer(),
                      if (!_externalPermission)
                        TextButton.icon(
                          onPressed: _requestStoragePermission,
                          icon: const Icon(Icons.security, size: 16),
                          label: const Text('授权'),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
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
    final entryType = entry.isDirectory ? '文件夹' : FileManagerService.formatSize(entry.size);
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
    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: _accentColor.withAlpha(36),
      leading: Icon(
        entry.isDirectory ? Icons.folder_outlined : Icons.description_outlined,
        color: !entry.canRead
            ? theme.disabledColor
            : entry.isDirectory
                ? _folderColor
                : theme.iconTheme.color,
      ),
      title: Text(
        entry.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: entry.isHidden
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _openEntry(pane, entry),
      onLongPress: () => _select(pane, entry),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          _select(pane, entry);
          switch (value) {
            case 'open':
              _openEntry(pane, entry);
              break;
            case 'rename':
              _renameSelected();
              break;
            case 'copy':
              _copyOrMoveSelected(move: false);
              break;
            case 'move':
              _copyOrMoveSelected(move: true);
              break;
            case 'delete':
              _deleteSelected();
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'open', child: Text('打开')),
          const PopupMenuItem(value: 'rename', child: Text('重命名')),
          const PopupMenuItem(value: 'copy', child: Text('复制到另一列')),
          const PopupMenuItem(value: 'move', child: Text('移动到另一列')),
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
      ),
    );
  }

  Widget _buildSelectionBar() {
    final selected = _selection;
    return Container(
      height: 48,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              selected == null ? '未选择文件' : selected.entry.name,
              style: const TextStyle(color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: '复制到另一列',
            onPressed:
                selected == null ? null : () => _copyOrMoveSelected(move: false),
            icon: const Icon(Icons.copy),
            color: Colors.white,
            disabledColor: Colors.white38,
          ),
          IconButton(
            tooltip: '移动到另一列',
            onPressed:
                selected == null ? null : () => _copyOrMoveSelected(move: true),
            icon: const Icon(Icons.drive_file_move_outline),
            color: Colors.white,
            disabledColor: Colors.white38,
          ),
          IconButton(
            tooltip: '重命名',
            onPressed: selected == null ? null : _renameSelected,
            icon: const Icon(Icons.edit_outlined),
            color: Colors.white,
            disabledColor: Colors.white38,
          ),
          IconButton(
            tooltip: '删除',
            onPressed: selected == null ? null : _deleteSelected,
            icon: const Icon(Icons.delete_outline),
            color: Colors.white,
            disabledColor: Colors.white38,
          ),
        ],
      ),
    );
  }

  Widget _buildResizeHandle(Size screen) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) {
        setState(() {
          final nextWidth = _clampWindowWidth(
            screen,
            _windowSize.width + details.delta.dx,
          );
          final nextHeight = _clampWindowHeight(
            screen,
            _windowSize.height + details.delta.dy,
          );
          _windowSize = Size(nextWidth, nextHeight);
        });
      },
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.bottomRight,
        padding: const EdgeInsets.all(4),
        child: const Icon(
          Icons.open_in_full,
          size: 16,
          color: Colors.white70,
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
    final maxWidth = screen.width > 336 ? screen.width - 16 : screen.width;
    final minWidth = maxWidth < 320 ? maxWidth : 320.0;
    return value.clamp(minWidth, maxWidth).toDouble();
  }

  double _clampWindowHeight(Size screen, double value) {
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
