import 'package:flutter/material.dart';

import '../constants.dart';
import '../l10n/app_localizations.dart';
import '../services/dashboard_url_resolver.dart';
import '../services/preferences_service.dart';
import '../services/provider_config_service.dart';
import '../services/terminal_input_controller.dart';
import '../widgets/native_proot_terminal.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/terminal_toolbar.dart';
import 'dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final bool isFirstRun;

  const OnboardingScreen({
    super.key,
    this.isFirstRun = false,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _terminalKey = GlobalKey<NativeProotTerminalState>();
  late final TerminalInputController _terminalInput;
  Future<String>? _commandFuture;
  bool _finished = false;
  var _generation = 0;
  String _urlScanBuffer = '';

  static final _ansiEscape = AppConstants.ansiEscape;
  static final _boxDrawing = RegExp(r'[│┤├┬┴┼╮╯╰╭─╌╴╶┌┐└┘◇◆]+');
  static final _completionPattern = RegExp(
    r'onboard(ing)?\s+(is\s+)?complete|successfully\s+onboarded|setup\s+complete',
    caseSensitive: false,
  );

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
    _commandFuture ??= _buildOnboardingCommand();
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

  Future<String> _buildOnboardingCommand() async {
    final l10n = context.l10n;
    final bonjourEnabled = await ProviderConfigService.readBonjourEnabled();
    final commandParts = <String>[
      if (!bonjourEnabled) 'export OPENCLAW_DISABLE_BONJOUR=1',
      _buildPrintLinesCommand([
        l10n.t('onboardingTerminalHeading'),
        l10n.t('onboardingTerminalIntro'),
        l10n.t('onboardingTerminalLoopbackTip'),
        l10n.t('onboardingTerminalAndroidOptimization'),
        l10n.t('onboardingTerminalAdvancedHint'),
        '',
      ]),
      'openclaw onboard',
      _buildPrintLinesCommand([
        '',
        l10n.t('onboardingTerminalDone'),
      ]),
    ];
    return commandParts.join('; ');
  }

  void _handleOutput(String text) {
    _urlScanBuffer += text;
    if (_urlScanBuffer.length > 4096) {
      _urlScanBuffer = _urlScanBuffer.substring(_urlScanBuffer.length - 2048);
    }

    final cleanText = _urlScanBuffer.replaceAll(_ansiEscape, '');
    final cleanForUrl = cleanText.replaceAll(_boxDrawing, '');
    final dashboardUrl = DashboardUrlResolver.extractDashboardUrlFromText(
      cleanForUrl,
      baseUri: Uri.parse(AppConstants.gatewayUrl),
    );
    if (dashboardUrl != null) {
      _saveTokenUrl(dashboardUrl);
    }

    if (!_finished && _completionPattern.hasMatch(cleanText) && mounted) {
      setState(() => _finished = true);
    }
  }

  Future<void> _saveTokenUrl(String url) async {
    final prefs = PreferencesService();
    await prefs.init();
    prefs.dashboardUrl = url;
  }

  void _restart() {
    setState(() {
      _finished = false;
      _urlScanBuffer = '';
      _generation++;
      _commandFuture = _buildOnboardingCommand();
    });
  }

  Future<void> _goToDashboard() async {
    final navigator = Navigator.of(context);
    final prefs = PreferencesService();
    await prefs.init();
    prefs.pendingSetupCompletionChoice = false;
    prefs.setupComplete = true;
    prefs.isFirstRun = false;

    if (mounted) {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
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
        title: Text(l10n.t('onboardingTitle')),
        leading: widget.isFirstRun
            ? null
            : IconButton(
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
                      l10n.t('onboardingStarting'),
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
                      l10n.t('onboardingStartFailed', {
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
            key: ValueKey('onboarding-$_generation'),
            sessionId: 'onboarding-$_generation',
            command: command,
            emitOutput: true,
            onOutput: _handleOutput,
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
                onPressed: widget.isFirstRun
                    ? _goToDashboard
                    : () => Navigator.of(context).pop(),
                icon: Icon(widget.isFirstRun ? Icons.arrow_forward : Icons.check),
                label: Text(widget.isFirstRun
                    ? l10n.t('onboardingGoToDashboard')
                    : l10n.t('commonDone')),
              ),
            ),
          ),
      ],
    );
  }
}
