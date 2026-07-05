import 'package:flutter/material.dart';

import '../models/cli_api_config.dart';
import '../models/cli_tool.dart';
import '../services/cli_api_config_service.dart';

class CliApiConfigDialog extends StatefulWidget {
  final CliToolDefinition tool;

  const CliApiConfigDialog({
    super.key,
    required this.tool,
  });

  @override
  State<CliApiConfigDialog> createState() => _CliApiConfigDialogState();

  static Future<bool> show(
    BuildContext context, {
    required CliToolDefinition tool,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => CliApiConfigDialog(tool: tool),
    );
    return result == true;
  }
}

class _CliApiConfigDialogState extends State<CliApiConfigDialog> {
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _mappingController = TextEditingController();
  String _reasoningEffort = '';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isCodex => widget.tool.id == 'codex';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _mappingController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final config = await CliApiConfigService.load(widget.tool.id);
      if (!mounted) return;
      setState(() {
        _baseUrlController.text = config.baseUrl;
        _apiKeyController.text = config.apiKey;
        _modelController.text = config.model;
        _mappingController.text = config.codexModelMapping;
        _reasoningEffort = config.reasoningEffort;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await CliApiConfigService.save(
        CliApiConfig(
          toolId: widget.tool.id,
          baseUrl: _baseUrlController.text,
          apiKey: _apiKeyController.text,
          model: _modelController.text,
          reasoningEffort: _reasoningEffort,
          codexModelMapping: _isCodex ? _mappingController.text : '',
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text('${widget.tool.name} 配置'),
      content: SizedBox(
        width: 520,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isCodex
                          ? 'Codex 支持自定义 OpenAI 兼容地址。若服务端模型名和 Codex 识别名不同，可填写模型映射。'
                          : 'Claude Code 通常需要 Anthropic 兼容 API。第三方中转需兼容 Anthropic 协议。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _baseUrlController,
                      decoration: const InputDecoration(
                        labelText: 'API 地址',
                        hintText: 'https://api.example.com/v1',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _apiKeyController,
                      decoration: const InputDecoration(
                        labelText: 'API Key',
                        hintText: 'sk-...',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _modelController,
                      decoration: InputDecoration(
                        labelText: _isCodex ? '服务端模型名' : '模型',
                        hintText: _isCodex ? 'gpt-5-codex' : 'claude-sonnet-4',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (_isCodex) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _mappingController,
                        decoration: const InputDecoration(
                          labelText: 'Codex 模型映射（可选）',
                          hintText: '留空则使用服务端模型名',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _reasoningEffort,
                      decoration: const InputDecoration(
                        labelText: '推理强度（可选）',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: '', child: Text('不设置')),
                        DropdownMenuItem(
                          value: 'minimal',
                          child: Text('minimal'),
                        ),
                        DropdownMenuItem(value: 'low', child: Text('low')),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('medium'),
                        ),
                        DropdownMenuItem(value: 'high', child: Text('high')),
                        DropdownMenuItem(
                          value: 'xhigh',
                          child: Text('xhigh'),
                        ),
                        DropdownMenuItem(value: 'ultra', child: Text('ultra')),
                      ],
                      onChanged: (value) {
                        setState(() => _reasoningEffort = value ?? '');
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _loading || _saving ? null : _save,
          child: Text(_saving ? '保存中...' : '保存'),
        ),
      ],
    );
  }
}
