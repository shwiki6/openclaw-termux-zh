class OpenClawReleaseNotesZh {
  const OpenClawReleaseNotesZh._();

  // Pinned at app build time. Versions not listed here intentionally fall back
  // to the official upstream changelog text so future releases are not stale.
  static const Map<String, String> notesByVersion = {
    '2026.6.11': r'''
### 亮点
- 增强 Slack、Mattermost、私聊模型覆盖等频道控制能力，自动化和路由配置更稳定。
- 增加 `openclaw agent --message-file` 与 RAFT CLI 唤醒桥，便于文件驱动和远程唤醒。
- 官方插件分发更安全，移动端 Android 设置详情页也补充了更多配置可视化能力。

### 变更
- 网关和插件工具增加频道身份上下文、每个 Agent 的用量成本统计。
- Provider/模型目录、推理控制、加密 reasoning 等兼容更多在线模型变体。

### 修复
- 修复 Telegram、WhatsApp、Webhook、反应指令、队列更新等频道投递问题。
- 修复 Codex/Claude 回退、使用限制识别、Ollama/OpenRouter/Gemini 等 Provider 边界问题。
- 加强 TLS、非交互配置、内存产物清理和 DOMPurify 安全更新。
''',
    '2026.6.10': r'''
### 亮点
- 新增短对话自动 fast mode，短轮次可自动提速，长任务再回到普通模式。
- 改进 Zai、GLM、原生 reasoning level 的模型路由和故障转移。
- 会话切换、cron 投递和审批敏感 hook 策略更稳。

### 变更
- fast mode 状态会贯穿重试、回退、进度事件和 CLI/ACP 归一化流程。
- 模型目录可提供更准确的 Zai base URL、过载分类和原生推理控制。

### 修复
- 修复 fast mode 回退边界、重复进度事件、Codex service tier 状态归一化。
- 修复 Zai/GLM 运行时元数据、频道来源残留和 Provider 插件安装后注册表刷新问题。
''',
    '2026.6.9': r'''
### 亮点
- Telegram 富文本、Markdown、贴纸、进度草稿、表格和提及处理显著增强。
- Agent 重试、压缩后用量、历史修复、最终回复投递等恢复能力更可靠。
- Codex 增加自动插件审批、GPT-5.3 Spark OAuth 路由、远程节点 exec 动态工具。
- 官方 Provider 插件开始以独立 npm 包形式发布，Web 与移动端界面补充会话工作区和健康状态。

### 变更
- 增加 Codex Hosted Search，外部 Provider 安装和 Gateway 启动发现流程更完整。
- 增强 ClawHub 技能来源校验、OpenTelemetry 日志导出和远程节点执行能力。

### 修复
- 修复密钥泄露、内部 HTTP 覆盖、插件写入权限等安全问题。
- 修复 Telegram、WhatsApp、Mattermost、Discord 等频道回复和进度投递问题。
- 修复 Gemini CLI 代理 OAuth、Codex Spark OAuth、Bedrock embedding、CLI/TUI 输入显示等问题。
''',
    '2026.6.8': r'''
### 亮点
- Telegram 和 WhatsApp 频道投递更丰富：支持结构化富文本、表格、列表、保留换行和 ACP 绑定。
- Agent/Gateway 在私聊发送、媒体生成、自动回复、重启关闭、子代理暂停等场景恢复更稳。
- Provider/模型支持扩展到 GLM-5.2、Claude Haiku 4.5、OpenRouter/Vertex 前缀归一化和 SecretRef 鉴权。
- `/usage` 与回复 payload hook 增加内置完整 footer 渲染、默认模板和固定小数格式。

### 变更
- 增加 GLM-5.2、Claude Haiku 4.5 目录项，并规范 OpenRouter/Google Vertex 模型 ID。
- key-free 搜索 Provider 改为显式选择，避免无 API 配置时被自动启用。
- CLI-backed 会话支持 `/btw`，并正确分类 CLI 用量错误。

### 修复
- 修复 Telegram 富文本、表格、线程创建、Feishu 路由、Slack hook、媒体完成等频道问题。
- 修复 OpenAI/Anthropic replay、LM Studio thinking-off、模型浏览边界和 SecretRef 模型鉴权。
- 修复 WebChat 回滚、会话选择、iOS 前台网关重连、插件安装缺失平台包等问题。
''',
    '2026.6.6': r'''
### 亮点
- 安全边界大幅收紧，覆盖 transcript、sandbox bind、主机环境继承、MCP stdio、Codex HTTP、原生搜索和 exec 审批超时。
- Telegram 投递更安全：账号级 topic、流式文本、`/compact`、回调 API、草稿分片和未授权 DM 缓存处理更可靠。
- iMessage 增加常驻入站重启、回显标记、流式块、空闲审批发现和启动诊断。
- Browser/MCP 增加既有 CDP 会话、WebSocket 校验、Streamable HTTP loopback 和 OAuth/SSE 兼容。

### 变更
- Claude CLI commentary 会转为频道进度事件，但不会暴露内部协议细节。
- 插件、ClawHub、Memory、移动端、TUI 和模型元数据缓存有多处性能和可维护性改进。

### 修复
- 修复会话重绑后的审批残留、可见回复恢复、Codex 压缩归属、短限流重试。
- 修复 WhatsApp、Feishu、Mattermost、LINE、Discord、OpenAI Realtime 等频道和实时能力问题。
- 修复包更新、Corepack PATH、Docker store、ClawHub dry-run 和 Android 前台服务类型问题。
''',
    '2026.6.5': r'''
### 亮点
- QQBot 会在原生投递前移除模型 reasoning/thinking 脚手架，避免 `<thinking>` 泄露到频道回复。
- MCP 工具结果会在边界处规范化 resource、audio、异常 image 等块，减少 Anthropic 400 和历史污染。
- Anthropic extended-thinking 会话在 prompt-cache 过期或 Gateway 重启后恢复更可靠。
- 新增 Parallel 作为内置 `web_search` Provider，并支持 `PARALLEL_API_KEY` 发现和 onboarding。

### 变更
- Release 版本号切换为 `YYYY.M.PATCH` 月度补丁格式，六月 2026 起始版本定为 `2026.6.5`。
- Android、Swift/macOS、Docker、CodeQL、Buildx、Codex Action 等构建依赖刷新。

### 修复
- 修复 Google Vertex ADC 目录、单 Provider cooldown 恢复、Memory 状态检查。
- 修复 Matrix 语音/线程、Auth SQLite、官方 npm 插件安装记录和 prerelease 完整性回退。
- 修复 cron 迁移、service env 占位符、WhatsApp 启动等待和禁用账号卸载。
''',
    '2026.6.1': r'''
### 亮点
- Agent 和 CLI-backed runtime 对中断工具调用、陈旧会话绑定、压缩交接、媒体重试的恢复更稳。
- Telegram、WhatsApp、iMessage、Slack、Discord、Teams、Google Chat/Meet、iOS Talk 等频道和移动投递更可靠。
- Provider/插件请求增加更多超时、重试、OAuth/device-code 生命周期、媒体下载和本地服务探测边界。
- 新增 Workboard、SecretRef 插件清单、iOS push relay、外部 Copilot/Tokenjuice 包等编排能力。

### 变更
- 新增 Skill Workshop 指南、提案审核流、支持文件、回滚元数据和 Control UI 工作流。
- 外部化 Tokenjuice 与 GitHub Copilot agent runtime 官方插件。
- iOS 增加托管 push relay、realtime Talk 播放和 iPad 原生布局。

### 修复
- 修复聊天历史加载、流式 delta、Markdown 流式性能、草稿、本地 composer 和首连优先级问题。
- 修复 OpenRouter SQLite 模型缓存、OpenAI replay、iMessage SQLite 状态迁移和 CI/E2E 超时边界。
''',
    '2026.5.28': r'''
### 亮点
- Agent/Codex runtime 恢复更稳：子代理 cwd/workspace 分离、hook 上下文隔离、锁超时释放和 app-server 共享状态恢复。
- Matrix、iMessage、Slack、Discord、WhatsApp、Telegram、Teams 等频道身份和投递更安全。
- iOS Pro UI、托管 push relay、realtime Talk、Gateway chat transport、WebChat 重连和会话选择器状态保持增强。
- Browser、cron、Discord 组件 ID、Telegram callback、频道进度回调等输入校验更严格。

### 变更
- 增加活动子代理状态输出，拆分默认语言包，扩展默认 Diffs 语言覆盖。
- 增加 Claude Opus 4.8、Fal Krea 图像 schema、NVIDIA featured models、MiniMax 流式音乐和 PDF 加密提取。
- 外部化 GitHub Copilot、Tokenjuice，并加入 Codex Supervisor 插件路径。

### 修复
- 修复 CLI/auth/doctor/provider 的 malformed option、workspace dotenv 凭据、OAuth/token 生命周期和本地服务启动边界。
- 修复插件/Gateway 热路径重复扫描、缓存一致性、QA/E2E 等待和跨平台验证假阳性。
''',
    '2026.5.27': r'''
### 亮点
- 安全边界增强：群组 prompt 不再进入 system prompt，危险 Node env、无鉴权 Tailscale、命令包装副作用和设备审批权限被收紧。
- Codex app-server 运行更可靠：优先解析 runtime model、workspace memory 走工具、共享客户端在启动/辅助进程失败后保持。
- Gateway 和回复路径更快，减少 session、插件元数据、auth env、tool-search 和文件系统热路径重复发现。
- Provider 覆盖增加 OpenAI-compatible embedding、DeepInfra 完整模型浏览、Pixverse 视频、VLLM thinking、Claude CLI OAuth overlay。

### 变更
- Memory 增加核心 OpenAI-compatible embedding Provider，并补充配置、doctor 和文档。
- Pixverse、DeepInfra、ClawHub、Heartbeat 模板、Plugin SDK 和 Channel SDK 有多项功能更新。

### 修复
- 修复 Telegram、iMessage、Slack、Matrix、QQBot、Discord、Google Chat 等频道投递和审批问题。
- 修复 Codex 模型解析、workspace memory 工具路径、native hook relay、OAuth compaction 和动态工具隔离。
- 修复 npm 打包、Docker 模板、shrinkwrap、postpublish 校验和 E2E 等发布路径问题。
''',
    '2026.5.26': r'''
### 亮点
- Gateway 启动和回复更快，减少插件、频道、会话、用量、警告、计划任务和文件系统重复扫描。
- Transcript 成为核心路径，会议摘要、来源片段、媒体来源、Codex 镜像、WebChat 回复和 CLI/TUI replay 更统一。
- Telegram、iMessage、WhatsApp、Discord、Signal 等频道更接近生产可用，支持更多进度、附件、群组和反应审批场景。
- Talk 和语音能力增强，可从 Web UI 与 Discord voice 检查、引导、取消和跟进实时对话。
- Provider、Codex、本地模型、安装更新、CI、Docker、插件发布和诊断链路整体加固。

### 变更
- 增加 named model login profiles，并支持 Hermes、OpenCode、Codex 鉴权配置迁移。
- 增加 Signal/iMessage/WhatsApp 反应审批、Android pair-new-gateway、iOS Talk mode 和 Activity tab。
- Codex CLI 更新到 0.134.0，并让 OpenClaw 接管预算触发的恢复边界。

### 修复
- 修复 prompt-like memory 注入、频道投递、实时语音、更新安装、服务管理和 CI 证明链路中的大量边界问题。
''',
  };

  static String? forVersion(String version) {
    final notes = notesByVersion[version.trim()];
    final trimmed = notes?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static bool hasVersion(String version) => forVersion(version) != null;
}
