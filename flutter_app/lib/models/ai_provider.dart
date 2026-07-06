import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

enum BaseUrlBehavior {
  keepAsIs,
  appendV1IfMissing,
}

/// Metadata for an AI model provider that can be configured
/// to power the OpenClaw gateway.
class AiProvider {
  final String id;
  final String nameKey;
  final String descriptionKey;
  final IconData icon;
  final Color color;
  final String baseUrl;
  final List<String> defaultModels;
  final String apiKeyHint;
  final bool supportsCustomBaseUrl;
  final String? endpointHelperKey;
  final String? modelHintKey;
  final BaseUrlBehavior baseUrlBehavior;
  final String? apiValue;

  const AiProvider({
    required this.id,
    required this.nameKey,
    required this.descriptionKey,
    required this.icon,
    required this.color,
    required this.baseUrl,
    required this.defaultModels,
    required this.apiKeyHint,
    this.supportsCustomBaseUrl = false,
    this.endpointHelperKey,
    this.modelHintKey,
    this.baseUrlBehavior = BaseUrlBehavior.keepAsIs,
    this.apiValue,
  });

  String name(AppLocalizations l10n) => l10n.t(nameKey);

  String description(AppLocalizations l10n) => l10n.t(descriptionKey);

  String endpointHelper(AppLocalizations l10n) =>
      l10n.t(endpointHelperKey ?? 'providerDetailEndpointHelper');

  String modelHint(AppLocalizations l10n) =>
      l10n.t(modelHintKey ?? 'providerDetailCustomModelHint');

  bool matchesModel(String model) {
    return defaultModels.any((candidate) => model.contains(candidate)) ||
        model.contains(id);
  }

