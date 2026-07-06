import 'package:flutter/material.dart';

import '../services/terminal_input_controller.dart';
import '../services/terminal_service.dart';
import '../widgets/native_terminal_view.dart';
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
  var _terminalKey = GlobalKey<NativeTerminalViewState>();
  late final TerminalInputController _terminalInput;
  late Future<_NativeTerminalConfig> _configFuture;
  late final List<_TerminalSessionTab> _sessions;
  var _activeIndex = 0;
  var _restartOnCreate = false;

  _TerminalSessionTab get _activeSession => _sessions[_activeIndex];

  @override
  void initState() {
    super.initState();
    _sessions = [
      _TerminalSessionTab(id: widget.sessionId, title: widget.title),
    ];
    _restartOnCreate = widget.restartOnOpen;
    _terminalInput = TerminalInputController(
      onWrite: (bytes) {
        _terminalKey.currentState?.writeBytes(bytes);
      },
    );
    _configFuture = _loadConfig();
  }

  Future<_NativeTerminalConfig> _loadConfig() async {
    final config = await TerminalService.getProotShellConfig();
    var args = TerminalService.buildProotArgs(config);
    final command = widget.initialCommand;
    if (command != null && command.trim().isNotEmpty) {
      args = TerminalService.replaceLoginShell(args, command);
    }
    return _NativeTerminalConfig(
      executable: config['executable']!,
      arguments: args,
      environment: TerminalService.buildHostEnv(config),
    );
  }

  @override
  void dispose() {
    _terminalInput.dispose();
    super.dispose();
  }

  void _restart() {
    setState(() {
      _restartOnCreate = true;
      _terminalKey = GlobalKey<NativeTerminalViewState>();
      _configFuture = _loadConfig();
    });
  }

  void _newSession() {
    final nextNumber = _sessions.length + 1;
    final nextSession = _TerminalSessionTab(
      id: '${widget.sessionId}-${DateTime.now().millisecondsSinceEpoch}',
      title: '${widget.title} $nextNumber',
    );
    setState(() {
      _sessions.add(nextSession);
      _activeIndex = _sessions.length - 1;
      _restartOnCreate = false;
      _terminalKey = GlobalKey<NativeTerminalViewState>();
      _configFuture = _loadConfig();
    });
  }

  void _switchSession(int index) {
    if (index == _activeIndex || index < 0 || index >= _sessions.length) {
      return;
    }
    setState(() {
      _activeIndex = index;
      _restartOnCreate = false;
      _terminalKey = GlobalKey<NativeTerminalViewState>();
      _configFuture = _loadConfig();
    });
  }

  Future<void> _paste() async {
    await _terminalKey.currentState?.paste();
  }

  Future<void> _closeSession() async {
    await _terminalKey.currentState?.close();
    if (!context.mounted) {
      return;
    }
    if (_sessions.length <= 1) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _sessions.removeAt(_activeIndex);
      if (_activeIndex >= _sessions.length) {
        _activeIndex = _sessions.length - 1;
      }
      _restartOnCreate = false;
      _terminalKey = GlobalKey<NativeTerminalViewState>();
      _configFuture = _loadConfig();
    });
  }

  @override
  Widget build(BuildContext context) {
    final compactActions = MediaQuery.sizeOf(context).width < 380;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.black,
        title: _buildTitle(),
        actions:
            compactActions ? [_buildOverflowMenu()] : _buildToolbarActions(),
      ),
      body: FutureBuilder<_NativeTerminalConfig>(
        future: _configFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return ColoredBox(
              color: Colors.black,
              child: ResponsiveLayout.scrollableCenter(
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Starting native terminal...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            );
          }

          final error = snapshot.error;
          if (error != null || !snapshot.hasData) {
            return ColoredBox(
              color: Colors.black,
              child: ResponsiveLayout.scrollableCenter(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      error?.toString() ?? 'Failed to start terminal',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _restart,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final config = snapshot.data!;
          return _buildTerminal(config);
        },
      ),
    );
  }

  List<Widget> _buildToolbarActions() {
    return [
      IconButton(
        icon: const Icon(Icons.add),
        tooltip: 'New session',
        onPressed: _newSession,
      ),
      _buildSessionMenu(),
      IconButton(
        icon: const Icon(Icons.paste),
        tooltip: 'Paste',
        onPressed: _paste,
      ),
      IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: 'Restart',
        onPressed: _restart,
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
        if (value.startsWith('session:')) {
          _switchSession(int.parse(value.substring('session:'.length)));
          return;
        }
        switch (value) {
          case 'new':
            _newSession();
            break;
          case 'paste':
            _paste();
            break;
          case 'restart':
            _restart();
            break;
          case 'close':
            _closeSession();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'new', child: Text('New session')),
        const PopupMenuDivider(),
        for (var i = 0; i < _sessions.length; i++)
          PopupMenuItem(
            value: 'session:$i',
            child: Row(
              children: [
                Icon(
                  i == _activeIndex
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(_sessions[i].title)),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'paste', child: Text('Paste')),
        const PopupMenuItem(value: 'restart', child: Text('Restart')),
        const PopupMenuItem(value: 'close', child: Text('Close session')),
      ],
    );
  }

  Widget _buildSessionMenu() {
    return PopupMenuButton<int>(
      tooltip: 'Sessions',
      icon: const Icon(Icons.tab),
      onSelected: _switchSession,
      itemBuilder: (context) => [
        for (var i = 0; i < _sessions.length; i++)
          PopupMenuItem(
            value: i,
            child: Row(
              children: [
                Icon(
                  i == _activeIndex
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(_sessions[i].title)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _activeSession.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (_sessions.length > 1)
          Text(
            '${_activeIndex + 1}/${_sessions.length}',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
      ],
    );
  }

  Widget _buildTerminal(_NativeTerminalConfig config) {
    return Column(
      children: [
        Expanded(
          child: NativeTerminalView(
            key: _terminalKey,
            sessionId: _activeSession.id,
            executable: config.executable,
            arguments: config.arguments,
            environment: config.environment,
            restart: _restartOnCreate,
            keepAlive: true,
            fontSize: 18,
          ),
        ),
        TerminalToolbar(
          onWrite: _terminalInput.writeBytes,
          ctrlNotifier: _terminalInput.ctrlNotifier,
          altNotifier: _terminalInput.altNotifier,
        ),
      ],
    );
  }
}

class _NativeTerminalConfig {
  final String executable;
  final List<String> arguments;
  final Map<String, String> environment;

  const _NativeTerminalConfig({
    required this.executable,
    required this.arguments,
    required this.environment,
  });
}

class _TerminalSessionTab {
  final String id;
  final String title;

  const _TerminalSessionTab({
    required this.id,
    required this.title,
  });
}
