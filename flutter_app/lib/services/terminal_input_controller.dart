import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

class TerminalInputController {
  TerminalInputController({required this.onWrite});

  final ValueChanged<Uint8List> onWrite;
  final ctrlNotifier = ValueNotifier<bool>(false);
  final altNotifier = ValueNotifier<bool>(false);

  void handleInput(String data) {
    if (ctrlNotifier.value && data.length == 1) {
      final code = data.toLowerCase().codeUnitAt(0);
      if (code >= 97 && code <= 122) {
        writeBytes([code - 96]);
        ctrlNotifier.value = false;
        return;
      }
    }

    if (altNotifier.value && data.isNotEmpty) {
      writeText('\x1b$data');
      altNotifier.value = false;
      return;
    }

    writeText(data);
  }

  void writeText(String data) {
    onWrite(Uint8List.fromList(utf8.encode(data)));
  }

  void writeBytes(List<int> bytes) {
    onWrite(Uint8List.fromList(bytes));
  }

  void dispose() {
    ctrlNotifier.dispose();
    altNotifier.dispose();
  }
}
