import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cli_api_config.dart';
import 'native_bridge.dart';

class CliApiConfigService {
  static const _configPath = '/root/.openclaw/app/cli-api-config.json';
  static const _envPath = '/root/.openclaw/cli-env.sh';
  static const _codexConfigPath = '/root/.codex/config.toml';
  static const _prefsKey = 'cli_api_config_json';

  static const configurableToolIds = {'codex', 'claude'};

  static Future<CliApiConfig> load(String toolId) async {
    final configs = await _loadAll();
    final tools = _asMap(configs['tools']);
    return CliApiConfig.fromJson(toolId, _asMapOrNull(tools[toolId]));
  }

  static Future<Map<String, CliApiConfig>> loadAll() async {
    final configs = await _loadAll();
    final tools = _asMap(configs['tools']);
    return {
      for (final toolId in configurableToolIds)
        toolId: CliApiConfig.fromJson(toolId, _asMapOrNull(tools[toolId])),
    };
  }

  static Future<void> save(CliApiConfig config) async {
    final configs = await _loadAll();
    final tools = _asMap(configs['tools']);
    configs['tools'] = tools;
    tools[config.toolId] = config.toJson();

    await _writePrefsConfig(configs);
    try {
      await regenerateRuntimeFiles(configs: configs);
    } catch (_) {
      // Rootfs may not exist yet during first-run preconfiguration.
      // The setup flow calls regenerateRuntimeFiles() again after extraction.
    }
  }

