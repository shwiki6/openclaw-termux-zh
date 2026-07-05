class CliApiConfig {
  final String toolId;
  final String baseUrl;
  final String apiKey;
  final String model;
  final String reasoningEffort;
  final String codexModelMapping;

  const CliApiConfig({
    required this.toolId,
    this.baseUrl = '',
    this.apiKey = '',
    this.model = '',
    this.reasoningEffort = '',
    this.codexModelMapping = '',
  });

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty ||
      apiKey.trim().isNotEmpty ||
      model.trim().isNotEmpty ||
      reasoningEffort.trim().isNotEmpty ||
      codexModelMapping.trim().isNotEmpty;

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
  }) {
    return CliApiConfig(
      toolId: toolId,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      reasoningEffort: reasoningEffort ?? this.reasoningEffort,
      codexModelMapping: codexModelMapping ?? this.codexModelMapping,
    );
  }

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl.trim(),
        'apiKey': apiKey.trim(),
        'model': model.trim(),
        'reasoningEffort': reasoningEffort.trim(),
        'codexModelMapping': codexModelMapping.trim(),
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
    );
  }

  static String _string(dynamic value) => value is String ? value : '';
}
