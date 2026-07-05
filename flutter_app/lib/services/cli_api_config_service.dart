import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cli_api_config.dart';
import 'native_bridge.dart';

class CliApiConfigService {
  static const _configPath = '/root/.openclaw/app/cli-api-config.json';
  static const _envPath = '/root/.openclaw/cli-env.sh';
  static const _codexProxyPath = '/root/.openclaw/codex-proxy.py';
  static const _codexProxyJsPath = '/root/.openclaw/codex-proxy.js';
  static const _codexProxyEnvPath = '/root/.openclaw/codex-proxy.env';
  static const _codexConfigPath = '/root/.codex/config.toml';
  static const _codexProxyBaseUrl = 'http://127.0.0.1:8787/v1';
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
    await NativeBridge.writeRootfsFile(_codexProxyPath, _buildCodexProxyPy());
    await NativeBridge.writeRootfsFile(
      _codexProxyJsPath,
      _buildCodexProxyJs(),
    );
    await NativeBridge.writeRootfsFile(
      _codexProxyEnvPath,
      _buildCodexProxyEnv(codex),
    );
    await NativeBridge.writeRootfsFile(_codexConfigPath, _buildCodexToml(codex));
    await NativeBridge.runInProot(
      'chmod 0755 $_codexProxyPath 2>/dev/null || true; '
      'chmod 0755 $_codexProxyJsPath 2>/dev/null || true; '
      'chmod 0600 $_codexProxyEnvPath 2>/dev/null || true',
      timeout: 10,
    );
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
      lines.add('export OPENAI_BASE_URL=${_shQuote(_codexProxyBaseUrl)}');
      lines.add('export CODEX_BASE_URL=${_shQuote(_codexProxyBaseUrl)}');
      lines.add(
        'export OPENCLAW_CODEX_PROXY_UPSTREAM='
        '${_shQuote(_trimTrailingSlash(codex.baseUrl.trim()))}',
      );
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
    final baseUrl = codex.baseUrl.trim().isNotEmpty ? _codexProxyBaseUrl : '';
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
        ..add('name = "OpenClaw Codex Proxy"')
        ..add('base_url = ${_tomlString(baseUrl)}')
        ..add('env_key = "OPENAI_API_KEY"')
        ..add('wire_api = "responses"')
        ..add('stream_idle_timeout_ms = 300000')
        ..add('request_max_retries = 2')
        ..add('stream_max_retries = 2');
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

  static String _buildCodexProxyEnv(CliApiConfig codex) {
    final lines = <String>[
      'OPENCLAW_CODEX_PROXY_HOST=127.0.0.1',
      'OPENCLAW_CODEX_PROXY_PORT=8787',
    ];
    final upstream = codex.baseUrl.trim();
    if (upstream.isNotEmpty) {
      lines.add(
        'OPENCLAW_CODEX_PROXY_UPSTREAM='
        '${_shQuote(_trimTrailingSlash(upstream))}',
      );
    }
    if (codex.apiKey.trim().isNotEmpty) {
      lines.add('OPENAI_API_KEY=${_shQuote(codex.apiKey.trim())}');
    }
    lines.add('');
    return lines.join('\n');
  }

