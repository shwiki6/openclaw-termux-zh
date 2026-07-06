import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NativeTerminalView extends StatefulWidget {
  final String sessionId;
  final String executable;
  final String cwd;
  final List<String> arguments;
  final Map<String, String> environment;
  final bool restart;
  final bool keepAlive;
  final bool emitOutput;
  final int fontSize;
  final ValueChanged<String>? onOutput;
  final ValueChanged<int>? onSessionFinished;
  final ValueChanged<String>? onTitleChanged;

  const NativeTerminalView({
    super.key,
    required this.sessionId,
    required this.executable,
    required this.arguments,
    required this.environment,
    this.cwd = '/',
    this.restart = false,
    this.keepAlive = false,
    this.emitOutput = false,
    this.fontSize = 18,
    this.onOutput,
    this.onSessionFinished,
    this.onTitleChanged,
  });

  @override
  State<NativeTerminalView> createState() => NativeTerminalViewState();
}

class NativeTerminalViewState extends State<NativeTerminalView> {
  MethodChannel? _channel;

  Future<void> writeBytes(List<int> bytes) async {
    await _channel?.invokeMethod('writeBytes', Uint8List.fromList(bytes));
  }

  Future<void> writeText(String text) async {
    await _channel?.invokeMethod('writeText', {'text': text});
  }

  Future<void> paste() async {
    await _channel?.invokeMethod('paste');
  }

  Future<void> showKeyboard() async {
    await _channel?.invokeMethod('showKeyboard');
  }

  Future<void> hideKeyboard() async {
    await _channel?.invokeMethod('hideKeyboard');
  }

  Future<void> setFontSize(int fontSize) async {
    await _channel?.invokeMethod('setFontSize', {'fontSize': fontSize});
  }

  Future<void> restart() async {
    await _channel?.invokeMethod('restart');
  }

  Future<void> close() async {
    await _channel?.invokeMethod('close');
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'Native terminal is only available on Android',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final androidView = AndroidView(
      viewType: 'openclaw/native_terminal',
      creationParamsCodec: const StandardMessageCodec(),
      creationParams: {
        'sessionId': widget.sessionId,
        'executable': widget.executable,
        'cwd': widget.cwd,
        'arguments': widget.arguments,
        'environment': widget.environment,
        'restart': widget.restart,
        'keepAlive': widget.keepAlive,
        'emitOutput': widget.emitOutput,
        'fontSize': widget.fontSize,
        'transcriptRows': 3000,
      },
      onPlatformViewCreated: (id) {
        final channel = MethodChannel('com.openclaw.cyx/native_terminal_$id');
        channel.setMethodCallHandler(_handleMethodCall);
        _channel = channel;
        unawaited(showKeyboard());
      },
    );

    return ColoredBox(
      color: Colors.black,
      child: SizedBox.expand(child: androidView),
    );
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onSessionFinished':
        final exitStatus = (call.arguments as num?)?.toInt() ?? 0;
        widget.onSessionFinished?.call(exitStatus);
        return null;
      case 'onTitleChanged':
        widget.onTitleChanged?.call(call.arguments?.toString() ?? '');
        return null;
      case 'onOutput':
        widget.onOutput?.call(call.arguments?.toString() ?? '');
        return null;
    }
  }
}
