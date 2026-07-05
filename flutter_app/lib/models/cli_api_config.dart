class CliApiConfig {
  final String toolId;
  final String baseUrl;
  final String apiKey;
  final String model;
  final String reasoningEffort;
  final String codexModelMapping;
  final String apiProtocol;

  const CliApiConfig({
    required this.toolId,
    this.baseUrl = '',
    this.apiKey = '',
    this.model = '',
    this.reasoningEffort = '',
    this.codexModelMapping = '',
    this.apiProtocol = '',
  });

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty ||
      apiKey.trim().isNotEmpty ||
      model.trim().isNotEmpty ||
      reasoningEffort.trim().isNotEmpty ||
      codexModelMapping.trim().isNotEmpty;

  String get effectiveApiProtocol {
    final protocol = apiProtocol.trim();
    if (protocol.isNotEmpty) return protocol;
    return toolId == 'claude' ? 'anthropic' : 'openai';
  }

  String get effectiveCodexModel {
    final mapped = codexModelMapping.trim();
    return mapped.isNotEmpty ? mapped : model.trim();
  }

  CliApiConfig copyWith({
    String? baseUrl,
    String? apiKey,
    String? model,
    String? reasoningEffort,
    String? codexModelMapping,
    String? apiProtocol,
  }) {
    return CliApiConfig(
      toolId: toolId,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      reasoningEffort: reasoningEffort ?? this.reasoningEffort,
      codexModelMapping: codexModelMapping ?? this.codexModelMapping,
      apiProtocol: apiProtocol ?? this.apiProtocol,
    );
  }

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl.trim(),
        'apiKey': apiKey.trim(),
        'model': model.trim(),
        'reasoningEffort': reasoningEffort.trim(),
        'codexModelMapping': codexModelMapping.trim(),
        'apiProtocol': effectiveApiProtocol,
      };

  static CliApiConfig fromJson(String toolId, Map<String, dynamic>? json) {
    if (json == null) {
      return CliApiConfig(toolId: toolId);
    }
    return CliApiConfig(
      toolId: toolId,
      baseUrl: _string(json['baseUrl']),
      apiKey: _string(json['apiKey']),
      model: _string(json['model']),
      reasoningEffort: _string(json['reasoningEffort']),
      codexModelMapping: _string(json['codexModelMapping']),
      apiProtocol: _string(json['apiProtocol']),
    );
  }

  static String _string(dynamic value) => value is String ? value : '';
}
