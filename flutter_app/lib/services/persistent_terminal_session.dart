import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';

import 'native_bridge.dart';
import 'terminal_output_buffer.dart';
import 'terminal_service.dart';

class PersistentTerminalSession extends ChangeNotifier {
  PersistentTerminalSession({
    required this.id,
    required this.title,
    this.initialCommand,
  }) : terminal = Terminal(maxLines: terminalScrollbackLines) {
    _outputBuffer = TerminalOutputBuffer(terminal);
    terminal.onOutput = writeInput;
  }

  final String id;
  final String title;
  final String? initialCommand;
  final Terminal terminal;
  late final TerminalOutputBuffer _outputBuffer;

  Pty? _pty;
  int _generation = 0;
  bool loading = false;
  bool closed = false;
  String? error;
  int? exitCode;

  bool get isRunning => _pty != null && exitCode == null && !closed;
  Pty? get pty => _pty;

  Future<void> start({
    int columns = 80,
    int rows = 24,
    bool restart = false,
  }) async {
    if (loading) return;
    if (isRunning && !restart) {
      resize(columns, rows);
      return;
    }

    if (restart) {
      _generation++;
      _pty?.kill();
      _pty = null;
      exitCode = null;
    }

    final generation = ++_generation;
    _outputBuffer.flush();
    loading = true;
    closed = false;
    error = null;
    exitCode = null;
    notifyListeners();

    try {
      await NativeBridge.startTerminalService();
      final config = await TerminalService.getProotShellConfig();
      final args = TerminalService.buildProotArgs(
        config,
        columns: columns,
        rows: rows,
        mode: TerminalProotMode.compatibility,
      );
      if (generation != _generation || closed) {
        loading = false;
        await PersistentTerminalSessions.stopServiceIfIdle();
        return;
      }
      final command = initialCommand?.trim();
      final finalArgs = command == null || command.isEmpty
          ? args
          : TerminalService.replaceLoginShell(args, command);

      _pty = Pty.start(
        config['executable']!,
        arguments: finalArgs,
        environment: TerminalService.buildHostEnv(config),
        columns: columns,
        rows: rows,
      );
      final pty = _pty!;

      pty.output.cast<List<int>>().listen((data) {
        if (generation != _generation || closed) return;
        final text = utf8.decode(data, allowMalformed: true);
        _outputBuffer.write(text);
      });

      pty.exitCode.then((code) {
        if (generation != _generation || closed) return;
        exitCode = code;
        _pty = null;
        _outputBuffer.write('\r\n[Process exited with code $code]\r\n');
        _outputBuffer.flush();
        notifyListeners();
        PersistentTerminalSessions.stopServiceIfIdle();
      });

      loading = false;
      notifyListeners();
    } catch (e) {
      if (generation != _generation || closed) return;
      loading = false;
      error = 'Failed to start terminal: $e';
      notifyListeners();
      PersistentTerminalSessions.stopServiceIfIdle();
    }
  }

  void writeInput(String data) {
    _pty?.write(utf8.encode(data));
  }

  void writeBytes(List<int> bytes) {
    _pty?.write(Uint8List.fromList(bytes));
  }

  void resize(int columns, int rows) {
    _pty?.resize(rows, columns);
  }

  Future<void> close() async {
    _generation++;
    closed = true;
    _pty?.kill();
    _pty = null;
    _outputBuffer.dispose();
    notifyListeners();
    await PersistentTerminalSessions.remove(id);
  }
}

class PersistentTerminalSessions {
  static final Map<String, PersistentTerminalSession> _sessions = {};

  static PersistentTerminalSession getOrCreate({
    required String id,
    required String title,
    String? initialCommand,
  }) {
    return _sessions.putIfAbsent(
      id,
      () => PersistentTerminalSession(
        id: id,
        title: title,
        initialCommand: initialCommand,
      ),
    );
  }

  static Future<void> remove(String id) async {
    _sessions.remove(id);
    await stopServiceIfIdle();
  }

  static Future<void> stopServiceIfIdle() async {
    if (_sessions.values.any((session) => session.isRunning)) {
      return;
    }
    try {
      await NativeBridge.stopTerminalService();
    } catch (_) {}
  }
}
