import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class FileManagerEntry {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime modified;
  final bool isHidden;
  final bool canRead;
  final bool canWrite;

  const FileManagerEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.modified,
    required this.isHidden,
    required this.canRead,
    required this.canWrite,
  });
}

class FileManagerService {
  static const agentToolsPath = 'openclaw://agent-tools';
  static const _textReadLimitBytes = 1024 * 1024;
  static const _binaryPreviewBytes = 768;

  Future<String> getPrivateRoot() async {
    final directory = await getApplicationSupportDirectory();
    return directory.path;
  }

  Future<String> getExternalRoot() async {
    final primary = Directory('/storage/emulated/0');
    if (await primary.exists()) {
      return primary.path;
    }
    return '/sdcard';
  }

  Future<bool> hasExternalPermission() async {
    if (!Platform.isAndroid) {
      return true;
    }
    return Permission.manageExternalStorage.isGranted;
  }

  Future<bool> requestExternalPermission() async {
    if (!Platform.isAndroid) {
      return true;
    }
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }
    final status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }

  Future<List<FileManagerEntry>> listDirectory(String path) async {
    if (path == agentToolsPath) {
      return _listAgentToolFolders();
    }

    final directory = Directory(path);
    final entries = <FileManagerEntry>[];
    await for (final entity in directory.list(followLinks: false)) {
      try {
        entries.add(await _entryFromEntity(entity));
      } catch (_) {
        entries.add(_fallbackEntry(entity.path));
      }
    }
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  Future<List<FileManagerEntry>> _listAgentToolFolders() async {
    final filesDir = await getPrivateRoot();
    final homeDir = Directory('$filesDir/rootfs/ubuntu/root');
    final privateDir = Directory(filesDir);
    final candidates = <String>[
      '${homeDir.path}/.codex',
      '${homeDir.path}/.openclaw',
      '${homeDir.path}/.claude',
      '${homeDir.path}/.qwen',
      '${homeDir.path}/.gemini',
      '${privateDir.path}/.codex',
      '${privateDir.path}/.openclaw',
    ];
    final seen = <String>{};
    final result = <FileManagerEntry>[];

    for (final path in candidates) {
      if (seen.contains(path)) continue;
      seen.add(path);
      final directory = Directory(path);
      if (await directory.exists()) {
        result.add(await _entryFromEntity(directory));
      }
    }

    for (final base in [homeDir, privateDir]) {
      if (!await base.exists()) continue;
      await for (final entity in base.list(followLinks: false)) {
        final name = basename(entity.path);
        if (!name.startsWith('.') || seen.contains(entity.path)) continue;
        if (await FileSystemEntity.isDirectory(entity.path)) {
          seen.add(entity.path);
          result.add(await _entryFromEntity(entity));
        }
      }
    }

    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  Future<void> createDirectory(String parentPath, String name) async {
    final path = join(parentPath, sanitizeName(name));
    await Directory(path).create(recursive: true);
  }

  Future<void> createFile(String parentPath, String name) async {
    final path = join(parentPath, sanitizeName(name));
    final file = File(path);
    if (await file.exists()) {
      throw FileSystemException('File already exists', path);
    }
    await file.create(recursive: true);
  }

  Future<void> deleteEntry(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    } else {
      await File(path).delete();
    }
  }

  Future<String> renameEntry(String path, String newName) async {
    final target = join(parentPath(path) ?? '/', sanitizeName(newName));
    if (target == path) return path;
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await Directory(path).rename(target);
    } else {
      await File(path).rename(target);
    }
    return target;
  }

  Future<String> copyEntry(String sourcePath, String targetDirectory) async {
    final targetPath = await _availableTargetPath(
      targetDirectory,
      basename(sourcePath),
    );
    final type = await FileSystemEntity.type(sourcePath, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await _copyDirectory(Directory(sourcePath), Directory(targetPath));
    } else {
      await File(sourcePath).copy(targetPath);
    }
    return targetPath;
  }

  Future<String> moveEntry(String sourcePath, String targetDirectory) async {
    final targetPath = await _availableTargetPath(
      targetDirectory,
      basename(sourcePath),
    );
    try {
      final type = await FileSystemEntity.type(sourcePath, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        await Directory(sourcePath).rename(targetPath);
      } else {
        await File(sourcePath).rename(targetPath);
      }
    } on FileSystemException {
      await _copyEntryTo(sourcePath, targetPath);
      await deleteEntry(sourcePath);
    }
    return targetPath;
  }

  Future<String> readTextFile(String path) async {
    final file = File(path);
    final size = await file.length();
    if (size > _textReadLimitBytes) {
      throw FileSystemException('File is larger than 1 MB', path);
    }
    final bytes = await file.readAsBytes();
    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<void> writeTextFile(String path, String content) async {
    await File(path).writeAsString(content, encoding: utf8);
  }

  Future<bool> isLikelyTextFile(String path, {String? name}) async {
    final lowerName = (name ?? basename(path)).toLowerCase();
    if (_knownBinaryExtensions.any(
      (extension) => lowerName.endsWith(extension),
    )) {
      return false;
    }
    if (_knownTextExtensions.any((extension) => lowerName.endsWith(extension)) ||
        _knownTextFileNames.contains(lowerName)) {
      return true;
    }

    final file = File(path);
    final length = await file.length();
    if (length == 0) {
      return true;
    }
    final sampleLength = math.min(length, 4096);
    final sample = await file.openRead(0, sampleLength).fold<List<int>>(
      <int>[],
      (previous, chunk) => previous..addAll(chunk),
    );
    if (sample.contains(0)) {
      return false;
    }

    var controlCount = 0;
    for (final byte in sample) {
      final isAllowedControl =
          byte == 9 || byte == 10 || byte == 12 || byte == 13;
      if (byte < 32 && !isAllowedControl) {
        controlCount++;
      }
    }
    if (controlCount / sample.length >= 0.05) {
      return false;
    }
    try {
      utf8.decode(sample, allowMalformed: false);
      return true;
    } on FormatException {
      return false;
    }
  }

  Future<String> readHexPreview(String path) async {
    final file = File(path);
    final length = await file.length();
    final sampleLength = math.min(length, _binaryPreviewBytes);
    final bytes = await file.openRead(0, sampleLength).fold<List<int>>(
      <int>[],
      (previous, chunk) => previous..addAll(chunk),
    );
    final lines = <String>[
      'Binary preview: ${formatSize(length)}',
      'Showing first ${formatSize(bytes.length)} as hex.',
      '',
    ];

    for (var offset = 0; offset < bytes.length; offset += 16) {
      final row = bytes.skip(offset).take(16).toList();
      final hex = row
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join(' ')
          .padRight(47);
      final ascii = row
          .map(
            (byte) =>
                byte >= 32 && byte <= 126 ? String.fromCharCode(byte) : '.',
          )
          .join();
      lines.add('${offset.toRadixString(16).padLeft(8, '0')}  $hex  $ascii');
    }

    return lines.join('\n');
  }

  bool canCreateIn(String path) => path != agentToolsPath;

  static String basename(String path) {
    var normalized = path.replaceAll(RegExp(r'/+$'), '');
    if (normalized.isEmpty) return '/';
    final index = normalized.lastIndexOf('/');
    return index >= 0 ? normalized.substring(index + 1) : normalized;
  }

  static String? parentPath(String path) {
    if (path == agentToolsPath) return null;
    var normalized = path.replaceAll(RegExp(r'/+$'), '');
    if (normalized.isEmpty || normalized == '/') return null;
    final index = normalized.lastIndexOf('/');
    if (index <= 0) return '/';
    return normalized.substring(0, index);
  }

  static String join(String parent, String child) {
    final normalizedParent = parent.replaceAll(RegExp(r'/+$'), '');
    if (normalizedParent.isEmpty || normalizedParent == '/') {
      return '/$child';
    }
    return '$normalizedParent/$child';
  }

  static String sanitizeName(String raw) {
    final value = raw.trim().replaceAll('/', '');
    if (value.isEmpty || value == '.' || value == '..') {
      throw const FileSystemException('Invalid file name');
    }
    return value;
  }

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(1)} GB';
  }

  Future<FileManagerEntry> _entryFromEntity(FileSystemEntity entity) async {
    final stat = await entity.stat();
    final isDirectory = stat.type == FileSystemEntityType.directory;
    return FileManagerEntry(
      name: basename(entity.path),
      path: entity.path,
      isDirectory: isDirectory,
      size: isDirectory ? 0 : stat.size,
      modified: stat.modified,
      isHidden: basename(entity.path).startsWith('.'),
      canRead: !await _throws(() async {
        if (isDirectory) {
          await Directory(entity.path).list(followLinks: false).take(1).length;
        } else {
          await File(entity.path).openRead(0, 1).drain<void>();
        }
      }),
      canWrite: !await _throws(() async {
        final parent = isDirectory ? entity.path : parentPath(entity.path);
        if (parent == null) throw const FileSystemException('No parent');
        await Directory(parent).stat();
      }),
    );
  }

  FileManagerEntry _fallbackEntry(String path) {
    return FileManagerEntry(
      name: basename(path),
      path: path,
      isDirectory: false,
      size: 0,
      modified: DateTime.fromMillisecondsSinceEpoch(0),
      isHidden: basename(path).startsWith('.'),
      canRead: false,
      canWrite: false,
    );
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list(followLinks: false)) {
      final nextTarget = join(target.path, basename(entity.path));
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        await _copyDirectory(Directory(entity.path), Directory(nextTarget));
      } else {
        await File(entity.path).copy(nextTarget);
      }
    }
  }

  Future<void> _copyEntryTo(String sourcePath, String targetPath) async {
    final type = await FileSystemEntity.type(sourcePath, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await _copyDirectory(Directory(sourcePath), Directory(targetPath));
    } else {
      await File(sourcePath).copy(targetPath);
    }
  }

  Future<String> _availableTargetPath(String directory, String name) async {
    var candidate = join(directory, name);
    if (!await FileSystemEntity.isDirectory(directory)) {
      throw FileSystemException('Target is not a directory', directory);
    }
    if (!await FileSystemEntity.isFile(candidate) &&
        !await FileSystemEntity.isDirectory(candidate) &&
        !await FileSystemEntity.isLink(candidate)) {
      return candidate;
    }

    final dotIndex = name.lastIndexOf('.');
    final stem = dotIndex > 0 ? name.substring(0, dotIndex) : name;
    final suffix = dotIndex > 0 ? name.substring(dotIndex) : '';
    var index = 1;
    do {
      candidate = join(directory, '${stem}_copy$index$suffix');
      index++;
    } while (await FileSystemEntity.isFile(candidate) ||
        await FileSystemEntity.isDirectory(candidate) ||
        await FileSystemEntity.isLink(candidate));
    return candidate;
  }

  Future<bool> _throws(Future<void> Function() action) async {
    try {
      await action();
      return false;
    } catch (_) {
      return true;
    }
  }
}

