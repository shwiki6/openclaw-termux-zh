import 'package:flutter/material.dart';

import '../models/cli_tool.dart';
import 'native_bridge.dart';

class CliToolService {
  static const shellTool = CliToolDefinition(
    id: 'shell',
    name: 'Ubuntu Shell',
    packageName: 'bash',
    executable: 'bash',
    description: '打开 Ubuntu 环境的交互式 Shell。',
    icon: Icons.terminal,
    color: Colors.blueGrey,
    installCommand: '',
    launchCommand: '',
    versionCommand: 'bash --version | head -n 1',
  );

  static const codexTool = CliToolDefinition(
    id: 'codex',
    name: 'OpenAI Codex CLI',
    packageName: '@openai/codex',
    executable: 'codex',
    description: '通过 npm 安装的 OpenAI Codex 命令行工具，适配 aarch64 Ubuntu。',
    icon: Icons.auto_awesome,
    color: Colors.green,
    installCommand: _codexInstallCommand,
    launchCommand: 'exec /usr/local/bin/codex',
    versionCommand: '/usr/local/bin/codex --version',
  );

  static const claudeTool = CliToolDefinition(
    id: 'claude',
    name: 'Claude Code',
    packageName: '@anthropic-ai/claude-code',
    executable: 'claude',
    description: '通过 npm 安装的 Anthropic Claude Code CLI，适配 aarch64 Ubuntu。',
    icon: Icons.psychology,
    color: Colors.deepOrange,
    installCommand: _claudeInstallCommand,
    launchCommand: 'exec /usr/local/bin/claude',
    versionCommand: '/usr/local/bin/claude --version',
  );

  static const allTools = [
    shellTool,
    codexTool,
    claudeTool,
  ];

  static const _commonNpmInstallPrefix = r'''
set -eu
export npm_config_audit=false
export npm_config_fund=false
export npm_config_progress=false
export npm_config_update_notifier=false
export npm_config_foreground_scripts=true
export npm_config_loglevel=notice
export npm_config_cache=/tmp/npm-cache
export npm_config_tmp=/tmp/npm-tmp
export npm_config_registry=https://registry.npmmirror.com
export npm_config_include=optional
export npm_config_optional=true
export npm_config_os=linux
export npm_config_cpu=arm64
export npm_config_arch=arm64
export npm_config_platform=linux
export npm_config_unsafe_perm=true
export NODE_OPTIONS="${NODE_OPTIONS:---require /root/.openclaw/bionic-bypass.js}"
export NODE_EXTRA_CA_CERTS="${NODE_EXTRA_CA_CERTS:-/etc/ssl/certs/ca-certificates.crt}"
export DEBIAN_FRONTEND=noninteractive

echo ">>> Architecture: $(uname -m)"
echo ">>> Node: $(node --version 2>/dev/null || echo missing)"
echo ">>> npm: $(npm --version 2>/dev/null || echo missing)"

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  echo "Node.js and npm are required. Run OpenClaw setup first." >&2
  exit 1
fi

if [ "$(uname -m)" != "aarch64" ] && [ "$(uname -m)" != "arm64" ]; then
  echo "This installer is intended for aarch64/arm64 Ubuntu rootfs." >&2
  exit 1
fi

mkdir -p /root/.npm /tmp/npm-cache /tmp/npm-tmp /opt/openclaw-cli /usr/local/bin /usr/local/lib
npm config set audit false --global >/dev/null 2>&1 || true
npm config set fund false --global >/dev/null 2>&1 || true
npm config set update-notifier false --global >/dev/null 2>&1 || true
npm config set registry https://registry.npmmirror.com --global >/dev/null 2>&1 || true

ensure_node_22() {
  node -e "const major = Number(process.versions.node.split('.')[0]); process.exit(major >= 22 ? 0 : 1)" || {
    echo "Node.js >= 22 is required for Claude Code. Re-run environment setup to install the bundled Node.js 24 runtime." >&2
    exit 1
  }
}

install_cli_package() {
  tool_id="$1"
  package_name="$2"
  bin_name="$3"
  target_dir="/opt/openclaw-cli/$tool_id"
  staging_dir="$target_dir.tmp"
  previous_dir="$target_dir.prev"

  rm -rf "$staging_dir" "$previous_dir"
  mkdir -p "$staging_dir"

  npm install \
    --prefix "$staging_dir" \
    --include=optional \
    --os=linux \
    --cpu=arm64 \
    --libc=glibc \
    "$package_name@latest"

  if [ -d "$target_dir" ]; then
    mv "$target_dir" "$previous_dir"
  fi
  mv "$staging_dir" "$target_dir"
  rm -rf "$previous_dir"
  rm -f "/usr/local/bin/$bin_name"
}
''';

  static const _codexInstallCommand = _commonNpmInstallPrefix +
      r'''
echo ">>> Installing OpenAI Codex CLI from npm..."
install_cli_package codex @openai/codex codex
cat > /usr/local/bin/codex <<'OPENCLAW_CODEX_WRAPPER'
#!/bin/sh
export NODE_OPTIONS="${NODE_OPTIONS:---require /root/.openclaw/bionic-bypass.js}"
export NODE_EXTRA_CA_CERTS="${NODE_EXTRA_CA_CERTS:-/etc/ssl/certs/ca-certificates.crt}"
[ -r /root/.openclaw/cli-env.sh ] && . /root/.openclaw/cli-env.sh
exec node /opt/openclaw-cli/codex/node_modules/@openai/codex/bin/codex.js "$@"
OPENCLAW_CODEX_WRAPPER
chmod 0755 /usr/local/bin/codex
hash -r
/usr/local/bin/codex --version
echo ">>> CODEX_CLI_INSTALL_COMPLETE"
''';