  static String _trimTrailingSlash(String value) {
    var result = value.trim();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  static String _buildCodexProxyPy() {
    return r'''#!/usr/bin/env python3
import http.server
import json
import os
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ENV_FILE = Path("/root/.openclaw/codex-proxy.env")


def load_env():
    values = {}
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def config():
    values = load_env()
    upstream = (
        values.get("OPENCLAW_CODEX_PROXY_UPSTREAM")
        or os.environ.get("OPENCLAW_CODEX_PROXY_UPSTREAM")
        or ""
    ).rstrip("/")
    token = values.get("OPENAI_API_KEY") or os.environ.get("OPENAI_API_KEY") or ""
    host = values.get("OPENCLAW_CODEX_PROXY_HOST") or "127.0.0.1"
    port = int(values.get("OPENCLAW_CODEX_PROXY_PORT") or "8787")
    return upstream, token, host, port


def target_url(upstream, path):
    if not upstream:
        raise RuntimeError("OPENCLAW_CODEX_PROXY_UPSTREAM is not configured")
    upstream_path = urllib.parse.urlsplit(upstream).path.rstrip("/")
    if upstream_path.endswith("/v1") and path.startswith("/v1/"):
        return upstream + path[3:]
    return upstream + path


def send_json(handler, status, payload):
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)
    handler.wfile.flush()


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        return

    def _proxy(self):
        upstream, token, _, _ = config()
        parsed_path = urllib.parse.urlsplit(self.path).path
        if parsed_path == "/health":
            send_json(self, 200, {"ok": True, "upstream": upstream, "has_key": bool(token)})
            return

        length = int(self.headers.get("content-length", "0") or "0")
        body = self.rfile.read(length) if length else None
        try:
            req = urllib.request.Request(target_url(upstream, self.path), data=body, method=self.command)
            for key, value in self.headers.items():
                if key.lower() in {"host", "content-length", "connection", "accept-encoding", "authorization"}:
                    continue
                req.add_header(key, value)
            if token:
                req.add_header("Authorization", "Bearer " + token)
            with urllib.request.urlopen(req, timeout=300) as resp:
                self.send_response(resp.status)
                for key, value in resp.headers.items():
                    if key.lower() in {"transfer-encoding", "connection", "content-encoding"}:
                        continue
                    self.send_header(key, value)
                self.end_headers()
                while True:
                    chunk = resp.read(8192)
                    if not chunk:
                        break
                    self.wfile.write(chunk)
                    self.wfile.flush()
        except urllib.error.HTTPError as error:
            data = error.read()
            self.send_response(error.code)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        except Exception as error:
            data = str(error).encode("utf-8")
            self.send_response(502)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

    def do_GET(self):
        self._proxy()

    def do_POST(self):
        self._proxy()


if __name__ == "__main__":
    _, _, host, port = config()
    http.server.ThreadingHTTPServer((host, port), Handler).serve_forever()
''';
  }

  static String _buildCodexProxyJs() {
    return r'''#!/usr/bin/env node
const http = require("http");
const https = require("https");
const fs = require("fs");
const { URL } = require("url");

const envFile = "/root/.openclaw/codex-proxy.env";

function loadEnv() {
  const values = {};
  if (!fs.existsSync(envFile)) return values;
  for (const rawLine of fs.readFileSync(envFile, "utf8").split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#") || !line.includes("=")) continue;
    const index = line.indexOf("=");
    const key = line.slice(0, index).trim();
    let value = line.slice(index + 1).trim();
    if (
      (value.startsWith("'") && value.endsWith("'")) ||
      (value.startsWith('"') && value.endsWith('"'))
    ) {
      value = value.slice(1, -1);
    }
    values[key] = value;
  }
  return values;
}

function config() {
  const values = loadEnv();
  return {
    upstream: (
      values.OPENCLAW_CODEX_PROXY_UPSTREAM ||
      process.env.OPENCLAW_CODEX_PROXY_UPSTREAM ||
      ""
    ).replace(/\/+$/, ""),
    token: values.OPENAI_API_KEY || process.env.OPENAI_API_KEY || "",
    host: values.OPENCLAW_CODEX_PROXY_HOST || "127.0.0.1",
    port: Number(values.OPENCLAW_CODEX_PROXY_PORT || 8787),
  };
}

function targetUrl(upstream, path) {
  if (!upstream) throw new Error("OPENCLAW_CODEX_PROXY_UPSTREAM is not configured");
  const upstreamPath = new URL(upstream).pathname.replace(/\/+$/, "");
  if (upstreamPath.endsWith("/v1") && path.startsWith("/v1/")) {
    return upstream + path.slice(3);
  }
  return upstream + path;
}

function sendJson(res, status, payload) {
  const body = Buffer.from(JSON.stringify(payload));
  res.writeHead(status, {
    "content-type": "application/json",
    "content-length": body.length,
  });
  res.end(body);
}

const server = http.createServer((clientReq, clientRes) => {
  const cfg = config();
  const requestUrl = new URL(clientReq.url, `http://${cfg.host}:${cfg.port}`);
  if (requestUrl.pathname === "/health") {
    sendJson(clientRes, 200, {
      ok: true,
      upstream: cfg.upstream,
      has_key: Boolean(cfg.token),
    });
    return;
  }

  let target;
  try {
    target = new URL(targetUrl(cfg.upstream, clientReq.url));
  } catch (error) {
    sendJson(clientRes, 502, { error: String(error.message || error) });
    return;
  }

  const headers = { ...clientReq.headers };
  delete headers.host;
  delete headers.connection;
  delete headers["accept-encoding"];
  delete headers.authorization;
  if (cfg.token) headers.authorization = `Bearer ${cfg.token}`;

  const transport = target.protocol === "https:" ? https : http;
  const upstreamReq = transport.request(
    target,
    {
      method: clientReq.method,
      headers,
    },
    (upstreamRes) => {
      const responseHeaders = { ...upstreamRes.headers };
      delete responseHeaders["transfer-encoding"];
      delete responseHeaders.connection;
      delete responseHeaders["content-encoding"];
      clientRes.writeHead(upstreamRes.statusCode || 502, responseHeaders);
      upstreamRes.pipe(clientRes);
    },
  );

  upstreamReq.on("error", (error) => {
    sendJson(clientRes, 502, { error: String(error.message || error) });
  });
  clientReq.pipe(upstreamReq);
});

const cfg = config();
server.listen(cfg.port, cfg.host);
''';
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
