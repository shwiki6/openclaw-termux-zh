import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import 'native_bridge.dart';

class BundledSampleConfig {
  const BundledSampleConfig({
    required this.version,
    required this.assetPath,
    required this.config,
    this.generated = false,
  });

  final String version;
  final String assetPath;
  final Map<String, dynamic> config;
  final bool generated;
}

class BundledSampleConfigService {
  static const _assetDirectory = 'assets/sample_configs/openclaw';
  static const _targetConfigPath = 'root/.openclaw/openclaw.json';

  static String assetPathForVersion(String version) =>
      '$_assetDirectory/${version.trim()}.json';

  static Future<BundledSampleConfig?> loadForVersion(String? version) async {
    final normalizedVersion = version?.trim() ?? '';
    if (normalizedVersion.isEmpty) {
      return null;
    }

    final assetPath = assetPathForVersion(normalizedVersion);
    try {
      final content = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(content);
      if (decoded is! Map) {
        return null;
      }

      return BundledSampleConfig(
        version: normalizedVersion,
        assetPath: assetPath,
        config: _sanitizeConfig(
          Map<String, dynamic>.from(decoded),
          version: normalizedVersion,
        ),
      );
    } catch (_) {
      return _buildGeneratedConfig(normalizedVersion);
    }
  }

  static BundledSampleConfig _buildGeneratedConfig(String version) {
    final now = DateTime.now().toUtc().toIso8601String();
    final token = _randomHexToken();

    return BundledSampleConfig(
      version: version,
      assetPath: 'generated://recommended-android-openclaw.json',
      generated: true,
      config: {
        'wizard': {
          'lastRunAt': now,
          'lastRunVersion': version,
          'lastRunCommand': 'onboard',
          'lastRunMode': 'local',
        },
        'agents': {
          'defaults': {
            'workspace': '/root/.openclaw/workspace',
          },
        },
        'tools': {
          'profile': 'full',
          'web': {
            'search': {
              'enabled': true,
              'provider': 'duckduckgo',
            },
          },
        },
        'commands': {
          'native': 'auto',
          'nativeSkills': 'auto',
          'restart': true,
          'ownerDisplay': 'raw',
        },
        'session': {
          'dmScope': 'per-channel-peer',
        },
        'hooks': {
          'internal': {
            'enabled': true,
            'entries': {
              'boot-md': {'enabled': true},
              'session-memory': {'enabled': true},
              'command-logger': {'enabled': true},
              'bootstrap-extra-files': {'enabled': true},
            },
          },
        },
        'gateway': {
          'port': 18789,
          'mode': 'local',
          'bind': 'loopback',
          'auth': {
            'mode': 'token',
            'token': token,
          },
          'tailscale': {
            'mode': 'off',
            'resetOnExit': false,
          },
          'controlUi': {
            'allowInsecureAuth': true,
          },
          'nodes': {
            'denyCommands': [],
            'allowCommands': [
              'camera.snap',
              'camera.clip',
              'camera.list',
              'canvas.navigate',
              'canvas.eval',
              'canvas.snapshot',
              'flash.on',
              'flash.off',
              'flash.toggle',
              'flash.status',
              'location.get',
              'screen.record',
              'sensor.read',
              'sensor.list',
              'haptic.vibrate',
              'serial.list',
              'serial.connect',
              'serial.disconnect',
              'serial.write',
              'serial.read',
            ],
          },
          'reload': {
            'mode': 'hybrid',
          },
        },
        'plugins': {
          'entries': {
            'duckduckgo': {
              'enabled': true,
            },
          },
        },
        'discovery': {
          'mdns': {
            'mode': 'off',
          },
        },
        'meta': {
          'lastTouchedVersion': version,
          'lastTouchedAt': now,
        },
      },
    );
  }

  static String _randomHexToken([int byteCount = 24]) {
    final random = Random.secure();
    final bytes = List<int>.generate(byteCount, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  static Map<String, dynamic> _sanitizeConfig(
    Map<String, dynamic> config, {
    required String version,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    final gateway = _stringKeyedMap(config['gateway']);
    config['gateway'] = gateway;

    final auth = _stringKeyedMap(gateway['auth']);
    auth['mode'] = 'token';
    auth['token'] = _randomHexToken();
    gateway['auth'] = auth;

    final meta = _stringKeyedMap(config['meta']);
    meta['lastTouchedVersion'] = version;
    meta['lastTouchedAt'] = now;
    config['meta'] = meta;

    final wizard = _stringKeyedMap(config['wizard']);
    wizard['lastRunVersion'] = version;
    wizard['lastRunAt'] = now;
    config['wizard'] = wizard;

    final models = _stringKeyedMap(config['models']);
    final providers = _stringKeyedMap(models['providers']);
    for (final entry in providers.entries.toList()) {
      final provider = _stringKeyedMap(entry.value);
      if (provider.containsKey('apiKey')) {
        provider['apiKey'] = '';
      }
      providers[entry.key] = provider;
    }
    models['providers'] = providers;
    config['models'] = models;

    return config;
  }

  static Map<String, dynamic> _stringKeyedMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
  }

  static Future<void> apply(BundledSampleConfig sample) async {
    await NativeBridge.writeRootfsFile(
      _targetConfigPath,
      const JsonEncoder.withIndent('  ').convert(sample.config),
    );
  }
}
