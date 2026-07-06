import 'package:flutter/material.dart';

import '../services/terminal_service.dart';
import 'native_terminal_view.dart';
import 'responsive_layout.dart';

class NativeProotTerminal extends StatefulWidget {
  final String sessionId;
  final String? command;
  final TerminalProotMode mode;
  final bool keepAlive;
  final bool restart;
  final int fontSize;
  final bool emitOutput;
  final ValueChanged<String>? onOutput;
  final ValueChanged<int>? onSessionFinished;
  final void Function(NativeTerminalViewState state)? onTerminalReady;

  const NativeProotTerminal({
    super.key,
    required this.sessionId,
    this.command,
    this.mode = TerminalProotMode.fast,
    this.keepAlive = false,
    this.restart = false,
    this.fontSize = 14,
    this.emitOutput = false,
    this.onOutput,
    this.onSessionFinished,
    this.onTerminalReady,
  });

  @override
  State<NativeProotTerminal> createState() => NativeProotTerminalState();
}

class NativeProotTerminalState extends State<NativeProotTerminal> {
  final _terminalKey = GlobalKey<NativeTerminalViewState>();
  late Future<_NativeProotConfig> _configFuture;

  @override
  void initState() {
    super.initState();
    _configFuture = _loadConfig();
  }

  @override
  void didUpdateWidget(covariant NativeProotTerminal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.command != widget.command ||
        oldWidget.mode != widget.mode ||
        oldWidget.restart != widget.restart) {
      _configFuture = _loadConfig();
    }
  }

  Future<void> writeBytes(List<int> bytes) async {
    await _terminalKey.currentState?.writeBytes(bytes);
  }

  Future<void> writeText(String text) async {
    await _terminalKey.currentState?.writeText(text);
  }

  Future<void> paste() async {
    await _terminalKey.currentState?.paste();
  }

  Future<void> close() async {
    await _terminalKey.currentState?.close();
  }

  Future<_NativeProotConfig> _loadConfig() async {
    final config = await TerminalService.getProotShellConfig();
    var args = TerminalService.buildProotArgs(config, mode: widget.mode);
    final command = widget.command;
    if (command != null && command.trim().isNotEmpty) {
      args = TerminalService.replaceLoginShell(args, command);
    }
    return _NativeProotConfig(
      executable: config['executable']!,
      arguments: args,
      environment: TerminalService.buildHostEnv(config),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_NativeProotConfig>(
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
            child: Text(
              error?.toString() ?? 'Failed to start terminal',
              textAlign: TextAlign.center,
            ),
          );
        }

        final config = snapshot.data!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final state = _terminalKey.currentState;
          if (state != null) {
            widget.onTerminalReady?.call(state);
          }
        });
        return NativeTerminalView(
          key: _terminalKey,
          sessionId: widget.sessionId,
          executable: config.executable,
          arguments: config.arguments,
          environment: config.environment,
          restart: widget.restart,
          keepAlive: widget.keepAlive,
          emitOutput: widget.emitOutput,
          fontSize: widget.fontSize,
          onOutput: widget.onOutput,
          onSessionFinished: widget.onSessionFinished,
        );
      },
    );
  }

}

class _NativeProotConfig {
  final String executable;
  final List<String> arguments;
  final Map<String, String> environment;

  const _NativeProotConfig({
    required this.executable,
    required this.arguments,
    required this.environment,
  });
}