  static const _claudeInstallCommand = _commonNpmInstallPrefix +
      r'''
ensure_node_22
echo ">>> Installing Claude Code from npm..."
install_cli_package claude @anthropic-ai/claude-code claude
echo ">>> Installing Claude Code musl arm64 runtime..."
npm install \
  --prefix /opt/openclaw-cli/claude \
  --include=optional \
  --os=linux \
  --cpu=arm64 \
  --libc=musl \
  @anthropic-ai/claude-code-linux-arm64-musl@latest
if [ ! -e /lib/ld-musl-aarch64.so.1 ] && command -v apt-get >/dev/null 2>&1; then
  echo ">>> Installing musl loader for Claude Code..."
  apt-get update
  apt-get install -y --no-install-recommends musl
fi
cat > /usr/local/bin/claude <<'OPENCLAW_CLAUDE_WRAPPER'
#!/bin/sh
export NODE_OPTIONS="${NODE_OPTIONS:---require /root/.openclaw/bionic-bypass.js}"
export NODE_EXTRA_CA_CERTS="${NODE_EXTRA_CA_CERTS:-/etc/ssl/certs/ca-certificates.crt}"
[ -r /root/.openclaw/cli-env.sh ] && . /root/.openclaw/cli-env.sh
node_modules=/opt/openclaw-cli/claude/node_modules
main="$node_modules/@anthropic-ai/claude-code"
musl="$node_modules/@anthropic-ai/claude-code-linux-arm64-musl/claude"
glibc="$node_modules/@anthropic-ai/claude-code-linux-arm64/claude"
if [ -x "$musl" ] && [ -e /lib/ld-musl-aarch64.so.1 ]; then
  exec "$musl" "$@"
fi
if [ -x "$main/bin/claude.exe" ]; then
  exec "$main/bin/claude.exe" "$@"
fi
if [ -x "$glibc" ]; then
  exec "$glibc" "$@"
fi
echo "Claude Code native binary is missing. Reinstall Claude from the CLI tools page." >&2
exit 127
OPENCLAW_CLAUDE_WRAPPER
chmod 0755 /usr/local/bin/claude
hash -r
/usr/local/bin/claude --version
echo ">>> CLAUDE_CLI_INSTALL_COMPLETE"
''';

  static Future<List<CliToolStatus>> checkAllStatuses() async {
    final statuses = <CliToolStatus>[];
    for (final tool in allTools) {
      statuses.add(await checkStatus(tool));
    }
    return statuses;
  }

  static Future<CliToolStatus> checkStatus(CliToolDefinition tool) async {
    if (tool.id == shellTool.id) {
      return _checkShellStatus();
    }

    final command = '''
set +e
set -o pipefail
if command -v ${tool.executable} >/dev/null 2>&1; then
  version_output="\$(${tool.versionCommand} 2>&1 | head -n 1)"
  version_status=\$?
  if [ \$version_status -eq 0 ]; then
    echo "__OPENCLAW_CLI_INSTALLED__"
    echo "\$version_output"
  else
    echo "__OPENCLAW_CLI_BROKEN__"
    echo "\$version_output"
  fi
else
  echo "__OPENCLAW_CLI_NOT_INSTALLED__"
fi
''';

    try {
      final output = await NativeBridge.runInProot(command, timeout: 30);
      final lines = output
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      final installed = lines.contains('__OPENCLAW_CLI_INSTALLED__');
      final broken = lines.contains('__OPENCLAW_CLI_BROKEN__');
      final markerIndex =
          lines.indexWhere((line) => line.startsWith('__OPENCLAW_CLI_'));
      final version = installed
          ? lines
              .skip(markerIndex + 1)
              .firstWhere((line) => !line.startsWith('__'), orElse: () => '')
          : '';
      final error = broken
          ? lines
              .skip(markerIndex + 1)
              .where((line) => !line.startsWith('__'))
              .join('\n')
          : null;
      return CliToolStatus(
        tool: tool,
        installed: installed,
        version: version.isEmpty ? null : version,
        error: error?.isEmpty == true ? null : error,
      );
    } catch (error) {
      return CliToolStatus(
        tool: tool,
        installed: false,
        error: error.toString(),
      );
    }
  }

  static Future<CliToolStatus> _checkShellStatus() async {
    try {
      final output = await NativeBridge.runInProot(
        'bash --version | head -n 1',
        timeout: 20,
      );
      final version = output
          .split('\n')
          .map((line) => line.trim())
          .firstWhere((line) => line.isNotEmpty, orElse: () => 'bash');
      return CliToolStatus(
        tool: shellTool,
        installed: true,
        version: version,
      );
    } catch (error) {
      return CliToolStatus(
        tool: shellTool,
        installed: false,
        error: error.toString(),
      );
    }
  }
}
