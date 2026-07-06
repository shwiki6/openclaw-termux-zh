import 'package:flutter/material.dart';

import '../models/optional_package.dart';
import '../services/terminal_input_controller.dart';
import '../widgets/native_proot_terminal.dart';
import '../widgets/terminal_toolbar.dart';

class PackageInstallScreen extends StatefulWidget {
  final OptionalPackage package;
  final bool isUninstall;

  const PackageInstallScreen({
    super.key,
    required this.package,
    this.isUninstall = false,
  });

  @override
  State<PackageInstallScreen> createState() => _PackageInstallScreenState();
}

class _PackageInstallScreenState extends State<PackageInstallScreen> {
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

  String get _command =>
      widget.isUninstall ? widget.package.uninstallCommand : widget.package.installCommand;

  String get _sentinel => widget.isUninstall
      ? widget.package.uninstallSentinel
      : widget.package.completionSentinel;

  void _restart() {
    setState(() {
      _finished = false;
      _generation++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.isUninstall ? 'Uninstall' : 'Install';

    return Scaffold(
      appBar: AppBar(
        title: Text('$action ${widget.package.name}'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.paste),
            tooltip: 'Paste',
            onPressed: () => _terminalKey.currentState?.paste(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Restart',
            onPressed: _restart,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: NativeProotTerminal(
              key: ValueKey('package-${widget.package.id}-$_generation'),
              sessionId: 'package-${widget.package.id}-$_generation',
              command: _command,
              emitOutput: true,
              onOutput: (text) {
                if (!_finished && text.contains(_sentinel) && mounted) {
                  setState(() => _finished = true);
                }
              },
              onSessionFinished: (_) {
                if (mounted && !_finished) {
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
                  label: const Text('Done'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
