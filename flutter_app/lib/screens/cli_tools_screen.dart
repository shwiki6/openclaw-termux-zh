import 'package:flutter/material.dart';

import '../app.dart';
import '../models/cli_tool.dart';
import '../services/cli_api_config_service.dart';
import '../services/cli_tool_service.dart';
import '../widgets/cli_api_config_dialog.dart';
import 'terminal_screen.dart';

class CliToolsScreen extends StatefulWidget {
  const CliToolsScreen({super.key});

  @override
  State<CliToolsScreen> createState() => _CliToolsScreenState();
}

class _CliToolsScreenState extends State<CliToolsScreen> {
  List<CliToolStatus> _statuses = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() => _loading = true);
    }
    try {
      await CliApiConfigService.regenerateRuntimeFiles();
    } catch (_) {
      // The Ubuntu rootfs may not exist yet; status checks below surface that.
    }
    final statuses = await CliToolService.checkAllStatuses();
    if (!mounted) return;
    setState(() {
      _statuses = statuses;
      _loading = false;
    });
  }

  Future<void> _openTool(CliToolDefinition tool) async {
    final isShell = tool.id == CliToolService.shellTool.id;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TerminalScreen(
          sessionId: tool.id,
          title: tool.name,
          initialCommand: isShell ? null : tool.launchCommand,
        ),
      ),
    );
    if (mounted) {
      await _refresh();
    }
  }

  Future<void> _installTool(CliToolDefinition tool) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TerminalScreen(
          sessionId: 'install-${tool.id}',
          title: 'Install ${tool.name}',
          initialCommand: tool.installCommand,
          restartOnOpen: true,
        ),
      ),
    );
    if (mounted) {
      await _refresh();
    }
  }

  Future<void> _configureTool(CliToolDefinition tool) async {
    final saved = await CliApiConfigDialog.show(context, tool: tool);
    if (saved && mounted) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CLI Tools'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '管理 Ubuntu 环境中的命令行工具。返回列表不会关闭已打开的终端，会话页右上角的关闭按钮才会终止进程。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final status in _statuses) _buildToolCard(theme, status),
                ],
              ),
            ),
    );
  }

  Widget _buildToolCard(ThemeData theme, CliToolStatus status) {
    final tool = status.tool;
    final isShell = tool.id == CliToolService.shellTool.id;
    final configurable =
        CliApiConfigService.configurableToolIds.contains(tool.id);
    final installed = isShell || status.installed;
    final statusColor =
        installed ? AppColors.statusGreen : theme.colorScheme.error;
    final statusLabel = installed ? '已安装' : '未安装';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tool.color.withAlpha(28),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(tool.icon, color: tool.color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tool.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tool.packageName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusPill(theme, statusLabel, statusColor),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              tool.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            _buildVersionLine(theme, status),
            if (status.error != null) ...[
              const SizedBox(height: 8),
              Text(
                status.error!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (configurable) ...[
                  OutlinedButton.icon(
                    onPressed: () => _configureTool(tool),
                    icon: const Icon(Icons.tune),
                    label: const Text('配置'),
                  ),
                  const SizedBox(width: 8),
                ],
                if (!isShell) ...[
                  FilledButton.icon(
                    onPressed: () => _installTool(tool),
                    icon: const Icon(Icons.download),
                    label: Text(status.installed ? '更新' : '安装'),
                  ),
                  const SizedBox(width: 8),
                ],
                OutlinedButton.icon(
                  onPressed: installed ? () => _openTool(tool) : null,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('打开'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(ThemeData theme, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildVersionLine(ThemeData theme, CliToolStatus status) {
    final version = status.version?.trim();
    final value = version == null || version.isEmpty ? '未知版本' : version;
    return Row(
      children: [
        Icon(
          Icons.info_outline,
          size: 15,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
