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
  var _restartOnCreate = false;

  @override
  void initState() {
    super.initState();
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

  Future<void> _paste() async {
    await _terminalKey.currentState?.paste();
  }

  Future<void> _closeSession() async {
    await _terminalKey.currentState?.close();
    if (context.mounted) {
      Navigator.of(context).pop(true);
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
      body: FutureBuilder<_NativeTerminalConfig>(
        future: _configFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return ResponsiveLayout.scrollableCenter(
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Starting native terminal...'),
                ],
              ),
            );
          }

          final error = snapshot.error;
          if (error != null || !snapshot.hasData) {
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
                    error?.toString() ?? 'Failed to start terminal',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _restart,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
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
        switch (value) {
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
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'paste', child: Text('Paste')),
        PopupMenuItem(value: 'restart', child: Text('Restart')),
        PopupMenuItem(value: 'close', child: Text('Close session')),
      ],
    );
  }

  Widget _buildTerminal(_NativeTerminalConfig config) {
    return Column(
      children: [
        Expanded(
          child: NativeTerminalView(
            key: _terminalKey,
            sessionId: widget.sessionId,
            executable: config.executable,
            arguments: config.arguments,
            environment: config.environment,
            restart: _restartOnCreate,
            keepAlive: true,
            fontSize: 14,
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