  static Future<List<String>> fetchModels({
    required String toolId,
    required String baseUrl,
    required String apiKey,
  }) async {
    final endpoint = _modelsEndpoint(baseUrl);
    if (endpoint == null) {
      throw Exception('请先填写 API 地址');
    }
    if (apiKey.trim().isEmpty) {
      throw Exception('请先填写 API Key');
    }

    final headers = <String, String>{
      'Accept': 'application/json',
      if (toolId == 'claude') ...{
        'x-api-key': apiKey.trim(),
        'anthropic-version': '2023-06-01',
      } else
        'Authorization': 'Bearer ${apiKey.trim()}',
    };
    if (toolId == 'claude') {
      headers['Authorization'] = 'Bearer ${apiKey.trim()}';
    }

    final response = await http
        .get(endpoint, headers: headers)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('模型列表获取失败：HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final models = _extractModelIds(decoded).toSet().toList()..sort();
    if (models.isEmpty) {
      throw Exception('模型列表为空或响应格式不支持');
    }
    return models;
  }

  static Future<void> regenerateRuntimeFiles({
    Map<String, dynamic>? configs,
  }) async {
    final allConfigs = configs ?? await _loadAll();
    final tools = _asMap(allConfigs['tools']);
    final codex = CliApiConfig.fromJson('codex', _asMapOrNull(tools['codex']));
    final claude =
        CliApiConfig.fromJson('claude', _asMapOrNull(tools['claude']));

    await _writePrefsConfig(allConfigs);
    await NativeBridge.writeRootfsFile(
      _configPath,
      const JsonEncoder.withIndent('  ').convert(allConfigs),
    );
    await NativeBridge.writeRootfsFile(_envPath, _buildEnvFile(codex, claude));
    await NativeBridge.writeRootfsFile(_codexConfigPath, _buildCodexToml(codex));
  }

  static Future<Map<String, dynamic>> _loadAll() async {
    final prefsConfig = await _readPrefsConfig();
    if (prefsConfig.isNotEmpty) {
      return prefsConfig;
    }

    try {
      final content = await NativeBridge.readRootfsFile(_configPath);
      if (content == null || content.trim().isEmpty) {
        return <String, dynamic>{'tools': <String, dynamic>{}};
      }
      final decoded = jsonDecode(content);
      final config = _asMap(decoded);
      config['tools'] = _asMap(config['tools']);
      await _writePrefsConfig(config);
      return config;
    } catch (_) {
      return <String, dynamic>{'tools': <String, dynamic>{}};
    }
  }

  static Future<Map<String, dynamic>> _readPrefsConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final content = prefs.getString(_prefsKey);
      if (content == null || content.trim().isEmpty) {
        return <String, dynamic>{};
      }
      final config = _asMap(jsonDecode(content));
      config['tools'] = _asMap(config['tools']);
      return config;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Future<void> _writePrefsConfig(Map<String, dynamic> config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      const JsonEncoder.withIndent('  ').convert(config),
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
  }

  static Map<String, dynamic>? _asMapOrNull(dynamic value) {
    if (value == null) return null;
    return _asMap(value);
  }

  static String _buildEnvFile(CliApiConfig codex, CliApiConfig claude) {
    final lines = <String>[
      '# Generated by OpenClaw app. Safe to source from CLI wrappers.',
      'export OPENCLAW_CLI_ENV_LOADED=1',
    ];

    if (codex.apiKey.trim().isNotEmpty) {
      lines.add('export OPENAI_API_KEY=${_shQuote(codex.apiKey.trim())}');
    }
    if (codex.baseUrl.trim().isNotEmpty) {
      lines.add('export OPENAI_BASE_URL=${_shQuote(codex.baseUrl.trim())}');
      lines.add('export CODEX_BASE_URL=${_shQuote(codex.baseUrl.trim())}');
    }
    if (codex.effectiveCodexModel.isNotEmpty) {
      lines.add('export OPENAI_MODEL=${_shQuote(codex.effectiveCodexModel)}');
      lines.add('export CODEX_MODEL=${_shQuote(codex.effectiveCodexModel)}');
    }
    if (codex.reasoningEffort.trim().isNotEmpty) {
      final effort = codex.reasoningEffort.trim();
      lines.add('export OPENAI_REASONING_EFFORT=${_shQuote(effort)}');
      lines.add('export CODEX_REASONING_EFFORT=${_shQuote(effort)}');
    }

    if (claude.apiKey.trim().isNotEmpty) {
      lines.add('export ANTHROPIC_API_KEY=${_shQuote(claude.apiKey.trim())}');
      lines.add('unset ANTHROPIC_AUTH_TOKEN');
    }
    if (claude.baseUrl.trim().isNotEmpty) {
      lines.add('export ANTHROPIC_BASE_URL=${_shQuote(claude.baseUrl.trim())}');
      lines.add('export CLAUDE_CODE_BASE_URL=${_shQuote(claude.baseUrl.trim())}');
    }
    if (claude.model.trim().isNotEmpty) {
      lines.add('export ANTHROPIC_MODEL=${_shQuote(claude.model.trim())}');
      lines.add('export CLAUDE_CODE_MODEL=${_shQuote(claude.model.trim())}');
    }
    if (claude.reasoningEffort.trim().isNotEmpty) {
      final effort = claude.reasoningEffort.trim();
      lines.add('export ANTHROPIC_REASONING_EFFORT=${_shQuote(effort)}');
      lines.add('export CLAUDE_CODE_REASONING_EFFORT=${_shQuote(effort)}');
    }

    lines.add('');
    return lines.join('\n');
  }

  static String _buildCodexToml(CliApiConfig codex) {
    final lines = <String>[];
    final model = codex.effectiveCodexModel;
    final baseUrl = codex.baseUrl.trim();
    final effort = codex.reasoningEffort.trim();

    if (model.isNotEmpty) {
      lines.add('model = ${_tomlString(model)}');
    }
    if (effort.isNotEmpty) {
      lines.add('model_reasoning_effort = ${_tomlString(effort)}');
    }
    if (baseUrl.isNotEmpty) {
      lines
        ..add('model_provider = "openclaw"')
        ..add('')
        ..add('[model_providers.openclaw]')
        ..add('name = "OpenClaw Custom API"')
        ..add('base_url = ${_tomlString(baseUrl)}')
        ..add('env_key = "OPENAI_API_KEY"')
        ..add('wire_api = "responses"');
    }

    if (lines.isEmpty) {
      lines.add('# OpenClaw CLI config is empty. Configure Codex in the app.');
    }
    lines.add('');
    return lines.join('\n');
  }

  static String _shQuote(String value) {
    return "'${value.replaceAll("'", r"'\''")}'";
  }

  static String _tomlString(String value) {
    return jsonEncode(value);
  }

  static Uri? _modelsEndpoint(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) return null;
    final normalized = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;

    final segments = uri.pathSegments.where((item) => item.isNotEmpty).toList();
    if (segments.isEmpty) {
      return uri.replace(pathSegments: ['v1', 'models']);
    }
    if (segments.last == 'models') {
      return uri;
    }
    return uri.replace(pathSegments: [...segments, 'models']);
  }

  static List<String> _extractModelIds(dynamic decoded) {
    final result = <String>[];
    void addModel(dynamic item) {
      if (item is String && item.trim().isNotEmpty) {
        result.add(item.trim());
        return;
      }
      if (item is Map) {
        final id = item['id'] ?? item['name'] ?? item['model'];
        if (id is String && id.trim().isNotEmpty) {
          result.add(id.trim());
        }
      }
    }

    if (decoded is Map) {
      final data = decoded['data'] ?? decoded['models'];
      if (data is List) {
        for (final item in data) {
          addModel(item);
        }
      } else {
        addModel(data);
      }
    } else if (decoded is List) {
      for (final item in decoded) {
        addModel(item);
      }
    }
    return result;
  }
}
