import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/provider_config_service.dart';
import '../services/terminal_input_controller.dart';
import '../services/terminal_service.dart';
import '../widgets/native_proot_terminal.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/terminal_toolbar.dart';

class ConfigureScreen extends StatefulWidget {
  const ConfigureScreen({super.key});

  @override
  State<ConfigureScreen> createState() => _ConfigureScreenState();
}

class _ConfigureScreenState extends State<ConfigureScreen> {
  final _terminalKey = GlobalKey<NativeProotTerminalState>();
  late final TerminalInputController _terminalInput;
  Future<String>? _commandFuture;
  bool _finished = false;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _terminalInput = TerminalInputController(
      onWrite: (bytes) {
        _terminalKey.currentState?.writeBytes(bytes);
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _commandFuture ??= _buildConfigureCommand();
  }

  @override
  void dispose() {
    _terminalInput.dispose();
    super.dispose();
  }

  String _shellQuote(String value) {
    return "'${value.replaceAll("'", r"'\''")}'";
  }

  String _buildPrintLinesCommand(Iterable<String> lines) {
    return lines
        .map((line) => "printf '%s\\n' ${_shellQuote(line)}")
        .join('; ');
  }

  Future<String> _buildConfigureCommand() async {
    final l10n = context.l10n;
    final bonjourEnabled = await ProviderConfigService.readBonjourEnabled();
    final commandParts = <String>[
      if (!bonjourEnabled) 'export OPENCLAW_DISABLE_BONJOUR=1',
      _buildPrintLinesCommand([
        l10n.t('configureTerminalHeading'),
        l10n.t('configureTerminalIntro'),
        l10n.t('configureTerminalAndroidOptimization'),
        l10n.t('configureTerminalAdvancedHint'),
        '',
      ]),
      'openclaw configure',
      _buildPrintLinesCommand([
        '',
        l10n.t('configureTerminalDone'),
      ]),
    ];
    return commandParts.join('; ');
  }

  void _restart() {
    setState(() {
      _finished = false;
      _generation++;
      _commandFuture = _buildConfigureCommand();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.black,
        title: Text(l10n.t('configureTitle')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.paste),
            tooltip: l10n.t('commonPaste'),
            onPressed: () => _terminalKey.currentState?.paste(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.t('commonRetry'),
            onPressed: _restart,
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _commandFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return ColoredBox(
              color: Colors.black,
              child: ResponsiveLayout.scrollableCenter(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      l10n.t('configureStarting'),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
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
                      l10n.t('configureStartFailed', {
                        'error': '${snapshot.error ?? 'unknown'}',
                      }),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _restart,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.t('commonRetry')),
                    ),
                  ],
                ),
              ),
            );
          }

          return _buildTerminal(snapshot.data!, l10n);
        },
      ),
    );
  }

  Widget _buildTerminal(String command, AppLocalizations l10n) {
    return Column(
      children: [
        Expanded(
          child: NativeProotTerminal(
            key: ValueKey('configure-$_generation'),
            sessionId: 'configure-$_generation',
            command: command,
            mode: TerminalProotMode.compatibility,
            onSessionFinished: (_) {
              if (mounted) {
                setState(() => _finished = true);
              }
            },
          ),
        ),
        TerminalToolbar(
          onWrite: _terminalInput.writeBytes,
          ctrlNotifier: _terminalInput.ctrlNotifier,
          altNotifier: _terminalInput.altNotifier,
        ),
        if (_finished)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.check),
                label: Text(l10n.t('commonDone')),
              ),
            ),
          ),
      ],
    );
  }
}