  String normalizeBaseUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty ||
        baseUrlBehavior != BaseUrlBehavior.appendV1IfMissing) {
      return trimmed;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return trimmed;
    }

    var path = uri.path.trim();
    if (path.isEmpty || path == '/') {
      path = '/v1';
    } else {
      path = path.replaceAll(RegExp(r'/+$'), '');
      if (!path.endsWith('/v1')) {
        path = '$path/v1';
      }
    }

    return uri.replace(path: path).toString();
  }

  static const customOpenai = AiProvider(
    id: 'custom-openai',
    nameKey: 'providerNameCustomOpenai',
    descriptionKey: 'providerDescriptionCustomOpenai',
    icon: Icons.api,
    color: Color(0xFF0F766E),
    baseUrl: 'https://api.example.com/v1',
    defaultModels: [],
    apiKeyHint: 'sk-...',
    supportsCustomBaseUrl: true,
    endpointHelperKey: 'providerDetailEndpointHelperOpenaiCompatible',
    modelHintKey: 'providerDetailModelHintOpenaiCompatible',
    baseUrlBehavior: BaseUrlBehavior.appendV1IfMissing,
  );

  static const anthropic = AiProvider(
    id: 'anthropic',
    nameKey: 'providerNameAnthropic',
    descriptionKey: 'providerDescriptionAnthropic',
    icon: Icons.psychology,
    color: Color(0xFFD97706),
    baseUrl: 'https://api.anthropic.com/v1',
    defaultModels: [
      'claude-fable-5',
      'claude-opus-4-8',
      'claude-sonnet-5',
    ],
    apiKeyHint: 'sk-ant-...',
  );

  static const openai = AiProvider(
    id: 'openai',
    nameKey: 'providerNameOpenai',
    descriptionKey: 'providerDescriptionOpenai',
    icon: Icons.auto_awesome,
    color: Color(0xFF10A37F),
    baseUrl: 'https://api.openai.com/v1',
    defaultModels: [
      'gpt-5.5',
      'gpt-5.4',
      'gpt-5.4-mini',
    ],
    apiKeyHint: 'sk-...',
    supportsCustomBaseUrl: true,
  );

  static const zhipu = AiProvider(
    id: 'zhipu',
    nameKey: 'providerNameZhipu',
    descriptionKey: 'providerDescriptionZhipu',
    icon: Icons.hub,
    color: Color(0xFF2563EB),
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    defaultModels: [
      'glm-5',
      'glm-4.7',
      'glm-4.6',
    ],
    apiKeyHint: 'your-api-key',
    supportsCustomBaseUrl: true,
    endpointHelperKey: 'providerDetailEndpointHelperZhipu',
    modelHintKey: 'providerDetailModelHintZhipu',
    apiValue: 'openai-completions',
  );

  static const google = AiProvider(
    id: 'google',
    nameKey: 'providerNameGoogle',
    descriptionKey: 'providerDescriptionGoogle',
    icon: Icons.diamond,
    color: Color(0xFF4285F4),
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    defaultModels: [
      'gemini-3.1-pro-preview',
      'gemini-3.5-flash',
      'gemini-3.1-flash-lite',
    ],
    apiKeyHint: 'AIza...',
  );

  static const openrouter = AiProvider(
    id: 'openrouter',
    nameKey: 'providerNameOpenrouter',
    descriptionKey: 'providerDescriptionOpenrouter',
    icon: Icons.route,
    color: Color(0xFF6366F1),
    baseUrl: 'https://openrouter.ai/api/v1',
    defaultModels: [
      'anthropic/claude-fable-5',
      'openai/gpt-5.5',
      'google/gemini-3.1-pro-preview',
    ],
    apiKeyHint: 'sk-or-...',
  );

  static const nvidia = AiProvider(
    id: 'nvidia',
    nameKey: 'providerNameNvidia',
    descriptionKey: 'providerDescriptionNvidia',
    icon: Icons.memory,
    color: Color(0xFF76B900),
    baseUrl: 'https://integrate.api.nvidia.com/v1',
    defaultModels: [
      'deepseek-ai/deepseek-r1',
      'meta/llama-3.3-70b-instruct',
      'nvidia/llama-3.1-nemotron-70b-instruct',
    ],
    apiKeyHint: 'nvapi-...',
  );

  static const deepseek = AiProvider(
    id: 'deepseek',
    nameKey: 'providerNameDeepseek',
    descriptionKey: 'providerDescriptionDeepseek',
    icon: Icons.explore,
    color: Color(0xFF0EA5E9),
    baseUrl: 'https://api.deepseek.com/v1',
    defaultModels: [
      'deepseek-v4-pro',
      'deepseek-v4-flash',
      'deepseek-chat',
    ],
    apiKeyHint: 'sk-...',
  );

  static const xai = AiProvider(
    id: 'xai',
    nameKey: 'providerNameXai',
    descriptionKey: 'providerDescriptionXai',
    icon: Icons.bolt,
    color: Color(0xFFEF4444),
    baseUrl: 'https://api.x.ai/v1',
    defaultModels: [
      'grok-build-0.1',
      'grok-4.3',
      'grok-4.3-thinking',
    ],
    apiKeyHint: 'xai-...',
  );

  static const qwen = AiProvider(
    id: 'qwen',
    nameKey: 'providerNameQwen',
    descriptionKey: 'providerDescriptionQwen',
    icon: Icons.cloud,
    color: Color(0xFF2563EB),
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    defaultModels: [
      'qwen3.7-max',
      'qwen3.7-plus',
      'qwen3.6-flash',
    ],
    apiKeyHint: 'sk-...',
    supportsCustomBaseUrl: true,
  );

  static const minimax = AiProvider(
    id: 'minimax',
    nameKey: 'providerNameMinimax',
    descriptionKey: 'providerDescriptionMinimax',
    icon: Icons.forum,
    color: Color(0xFFEC4899),
    baseUrl: 'https://api.minimax.chat/v1',
    defaultModels: [
      'MiniMax-M3',
      'MiniMax-M2.7',
      'MiniMax-M2.7-highspeed',
    ],
    apiKeyHint: 'sk-...',
    supportsCustomBaseUrl: true,
  );

  static const doubao = AiProvider(
    id: 'doubao',
    nameKey: 'providerNameDoubao',
    descriptionKey: 'providerDescriptionDoubao',
    icon: Icons.token,
    color: Color(0xFFEA580C),
    baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
    defaultModels: [
      'doubao-seed-2-1-pro',
      'doubao-seed-2-1-lite',
      'doubao-seed-2-1-mini',
    ],
    apiKeyHint: 'ark-...',
    supportsCustomBaseUrl: true,
  );

  /// All available AI providers.
  static const all = [
    customOpenai,
    anthropic,
    openai,
    zhipu,
    qwen,
    minimax,
    doubao,
    google,
    openrouter,
    nvidia,
    deepseek,
    xai,
  ];
}
