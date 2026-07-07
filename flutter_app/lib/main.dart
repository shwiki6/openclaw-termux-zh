import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app.dart';
import 'l10n/app_localizations.dart';
import 'widgets/floating_file_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OpenClawApp());
}

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  runApp(const FileManagerSystemOverlayApp());
}

class FileManagerSystemOverlayApp extends StatelessWidget {
  const FileManagerSystemOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFDC2626),
          onPrimary: Colors.white,
          surface: Color(0xFF121212),
          onSurface: Colors.white,
          onSurfaceVariant: Color(0xFF9CA3AF),
          outline: Color(0xFF2A2A2A),
          error: Color(0xFFEF4444),
          onError: Colors.white,
        ),
      ),
      home: const Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            FloatingFileManagerWindow(systemOverlay: true),
          ],
        ),
      ),
    );
  }
}