const _knownTextExtensions = [
  '.txt',
  '.md',
  '.markdown',
  '.json',
  '.jsonl',
  '.yaml',
  '.yml',
  '.toml',
  '.xml',
  '.html',
  '.htm',
  '.css',
  '.scss',
  '.js',
  '.mjs',
  '.cjs',
  '.ts',
  '.tsx',
  '.jsx',
  '.dart',
  '.kt',
  '.kts',
  '.java',
  '.gradle',
  '.properties',
  '.py',
  '.rb',
  '.go',
  '.rs',
  '.c',
  '.cc',
  '.cpp',
  '.h',
  '.hpp',
  '.sh',
  '.bash',
  '.zsh',
  '.fish',
  '.log',
  '.conf',
  '.cfg',
  '.ini',
  '.csv',
  '.sql',
  '.env',
  '.license',
];

const _knownTextFileNames = {
  'license',
  'notice',
  'readme',
  'changelog',
  '.env',
  '.gitignore',
  '.gitattributes',
  '.npmignore',
};

const _knownBinaryExtensions = [
  '.apk',
  '.apks',
  '.aab',
  '.zip',
  '.7z',
  '.rar',
  '.tar',
  '.gz',
  '.tgz',
  '.xz',
  '.bz2',
  '.zst',
  '.pdf',
  '.doc',
  '.docx',
  '.xls',
  '.xlsx',
  '.ppt',
  '.pptx',
  '.db',
  '.sqlite',
  '.so',
  '.o',
  '.a',
  '.dex',
  '.class',
  '.jar',
  '.ttf',
  '.otf',
  '.woff',
  '.woff2',
  '.mp3',
  '.m4a',
  '.flac',
  '.wav',
  '.ogg',
  '.mp4',
  '.mkv',
  '.mov',
  '.avi',
  '.webm',
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
  '.bmp',
  '.ico',
];
