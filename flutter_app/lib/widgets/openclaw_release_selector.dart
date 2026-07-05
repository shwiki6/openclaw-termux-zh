import 'package:flutter/material.dart';

import '../constants.dart';
import '../l10n/app_localizations.dart';
import '../models/openclaw_install_options.dart';
import '../services/openclaw_release_notes_zh.dart';
import '../services/openclaw_version_service.dart';

class OpenClawReleaseSelector extends StatefulWidget {
  final List<OpenClawReleaseInfo> releases;
  final OpenClawReleaseInfo? selectedRelease;
  final OpenClawReleaseInfo? latestRelease;
  final bool enabled;
  final ValueChanged<OpenClawReleaseInfo> onChanged;

  const OpenClawReleaseSelector({
    super.key,
    required this.releases,
    required this.selectedRelease,
    required this.latestRelease,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<OpenClawReleaseSelector> createState() =>
      _OpenClawReleaseSelectorState();
}

class _OpenClawReleaseSelectorState extends State<OpenClawReleaseSelector> {
  final _versionService = OpenClawVersionService();
  final Map<String, String?> _notesCache = {};
  final Set<String> _loadingNotes = {};
  String? _expandedVersion;

  @override
  void initState() {
    super.initState();
    _expandedVersion = widget.selectedRelease?.version;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSelectedReleaseNotes();
    });
  }

  @override
  void didUpdateWidget(covariant OpenClawReleaseSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedRelease?.version != widget.selectedRelease?.version) {
      _expandedVersion = widget.selectedRelease?.version;
      _loadSelectedReleaseNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    if (widget.releases.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: _boxDecoration(theme),
        child: Text(
          l10n.t('openClawReleaseListEmpty'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Container(
      decoration: _boxDecoration(theme),
      child: Column(
        children: [
          for (var index = 0; index < widget.releases.length; index++) ...[
            _buildReleaseTile(context, widget.releases[index]),
            if (index != widget.releases.length - 1)
              Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }

  BoxDecoration _boxDecoration(ThemeData theme) {
    return BoxDecoration(
      border: Border.all(color: theme.colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(8),
    );
  }

  Widget _buildReleaseTile(BuildContext context, OpenClawReleaseInfo release) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final selected = widget.selectedRelease?.version == release.version;
    final groupValue = widget.selectedRelease?.version;
    final expanded = _expandedVersion == release.version;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.enabled ? () => _toggleRelease(release) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Radio<String>(
                    value: release.version,
                    groupValue: groupValue,
                    onChanged:
                        widget.enabled ? (_) => _selectRelease(release) : null,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  formatOpenClawReleaseLabel(
                                    l10n,
                                    release.version,
                                    latestVersion:
                                        widget.latestRelease?.version,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(
                                expanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 20,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _summary(l10n, release),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 0, 6),
                  child: _buildReleaseDetails(context, release),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReleaseDetails(
    BuildContext context,
    OpenClawReleaseInfo release,
  ) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('openClawReleaseNotesTitle'),
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _releaseNotes(l10n, release),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        _detailLine(
          context,
          Icons.inventory_2_outlined,
          l10n.t('openClawReleasePackageSize', {
            'size':
                release.unpackedSizeLabel ?? AppConstants.openClawEstimatedSize,
          }),
        ),
        if (release.nodeRequirement?.trim().isNotEmpty == true)
          _detailLine(
            context,
            Icons.memory_outlined,
            l10n.t('gatewayNodeRequirementHint', {
              'requirement': release.nodeRequirement,
            }),
          ),
        if (release.publishedAt?.trim().isNotEmpty == true)
          _detailLine(
            context,
            Icons.schedule_outlined,
            l10n.t('openClawReleasePublishedAt', {
              'date': _formatPublishedAt(release.publishedAt!),
            }),
          ),
      ],
    );
  }

  void _toggleRelease(OpenClawReleaseInfo release) {
    widget.onChanged(release);
    setState(() {
      _expandedVersion =
          _expandedVersion == release.version ? null : release.version;
    });
    _loadReleaseNotes(release.version);
  }

  void _selectRelease(OpenClawReleaseInfo release) {
    widget.onChanged(release);
    setState(() => _expandedVersion = release.version);
    _loadReleaseNotes(release.version);
  }

  Widget _detailLine(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _summary(AppLocalizations l10n, OpenClawReleaseInfo release) {
    return l10n.t('openClawReleaseSummary', {
      'size': release.unpackedSizeLabel ?? AppConstants.openClawEstimatedSize,
      'date': release.publishedAt == null
          ? l10n.t('commonUnknown')
          : _formatPublishedAt(release.publishedAt!),
    });
  }

  String _releaseNotes(AppLocalizations l10n, OpenClawReleaseInfo release) {
    final builtinZhNotes = OpenClawReleaseNotesZh.forVersion(release.version);
    if (builtinZhNotes != null) {
      return builtinZhNotes;
    }
    if (_loadingNotes.contains(release.version)) {
      return l10n.t('openClawReleaseNotesLoading');
    }
    final remoteNotes = _notesCache[release.version]?.trim();
    if (remoteNotes != null && remoteNotes.isNotEmpty) {
      return remoteNotes;
    }
    final notes = release.releaseNotes?.trim();
    if (notes != null && notes.isNotEmpty) {
      return notes;
    }
    final description = release.description?.trim();
    if (description != null && description.isNotEmpty) {
      return '${l10n.t('openClawReleaseNotesUnavailable')}\n$description';
    }
    return l10n.t('openClawReleaseNotesUnavailable');
  }

  Future<void> _loadReleaseNotes(String version) async {
    if (OpenClawReleaseNotesZh.hasVersion(version)) {
      return;
    }
    if (_notesCache.containsKey(version) || _loadingNotes.contains(version)) {
      return;
    }
    setState(() => _loadingNotes.add(version));
    try {
      final notes = await _versionService.fetchReleaseNotes(version);
      if (!mounted) return;
      setState(() {
        _notesCache[version] = notes;
        _loadingNotes.remove(version);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notesCache[version] = null;
        _loadingNotes.remove(version);
      });
    }
  }

  void _loadSelectedReleaseNotes() {
    final version = widget.selectedRelease?.version;
    if (!mounted || version == null || version.trim().isEmpty) {
      return;
    }
    _loadReleaseNotes(version);
  }

  String _formatPublishedAt(String value) {
    final normalized = value.trim();
    if (normalized.length >= 10) {
      return normalized.substring(0, 10);
    }
    return normalized;
  }
}
