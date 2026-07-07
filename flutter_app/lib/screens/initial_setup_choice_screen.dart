import 'package:flutter/material.dart';

import '../constants.dart';
import '../l10n/app_localizations.dart';
import '../services/preferences_service.dart';
import 'setup_wizard_screen.dart';

class InitialSetupChoiceScreen extends StatelessWidget {
  const InitialSetupChoiceScreen({super.key});

  Future<void> _install(
    BuildContext context, {
    required bool installOpenClaw,
  }) async {
    final prefs = PreferencesService();
    await prefs.init();
    prefs.openClawInstallDeferred = !installOpenClaw;
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SetupWizardScreen(
          installOpenClawByDefault: installOpenClaw,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l10n.t('initialSetupChoiceTitle')),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/ic_launcher.png',
                    width: 72,
                    height: 72,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppConstants.appName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.t('initialSetupChoiceBody'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () => _install(
                      context,
                      installOpenClaw: true,
                    ),
                    icon: const Icon(Icons.download_for_offline_outlined),
                    label: Text(l10n.t('initialSetupChoiceInstall')),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _install(
                      context,
                      installOpenClaw: false,
                    ),
                    icon: const Icon(Icons.layers_outlined),
                    label: Text(l10n.t('initialSetupChoiceSkip')),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.t('initialSetupChoiceSkipHint'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
