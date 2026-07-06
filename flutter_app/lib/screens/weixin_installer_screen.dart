import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/message_platform_config_service.dart';
import '../services/terminal_input_controller.dart';
import '../widgets/native_proot_terminal.dart';
import '../widgets/terminal_toolbar.dart';

class WeixinInstallerScreen extends StatefulWidget {
  const WeixinInstallerScreen({super.key});

  @override
  State<WeixinInstallerScreen> createState() => _WeixinInstallerScreenState();
}

class _WeixinInstallerScreenState extends State<WeixinInstallerScreen> {
  final _terminalKey = GlobalKey<NativeProotTerminalState>();
  late final TerminalInputController _terminalInput;
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
  void dispose() {
    _terminalInput.dispose();
    super.dispose();
  }

  String get _command => 'echo "=== OpenClaw Weixin Installer ===" && '
      'echo "The installer may show a QR code or a login link." && '
      'echo "Use the native terminal selection handles to copy links." && '
      'echo "" && '
      '${MessagePlatformConfigService.weixinInstallerCommand}; '
      'echo "" && echo "Weixin installer finished. You can return now."';

  void _restart() {
    setState(() {
      _finished = false;
      _generation++;
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
        title: Text(l10n.t('messagePlatformDetailWeixinTerminalTitle')),
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
      body: Column(
        children: [
          Expanded(
            child: NativeProotTerminal(
              key: ValueKey('weixin-installer-$_generation'),
              sessionId: 'weixin-installer-$_generation',
              command: _command,
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
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.check),
                  label: Text(l10n.t('commonDone')),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
