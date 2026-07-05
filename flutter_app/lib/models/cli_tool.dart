import 'package:flutter/material.dart';

class CliToolDefinition {
  final String id;
  final String name;
  final String packageName;
  final String executable;
  final String description;
  final IconData icon;
  final Color color;
  final String installCommand;
  final String launchCommand;
  final String versionCommand;

  const CliToolDefinition({
    required this.id,
    required this.name,
    required this.packageName,
    required this.executable,
    required this.description,
    required this.icon,
    required this.color,
    required this.installCommand,
    required this.launchCommand,
    required this.versionCommand,
  });
}

class CliToolStatus {
  final CliToolDefinition tool;
  final bool installed;
  final String? version;
  final String? error;

  const CliToolStatus({
    required this.tool,
    required this.installed,
    this.version,
    this.error,
  });
}
