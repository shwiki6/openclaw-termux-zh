# OpenClaw Termux 中文版 — 源码结构文档

> 版本：v2.0.2+77 | 协议：MIT | 更新日期：2026-07-03
>
> 本文档用于二次开发前的源码理解，按"从外到内"的方式组织：先看项目全貌，再逐层深入。本文已按当前工作区源码重新核对。

---

## 目录

1. [项目总览](#1-项目总览)
2. [技术栈](#2-技术栈)
3. [目录结构总览](#3-目录结构总览)
4. [Flutter 应用层详细分析](#4-flutter-应用层详细分析)
5. [Node.js 运行时层详细分析](#5-nodejs-运行时层详细分析)
6. [Android 原生层详细分析](#6-android-原生层详细分析)
7. [核心数据流](#7-核心数据流)
8. [国际化和中文本地化](#8-国际化和中文本地化)
9. [构建与发布流程](#9-构建与发布流程)
10. [二次开发路线图](#10-二次开发路线图)

---

## 1. 项目总览

### 1.1 它解决什么问题

在 Android 手机上运行一个完整的 AI 代理网关（OpenClaw Gateway），不需要：
- Root 权限
- Termux App
- 外部云服务器

核心思路：通过 **PRoot** 在 Android 上运行一个隔离的 Ubuntu RootFS，里面部署 Node.js 和 OpenClaw，再由 Flutter App 提供 Android 原生 UI 控制。

### 1.2 三大技术层

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter 应用层                          │
│   UI / 状态管理 / 安装向导 / 终端模拟 / 配置编辑器           │
│   语言：Dart（29 个 Screen + 30 个 Service + 9 个 Capability）│
├─────────────────────────────────────────────────────────┤
│                 MethodChannel 桥接                        │
│   Flutter → Kotlin 方法调用 + EventChannel 事件流         │
├─────────────────────────────────────────────────────────┤
│                  Android 原生层                           │
│   PRoot 管理 / 进程管理 / 前台 Service / 权限 / 硬件       │
│   语言：Kotlin（14 个核心文件）                              │
├─────────────────────────────────────────────────────────┤
│                    PRoot 隔离环境                         │
│              ┌──────────────────────┐                      │
│              │   Ubuntu RootFS      │                      │
│              │   ├── Node.js 24.x   │                      │
│              │   └── OpenClaw CLI   │                      │
│              │   /root/.openclaw/   │                      │
│              └──────────────────────┘                      │
└─────────────────────────────────────────────────────────┘
```

### 1.3 仓库来源

| 角色 | 仓库 |
|---|---|
| 上游（Android 集成） | `mithun50/openclaw-termux`（1634 ⭐） |
| 汉化基础 | `TIANLI0/openclaw-termux` `feature/translation` 分支 |
| 核心引擎 | `openclaw/openclaw` |
| 本仓库（中文整合） | `JunWan666/openclaw-termux-zh`（187 ⭐，MIT） |

---

## 2. 技术栈

| 层 | 技术 | 版本/说明 |
|---|---|---|
| App 框架 | Flutter | SDK >=3.2.0 |
| UI 组件库 | Material Design 3 | `useMaterial3: true` |
| 状态管理 | Provider | `provider: ^6.1.0` |
| 终端模拟 | xterm + flutter_pty | `xterm: ^4.0.0` |
| Web 面板 | webview_flutter | `^4.4.0` |
| 网络请求 | dio + http | `dio: ^5.4.0` |
| WebSocket | web_socket_channel | `^3.0.0` |
| 硬件能力 | camera, geolocator, flutter_blue_plus, usb_serial | 多插件 |
| 本地存储 | shared_preferences + path_provider | |
| 加密 | cryptography | `^2.7.0` |
| 前端渲染 | flutter_markdown_plus | `^1.0.7` |
| Android 原生 | Kotlin | |
| 隔离环境 | PRoot | 无需 Root 的 chroot 替代 |
| 运行时 | Node.js >= 22.19.0 | 32/64 位 ARM + x86_64；按 `openclaw@latest` engines 校验 |
| CLI 引擎 | OpenClaw latest stable | 多渠道 AI 网关，推荐版本跟随 npm latest 稳定版 |

当前版本默认运行时策略：

- `arm64` / `x86_64`：Node.js `24.14.1`。
- `armeabi-v7a` / `armhf`：Node.js `22.22.2`，用于避开 Node.js 24 不再提供官方 `linux-armv7l` 包的问题。
- `openclaw@latest` 当前为 `2026.6.11`，要求 Node.js `>=22.19.0`，以上两个 Node.js 版本均满足。
- APK 不再内置大体积 `assets/bootstrap/` 运行时包，初始化时从默认资源、用户填写 URL 或本地压缩包导入。
- App 品牌当前为“小龙虾”，Android `applicationId` / `namespace` / MethodChannel 包名为 `com.openclaw.xlx`。

---

## 3. 目录结构总览

```
openclaw-termux-zh/
│
├── flutter_app/                          # ★ Flutter Android 应用
│   ├── android/                          # Android 原生配置
│   │   └── app/src/main/
│   │       ├── AndroidManifest.xml       # 权限、Service 声明
│   │       ├── kotlin/.../MainActivity.kt # MethodChannel 宿主
│   │       ├── kotlin/.../BootstrapManager.kt  # 安装管理
│   │       ├── kotlin/.../GatewayService.kt     # Gateway 进程管理
│   │       ├── kotlin/.../NodeForegroundService.kt  # 节点前台服务
│   │       ├── kotlin/.../TerminalSessionService.kt  # 终端 PTY
│   │       ├── kotlin/.../SetupService.kt       # 安装进度通知
│   │       ├── kotlin/.../ProcessManager.kt     # PRoot 进程管理
│   │       └── kotlin/.../*ForegroundService.kt  # 其他前台服务
│   ├── lib/
│   │   ├── main.dart                      # 入口
│   │   ├── app.dart                       # App 主题、颜色、多 Provider
│   │   ├── constants.dart                 # 全局常量（端口、URL、镜像列表等）
│   │   ├── l10n/                           # 国际化（中/英/日/繁中）
│   │   ├── models/                         # 数据模型
│   │   ├── providers/                      # 状态管理（4 个 Provider）
│   │   ├── screens/                        # 页面（29 个 Screen）
│   │   ├── services/                       # 业务服务（30 个 Service）
│   │   │   └── capabilities/               # 设备能力（9 个 Capability）
│   │   └── widgets/                        # 可复用组件（5 个）
│   ├── assets/                            # 资源文件
│   └── pubspec.yaml                       # Flutter 依赖配置
│
├── lib/                                   # ★ Node.js CLI 运行时
│   ├── index.js                           # CLI 入口
│   ├── installer.js                       # 安装器逻辑
│   ├── bionic-bypass.js                   # Android Bionic 绕过
│   ├── postinstall.js                     # 安装后钩子
│   └── test.js                            # 自检脚本
│
├── bin/openclawx                          # CLI 入口脚本（shebang）
│
├── scripts/                               # 构建脚本
│   ├── build_release.py                   # 发布打包（版本号、构建号管理）
│   ├── build-apk.sh                       # APK 构建
│   ├── build-prebuilt-rootfs.sh           # RootFS 预构建
│   └── fetch-proot-binaries.sh            # 下载 PRoot 二进制
│
├── release/                               # 各版本发布说明
├── docs/                                  # 补充文档
├── assets/                                # README 截图/图标
├── package.json                           # Node.js 依赖
├── .github/workflows/flutter-build.yml     # CI/CD
├── install.sh                             # 一键安装脚本
├── CHANGELOG.md
├── README.md
└── LICENSE
```

---

## 4. Flutter 应用层详细分析

### 4.1 入口与主题

**`main.dart`** — 极简入口，启动 `OpenClawApp`。

**`app.dart`**（355 行）— 整个应用的核心骨架：

- **`AppColors`**：集中管理的颜色系统（品牌色 `#DC2626`、暗/亮主题背景、状态色）
- **`MultiProvider`**：注入 4 个顶层状态管理：
  - `LocaleProvider` — 语言切换
  - `SetupProvider` — 安装状态
  - `GatewayProvider` — Gateway 生命周期
  - `NodeProvider`（Proxy）— 节点连接，依赖 GatewayProvider
- **双主题**：`_buildDarkTheme()` + `_buildLightTheme()`，均使用 Material 3 + Google Fonts Inter

### 4.2 常量定义（`constants.dart`）

集中管理所有"魔法值"：
- MethodChannel / EventChannel 名称
- App 名称、包名、运行时版本
- Gateway 默认端口 `18789`
- 默认 Gateway 主机地址
- Ubuntu 镜像候选列表（含国内镜像）
- Ubuntu 版本代号
- WebSocket 重连参数（指数退避基数、倍数、上限）
- ANSI 转义正则
- APK 下载 URL 模板

### 4.3 数据模型（`models/`，9 个文件）

| 模型文件 | 核心类型 | 说明 |
|---|---|---|
| `gateway_state.dart` | `GatewayState`, `GatewayStatus` | Gateway 运行状态（stopped/starting/running/error）+ 日志 |
| `node_state.dart` | `NodeState`, `NodeStatus` | 节点连接状态（disabled/disconnected/connecting/challenging/pairing/paired/error） |
| `node_frame.dart` | `NodeFrame` | WebSocket 帧编解码（JSON 格式，含 id/type/command/params） |
| `ai_provider.dart` | `AiProvider` | AI 提供商元数据（OpenAI/Anthropic/Gemini/自定义） |
| `custom_provider_preset.dart` | `CustomProviderPreset` | 用户自定义提供商预设，含可选 `thinking` 推理强度 |
| `message_platform.dart` | `MessagePlatform` | 消息平台（QQ/Telegram/Discord/WhatsApp） |
| `openclaw_install_options.dart` | `OpenClawInstallOptions`, `OpenClawReleaseInfo` | 安装选项 + 版本信息 |
| `optional_package.dart` | `OptionalPackage` | 可选组件（llama.cpp/CPolar/SSH 等） |
| `setup_state.dart` | `SetupState`, `SetupStep`, `SetupStatus` | 安装流程状态机 |

### 4.4 状态管理（`providers/`，4 个文件）

#### `LocaleProvider`
- 管理当前语言（`zh-Hans`/`zh-Hant`/`en`/`ja`）
- 持久化到 `shared_preferences`

#### `SetupProvider`
- 封装 `BootstrapService`，驱动安装向导
- `checkIfSetupNeeded()` → `runSetup()` 两步流程
- 通过 `onProgress` 回调实时更新安装状态

#### `GatewayProvider`
- 封装 `GatewayService`，控制 Gateway 启停
- 监听 `GatewayState` 流，自动同步状态
- `applyConfigChanges()` → 通知 Gateway 热加载配置

#### `NodeProvider`（最复杂，324 行）
- 管理 Android 设备作为 OpenClaw 节点的完整生命周期
- **能力注册**：注册 8 种硬件能力（Camera/Flash/Location/Screen/Sensor/Serial/Vibration/Canvas）
- **前台 Service 管理**：`NativeBridge.startNodeService()` / `stopNodeService()`
- **WebSocket 长连接**：通过 `NodeService` 与 Gateway 通信
- **保活机制**：
  - 45 秒 Watchdog 定时器检测连接是否过期（90 秒无数据判定 stale）
  - App 前后台切换时自动重连
  - 指数退避重连策略
- **权限管理**：主动请求 Camera/Location/Sensors/Bluetooth 权限

### 4.5 页面（`screens/`，29 个文件）

按导航关系组织：

```
SplashScreen                    # 启动页（判断是否需要初始化）
    │
    ├── SetupWizardScreen        # ★ 安装向导（1539 行，最大页面）
    │       │
    │       ├── 预构建资源配置页
    │       ├── 版本选择
    │       ├── AI 提供商配置
    │       └── 安装进度展示
    │
    └── DashboardScreen          # ★ 主控面板（465 行）
            │
            ├── 顶部：Gateway 控制卡片
            │       ├── 启动/停止 Gateway
            │       └── 打开 Web 面板
            │
            ├── 快捷操作区
            │       ├── 终端（TerminalScreen）
            │       ├── 本地模型（LocalModelScreen）
            │       ├── 备份中心（BackupManagerScreen）
            │       └── 日志（LogsScreen）
            │
            ├── 配置管理
            │       ├── ProvidersScreen → ProviderDetailScreen
            │       │       └── CustomProviderDetailScreen
            │       ├── MessagePlatformsScreen → MessagePlatformDetailScreen
            │       ├── PackagesScreen → PackageInstallScreen
            │       └── ConfigEditorScreen
            │
            ├── 网络穿透
            │   └── CpolarScreen
            │
            ├── 节点能力
            │   └── NodeScreen
            │
            ├── SSH
            │   └── SshScreen
            │
            ├── 设置
            │   └── SettingsScreen
            │
            └── Web 面板
                └── WebDashboardScreen
```

**关键页面详解：**

| 页面 | 行数 | 核心职责 |
|---|---|---|
| `setup_wizard_screen.dart` | 1539 | 安装流程编排、下载/解压/配置进度 |
| `local_model_screen.dart` | 1557 | 本地模型总览（llama.cpp + GGUF） |
| `local_model_chat_screen.dart` | 1459 | 本地模型流式对话 UI |
| `logs_screen.dart` | 1243 | 结构化日志查看、搜索、复制 |
| `message_platform_detail_screen.dart` | 1048 | 单个消息平台的详细配置 |
| `local_model_chat_settings_screen.dart` | 792 | 本地模型聊天参数（上下文长度/线程数等） |
| `command_shortcuts_screen.dart` | 865 | 快捷命令列表 |
| `web_dashboard_screen.dart` | 880 | 内置 WebView 加载 Gateway 面板 |

### 4.6 服务层（`services/`，28 个文件 + 9 个能力）

按职责分组：

**安装与环境（Bootstrap）：**
| 服务 | 行数 | 职责 |
|---|---|---|
| `bootstrap_service.dart` | 1093 | ★ 核心安装编排：RootFS 下载→解压→Node.js 安装→OpenClaw 安装→Bionic Bypass |
| `openclaw_version_service.dart` | 814 | 获取可用 OpenClaw 版本列表 |
| `install_status_message_formatter.dart` | 378 | 安装状态中文文案格式化 |
| `bundled_sample_config_service.dart` | 56 | 提供示例配置 |

**Gateway 生命周期：**
| 服务 | 行数 | 职责 |
|---|---|---|
| `gateway_service.dart` | 827 | Gateway 启停、日志流、健康检查、配置热加载 |
| `gateway_auth_config_service.dart` | 202 | Gateway 认证配置读写 |
| `dashboard_url_resolver.dart` | 114 | Dashboard URL 解析（本地/局域网） |

**节点通信：**
| 服务 | 行数 | 职责 |
|---|---|---|
| `node_service.dart` | 488 | WebSocket 连接管理、能力调度、请求/响应路由 |
| `node_ws_service.dart` | 150 | WebSocket 底层（含指数退避重连） |
| `node_identity_service.dart` | 103 | 设备唯一 ID 生成与持久化 |

**本地模型：**
| 服务 | 行数 | 职责 |
|---|---|---|
| `local_model_service.dart` | 2379 | ★ 最复杂服务：模型管理、llama.cpp 启动、运行时统计 |
| `local_model_chat_service.dart` | 1061 | 本地模型对话流式输出 |
| `online_model_catalog_service.dart` | 387 | 在线模型目录获取 |

**消息平台：**
| 服务 | 行数 | 职责 |
|---|---|---|
| `message_platform_config_service.dart` | 449 | QQ/Telegram/Discord/WhatsApp 配置管理 |
| `cpolar_package_service.dart` | 1081 | CPolar 内网穿透集成 |

**备份与数据：**
| 服务 | 行数 | 职责 |
|---|---|---|
| `backup_service.dart` | 293 | 备份创建/恢复 |
| `backup_library_service.dart` | 206 | 备份库管理 |
| `snapshot_service.dart` | 212 | 配置快照 |
| `preferences_service.dart` | 202 | 用户偏好持久化 |

**原生桥接：**
| 服务 | 行数 | 职责 |
|---|---|---|
| `native_bridge.dart` | 367 | ★ 唯一的 MethodChannel 封装，所有 Kotlin 调用的入口 |
| `terminal_service.dart` | 197 | 终端 PTY 会话管理 |
| `screenshot_service.dart` | 44 | 屏幕截图 |

### 4.7 设备能力系统（`services/capabilities/`）

9 种能力，每个能力文件包含：
- `name` — 能力标识
- `commands` — 支持的命令列表
- `handle()` / `handleWithPermission()` — 命令处理函数

| 能力 | 权限需求 | 状态 |
|---|---|---|
| `camera_capability.dart` | Camera | ✅ |
| `flash_capability.dart` | 无（Camera 权限已覆盖） | ✅ |
| `location_capability.dart` | Location | ✅ |
| `screen_capability.dart` | 屏幕录制（系统弹窗授权） | ✅ |
| `sensor_capability.dart` | Sensors | ✅ |
| `serial_capability.dart` | Bluetooth + USB | ✅ |
| `vibration_capability.dart` | 无 | ✅ |
| `canvas_capability.dart` | — | ⏳ NOT_IMPLEMENTED |

### 4.8 组件（`widgets/`）

| 组件 | 行数 | 用途 |
|---|---|---|
| `gateway_controls.dart` | 1006 | Gateway 启停按钮、状态指示、日志预览（复用最多） |
| `terminal_toolbar.dart` | 202 | 终端工具栏（字体大小、颜色、全屏） |
| `node_controls.dart` | 183 | 节点连接/断开按钮 |
| `progress_step.dart` | 262 | 安装步骤进度条 |
| `status_card.dart` | 72 | 状态卡片容器 |

---

## 5. Node.js 运行时层详细分析

### 5.1 目录结构

```
lib/                                   # OpenClaw CLI 核心源码
├── index.js                           # CLI 主入口（命令路由）
├── installer.js                       # 安装器（下载/解压/配置 OpenClaw）
├── bionic-bypass.js                   # ★ Android Bionic 绕过层
├── postinstall.js                     # 安装后钩子
└── test.js                            # 自检脚本

bin/
└── openclawx                          # CLI 入口 shebang 脚本

package.json                           # 依赖：chalk + inquirer + ora（仅 3 个）
```

### 5.2 核心逻辑

**`bionic-bypass.js`** — 最关键的文件。Android 使用 Bionic libc 而非 glibc，导致许多 Linux 二进制不兼容。该文件实现了：
- `LD_LIBRARY_PATH` 重定向
- 必要的 Bionic 兼容库注入
- 使 Node.js 和 OpenClaw 在 Android 上正常运行

**`index.js`** — CLI 命令路由：
- 解析 `process.argv`
- 分发到对应的子命令处理器
- 支持：`gateway run` / `chat` / `tui` / `dashboard` / `status` / `configure` / `config` 等

**`installer.js`** — 安装逻辑：
- 下载 OpenClaw 发布包
- 解压到 `/root/.openclaw/`
- 配置 `openclaw.json`
- 设置 PATH

### 5.3 与 Flutter 层的协作

Flutter 层通过 `NativeBridge.runInProot(command)` 执行 Node.js 命令，相当于在 PRoot 环境里远程操作 CLI：

```
Flutter (Dart)
  → MethodChannel.invokeMethod('runInProot', {command: 'openclaw gateway run'})
  → Kotlin (ProcessManager)
    → PRoot 执行
      → /root/.openclaw/node-wrapper.js openclaw gateway run
        → Node.js (lib/index.js)
          → Gateway 启动（HTTP + WebSocket 服务）
```

---

## 6. Android 原生层详细分析

### 6.1 Kotlin 文件总览

| 文件 | 行数（估） | 职责 |
|---|---|---|
| `MainActivity.kt` | ~200 | MethodChannel 注册、事件通道、权限处理 |
| `BootstrapManager.kt` | ~500 | RootFS 下载/解压、Node.js 安装、Bionic Bypass |
| `GatewayService.kt` | ~400 | OpenClaw Gateway 进程管理（启动/停止/重启） |
| `NodeForegroundService.kt` | ~300 | 节点 WebSocket 长连接的前台 Service |
| `TerminalSessionService.kt` | ~250 | PTY 终端会话管理 |
| `SetupService.kt` | ~200 | 安装进度通知 Service |
| `ProcessManager.kt` | ~300 | PRoot 进程生命周期管理 |
| `CpolarForegroundService.kt` | ~200 | CPolar 内网穿透 |
| `SshForegroundService.kt` | ~150 | SSH 服务 |
| `LocalModelForegroundService.kt` | ~200 | 本地模型（llama.cpp）推理服务 |
| `ScreenCaptureService.kt` | ~150 | 屏幕录制 |
| `GatewayLogPersistence.kt` | ~100 | Gateway 日志持久化 |
| `HostFilesystem.kt` | ~100 | PRoot 文件系统操作 |
| `ArchUtils.kt` | ~80 | CPU 架构检测 |

### 6.2 MethodChannel 接口映射

Flutter `NativeBridge` 中的每个方法对应一个 Kotlin 处理函数：

| Flutter 调用 | Kotlin 处理 | 功能 |
|---|---|---|
| `runInProot` | ProcessManager | 在 PRoot 中执行命令 |
| `extractRootfs` | BootstrapManager | 解压 RootFS tar.gz |
| `extractNodeTarball` | BootstrapManager | 解压 Node.js |
| `installBionicBypass` | BootstrapManager | 安装 Bionic 绕过 |
| `startGateway` / `stopGateway` | GatewayService | Gateway 进程管理 |
| `startTerminalService` | TerminalSessionService | PTY 终端 |
| `startNodeService` | NodeForegroundService | 节点连接 Service |
| `startSetupService` | SetupService | 安装通知 |
| `writeRootfsFile` | HostFilesystem | 写 PRoot 内文件 |
| `readRootfsFile` | HostFilesystem | 读 PRoot 内文件 |
| `startCpolarService` | CpolarForegroundService | 内网穿透 |
| `startSshd` / `stopSshd` | SshForegroundService | SSH |
| `startLocalModelService` | LocalModelForegroundService | 本地模型推理 |

### 6.3 AndroidManifest 关键声明

- **权限**：Camera / Location / Sensors / Bluetooth / Storage / Foreground Service / Wake Lock / Internet
- **前台 Service**：6 个（Gateway / Node / Terminal / Setup / CPolar / SSH / LocalModel）
- **导出 Activity**：`MainActivity`（处理 URL  scheme 跳转）

---

## 7. 核心数据流

### 7.1 安装流程

```
用户打开 App
  → SplashScreen（检查是否已初始化）
    → 已初始化 → DashboardScreen
    → 未初始化 → SetupWizardScreen
        │
        ├── Step 1: 选择预构建资源（RootFS/Node.js）
        │   ├── 使用 GitHub 默认资源
        │   ├── 自定义 URL
        │   └── 本地文件
        │
        ├── Step 2: 选择 OpenClaw 版本
        │   └── openclaw_version_service.fetchAvailableReleases()
        │
        ├── Step 3: 下载 RootFS（dio 带进度）
        │   ├── 探测最快 Ubuntu 镜像
        │   ├── 下载 tar.gz
        │   └── 解压到 PRoot 目录
        │
        ├── Step 4: 安装 Node.js
        │   ├── 下载 Node.js tarball
        │   └── 解压到 /usr/local/
        │
        ├── Step 5: 安装 OpenClaw
        │   ├── npm install -g openclaw
        │   └── 创建 node-wrapper.js 兼容脚本
        │
        ├── Step 6: 配置 Bionic Bypass
        │   └── 写入 LD_LIBRARY_PATH 等环境变量
        │
        └── Step 7: 完成 → 跳转到 DashboardScreen
```

### 7.2 Gateway 生命周期

```
DashboardScreen → 点击"启动 Gateway"
  → GatewayProvider.start()
    → GatewayService.start()
      → NativeBridge.startGateway()
        → Kotlin: GatewayService.kt 启动进程
          → PRoot 中执行: openclaw gateway run
            → Node.js: Gateway 启动 HTTP (18789) + WebSocket
      ← 监听日志流（EventChannel）
      ← 健康检查（轮询 /health）
    ← GatewayState 更新（status: running, dashboardUrl）
  → UI 更新：显示 Dashboard URL + 状态指示
```

### 7.3 节点连接流程

```
DashboardScreen → 开启"节点能力"
  → NodeProvider.enable()
    → 请求权限（Camera/Location/Sensors/Bluetooth）
    → 请求关闭电池优化
    → NativeBridge.startNodeService()
      → Kotlin: 启动前台 Service（保活）
    → NodeService.connect()
      → NodeWsService.connect(host, port)
        → WebSocket 连接到 Gateway
          → Gateway 发送 challenge
          ← 节点响应 challenge
          → 配对成功 → NodeStatus.paired
    → 注册 8 种设备能力
    → 45 秒 Watchdog 开始工作
```

### 7.4 本地模型推理流程

```
LocalModelScreen → 下载/选择 GGUF 模型
  → NativeBridge 下载模型到 PRoot
  → 点击"启动"
    → LocalModelService.startModel()
      → NativeBridge.startLocalModelService()
        → Kotlin: 启动 llama.cpp 前台 Service
          → PRoot 中执行: llama-server -m model.gguf --port 8080
      ← 监听运行时统计（内存/速度/TPS）
    ← 模型状态更新
  → 进入对话页
    → WebView / 直接 HTTP 调用 llama-server API
    → 流式输出响应
```

---

## 8. 国际化和中文本地化

### 8.1 支持的语言

| 语言代码 | 文件 | 大小 |
|---|---|---|
| `en` | `app_strings_en.dart` | ~59 KB |
| `zh-Hans`（简体） | `app_strings_zh_hans.dart` | ~66 KB |
| `zh-Hant`（繁体） | `app_strings_zh_hant.dart` | ~39 KB |
| `ja`（日文） | `app_strings_ja.dart` | ~46 KB |

### 8.2 使用方式

```dart
// 在 UI 中获取翻译
context.l10n.t('appName')           // → "OpenClaw"
context.l10n.t('gateway.start')     // → "启动网关"
```

### 8.3 二次开发加翻译

1. 在 `app_strings_zh_hans.dart`（及其他语言文件）中添加键值对
2. 在 `app_localizations.dart` 中注册新键
3. 使用 `context.l10n.t('your.new.key')` 调用

---

## 9. 构建与发布流程

### 9.1 环境要求

- Flutter SDK >= 3.2.0
- Android SDK（NDK 支持多架构）
- Node.js >= 18（用于 CLI 部分）
- Python 3（用于构建脚本）
- bash（用于 `scripts/fetch-proot-binaries.sh` 等脚本）

当前工作区核对结果：

- `node` / `npm` 可用，本机 Node.js 为 `v24.14.1`。
- 当前 shell 环境未找到 `flutter` / `dart`，因此本机暂不能直接运行 Flutter 测试或 APK 构建。
- 当前目录不是 Git 仓库；二次开发前建议先初始化 Git 或重新 clone 上游仓库。
- 项目根目录尚未安装 `node_modules` 时，`npm run lint` 会因为找不到 `eslint` 失败；普通文件系统先执行 `npm install` 或 `npm ci`。
- 如果项目位于 Android 共享存储（如 `/storage/emulated/0/...`），该文件系统通常不支持 npm 创建 `.bin` symlink；请使用 `npm ci --no-bin-links`，再用 `node node_modules/eslint/bin/eslint.js . --no-warn-ignored` 运行 lint。

### 9.2 APK 构建

```bash
# 方式 1：标准 Flutter 构建
cd flutter_app && flutter pub get && flutter build apk --release

# 方式 2：使用发布脚本（自动管理版本号）
python scripts/build_release.py --version 2.0.2 --build-number 77
```

### 9.2.1 本地验证命令

```bash
# Node CLI 自检
npm test

# Node CLI 语法检查
node --check lib/index.js

# 普通文件系统：安装 Node 依赖后再运行 lint
npm ci
npm run lint

# Android 共享存储 / Termux：避免 .bin symlink 权限错误
npm ci --no-bin-links
node node_modules/eslint/bin/eslint.js . --no-warn-ignored

# Flutter 依赖、静态检查和测试
cd flutter_app
flutter pub get
flutter analyze
flutter test
```

本轮已验证：

- `npm test`：通过，11 passed / 0 failed。
- `node --check lib/index.js`：通过。
- `node node_modules/eslint/bin/eslint.js . --no-warn-ignored`：通过。
- 乱码扫描：`lib/`、`flutter_app/lib/`、`flutter_app/android/app/src/main/kotlin/`、`scripts/` 未再发现本轮定位到的误编码片段。

未验证：

- `flutter analyze` / `flutter test` / APK 构建，因为当前环境缺少 `flutter` 和 `dart` 命令。

### 9.3 RootFS 预构建

```bash
bash scripts/build-prebuilt-rootfs.sh
# 输出：带 Ubuntu RootFS + Node.js 的压缩包
```

### 9.4 CI/CD

`.github/workflows/flutter-build.yml` — GitHub Actions 自动构建多架构 APK。

### 9.5 APK 分发包

| 文件名 | ABI | 大小 |
|---|---|---|
| `OpenClaw-v2.0.2-universal.apk` | 全架构 | ~46 MB |
| `OpenClaw-v2.0.2-arm64-v8a.apk` | 64 位 ARM | ~28 MB |
| `OpenClaw-v2.0.2-armeabi-v7a.apk` | 32 位 ARM | ~27 MB |
| `OpenClaw-v2.0.2-x86_64.apk` | x86_64 | ~28 MB |
| `OpenClaw-v2.0.2.aab` | 全架构 | ~53 MB |

---

## 10. 二次开发路线图

### 10.1 快速理解路径（建议顺序）

```
1. app.dart          — 5 分钟，理解主题和 Provider 骨架
2. constants.dart    — 5 分钟，熟悉所有"魔法值"
3. native_bridge.dart — 10 分钟，看懂 Flutter ↔ Kotlin 的接口
4. providers/        — 15 分钟，理解状态管理的数据流
5. bootstrap_service.dart — 20 分钟，理解安装流程
6. gateway_service.dart   — 15 分钟，理解 Gateway 控制
7. node_service.dart      — 15 分钟，理解节点通信
8. lib/bionic-bypass.js   — 10 分钟，理解 Android 兼容层
```

### 10.2 常见二次开发方向

#### A. 添加新页面

1. 在 `screens/` 下创建 `your_feature_screen.dart`
2. 在 `app.dart` 或 Dashboard 中添加导航入口
3. 如需新 Service，在 `services/` 下创建

#### B. 添加新设备能力（Capability）

1. 在 `services/capabilities/` 下创建 `your_capability.dart`
2. 实现 `name`、`commands`、`handle()` / `handleWithPermission()`
3. 在 `NodeProvider._registerCapabilities()` 中注册
4. 在 AndroidManifest 中添加对应权限
5. 在 Kotlin 层实现对应的能力处理（如果需要原生能力）

#### C. 添加新 AI 提供商

1. 在 `models/ai_provider.dart` 中补充提供商元数据
2. 在 `provider_config_service.dart` 中添加配置模板
3. 在 `providers_screen.dart` / `provider_detail_screen.dart` 中确认展示和编辑逻辑
4. 在 `l10n/app_strings_zh_hans.dart` 等语言文件中添加翻译
5. 为地址归一化、保存、迁移或连接测试补充对应测试

#### C1. 扩展自定义模型参数

当前自定义模型提供商已支持可选推理强度：

1. UI 位于 `custom_provider_detail_screen.dart`，选项来自 `customProviderThinkingLevels`。
2. 保存时写入 `models.providers.<providerId>.models[0].thinking`，留空会移除该字段。
3. OpenClaw 侧 canonical key 是 `thinking`，并兼容 `effort` / `reasoning_effort` / `thought_level` 等别名；应用侧统一写 `thinking`。
4. 支持值：`off`、`minimal`、`low`、`medium`、`high`、`xhigh`、`adaptive`、`max`。不支持该能力的模型会忽略或由 OpenClaw 报错。

#### D. 修改安装流程

1. 修改 `bootstrap_service.dart` 中的 `_overallProgressFor()` 和步骤逻辑
2. 如需新的下载源，在 `constants.dart` 中添加 URL 模板
3. OpenClaw 推荐版本默认跟随 npm latest 稳定版；如果 latest 是 beta/rc/test，会回退到可用稳定版本。
4. 首次安装完成后会提示写入 Android 推荐预配置，入口在 `BundledSampleConfigService`，用于跳过终端里难懂的 onboard 初始问题；API Key/Base URL/模型仍应由“AI 提供商”页面填写。
5. 如需新的系统操作，在 `native_bridge.dart` 添加方法 + Kotlin 层实现

#### E. 修改主题/UI

1. 颜色：修改 `app.dart` 中的 `AppColors`
2. 字体：修改 `GoogleFonts` 调用
3. 组件样式：修改对应 `widgets/` 文件
4. 暗/亮模式：已支持，按 `ThemeMode.system` 自动切换

#### F. 添加新语言

1. 复制 `app_strings_en.dart` 为新语言文件
2. 在 `app_localizations.dart` 中注册新 locale
3. 在 `app.dart` 的 `supportedLocales` 中添加

#### G. 新增 Flutter 到 Kotlin 的原生能力

1. 在 `native_bridge.dart` 中添加 Dart 封装方法。
2. 在 `MainActivity.kt` 的 `MethodChannel` 分支中添加同名方法。
3. 如果是长运行任务，优先实现独立 `ForegroundService`，不要把耗时逻辑阻塞在 `MainActivity`。
4. 如需权限，在 `AndroidManifest.xml` 声明，并在 UI 或 Provider 层触发运行时权限申请。
5. 为纯 Dart 逻辑补测试；Kotlin/Android 逻辑至少用真机手测启动、停止、异常恢复。

#### H. 修改 PRoot / Gateway 启动行为

1. 安装期短命令看 `ProcessManager.buildInstallCommand()`。
2. Gateway 长驻进程看 `ProcessManager.buildGatewayCommand()` 和 `GatewayService.startGateway()`。
3. DNS、bind mount、fake proc/sys 相关改动风险较高，修改后要验证 setup、终端、Gateway、本地模型四条链路。
4. 不要随意移除 `env -i`、`PROOT_LOADER`、`LD_LIBRARY_PATH`、`NODE_OPTIONS=--require /root/.openclaw/bionic-bypass.js`。

### 10.3 开发注意事项

| 注意事项 | 说明 |
|---|---|
| **PRoot 环境有限** | 不是完整 Linux，某些系统调用不可用 |
| **前台 Service 保活** | Android 会杀死后台进程，长时间运行必须用前台 Service |
| **权限动态请求** | Android 6+ 需要运行时权限，代码中已有处理模式可参考 |
| **WebSocket 保活** | 需 45 秒 Watchdog + 90 秒 Stale 检测 + 指数退避重连 |
| **大文件下载** | 用 dio 的 `onReceiveProgress` 回调，不要用 `compute()` |
| **Kotlin 层修改后重编** | 改了 MethodChannel 对应的方法后需重编 APK |
| **Bionic Bypass 敏感** | 不要轻易修改，影响 Node.js 运行稳定性 |
| **Git 历史缺失** | 当前是 zip 解压，无 git 历史，建议重新 `git init` 并关联上游 |
| **MethodChannel 名称要一致** | Dart `NativeBridge` 与 Kotlin `MainActivity` 必须使用同一个方法名和参数结构 |
| **版本号多处同步** | `package.json`、`flutter_app/pubspec.yaml`、`constants.dart`、README、release 文档需要同时核对 |
| **移动端性能约束** | 大量终端输出要走 `TerminalOutputBuffer`，避免逐字符刷新 UI |
| **国际化不能只改中文** | 新 UI 文案至少同步简中、繁中、英文、日文，避免缺键 |

### 10.4 推荐的开发 Workflow

```bash
# 1. 初始化 git
cd openclaw-termux-zh
git init
git add .
git commit -m "chore: initial import from zip v2.0.2"

# 2. 关联上游（可选，方便拉取更新）
git remote add upstream https://github.com/JunWan666/openclaw-termux-zh.git

# 3. Flutter 热重载开发
cd flutter_app
flutter pub get
flutter run  # 连接真机

# 4. 构建调试 APK
flutter build apk --debug

# 5. 构建发布 APK
flutter build apk --release --split-per-abi
```

建议每次功能开发按以下顺序收口：

1. 先跑 `npm test` 和相关 Dart 单元测试。
2. 有 Flutter SDK 时跑 `flutter analyze`。
3. 涉及 Kotlin、权限、前台服务、PRoot 的改动必须真机验证。
4. 涉及安装流程的改动至少验证一次全新安装和一次已有环境升级。
5. 涉及文案或页面入口的改动同步更新 `README.md`、`CHANGELOG.md` 或 release 文档。

### 10.5 远程构建 / 测试服务器

本地 Termux/Android 共享存储不适合完成所有构建与测试，特别是 Flutter SDK、Android SDK、Gradle 缓存、symlink、APK 打包等场景。后续可使用一台 x86 Ubuntu 服务器作为远程构建机。

凭据处理规则：

- 不要把服务器口令、SSH 私钥、Gitee 令牌写入仓库、脚本、README、`STRUCTURE.md` 或 `.git/config`。
- 临时口令只在当前会话或本机安全密码管理器中使用。
- Gitee 令牌只放环境变量、系统凭据管理器，或在 Git 交互提示中作为密码输入。
- `.env`、`.env.local` 已被 `.gitignore` 忽略，但仍不建议长期保存高权限令牌。

推荐远程构建流程：

```bash
# 本机：把源码同步到远程构建机，排除缓存和本地产物
rsync -az --delete \
  --exclude node_modules \
  --exclude flutter_app/build \
  --exclude flutter_app/.dart_tool \
  --exclude flutter_app/android/.gradle \
  ./ "$BUILD_SERVER_USER@$BUILD_SERVER_HOST:~/openclaw-termux-zh/"

# 远程：进入项目后安装依赖并验证
ssh "$BUILD_SERVER_USER@$BUILD_SERVER_HOST"
cd ~/openclaw-termux-zh
npm ci
npm test
npm run lint
cd flutter_app
flutter pub get
flutter analyze
flutter test

# 远程：构建 APK / AAB
cd ~/openclaw-termux-zh
python scripts/build_release.py --version 2.0.2 --build-number 77
```

远程构建机首次准备建议：

```bash
sudo apt update
sudo apt install -y git curl unzip xz-utils zip openjdk-17-jdk python3 rsync

# Flutter / Android SDK 建议安装在用户目录或 /opt，并把 flutter/bin 加入 PATH。
flutter doctor
flutter doctor --android-licenses
```

### 10.6 Gitee 版本提交

后续版本管理以 Gitee 为主。建议优先使用 SSH remote；如果必须用 HTTPS + 令牌，避免把令牌拼进 remote URL。

```bash
# 初始化仓库
git init
git add .
git commit -m "chore: import openclaw termux zh v2.0.2"

# 推荐：SSH remote，不在仓库配置中保存令牌
git remote add origin git@gitee.com:<owner>/<repo>.git
git push -u origin main

# HTTPS remote 也不要包含 token
git remote add origin https://gitee.com/<owner>/<repo>.git
git push -u origin main
# 交互提示密码时再输入 Gitee 令牌
```

发布前建议检查：

```bash
git status --short
git diff --check
npm test
npm run lint
cd flutter_app && flutter analyze && flutter test
```

### 10.7 本轮已修复问题

| 问题 | 处理 |
|---|---|
| `lib/index.js` CLI 输出存在误编码字符 | 已重写为稳定 ASCII 文案，避免终端乱码 |
| `weixin_installer_screen.dart` 中 box drawing 正则为误编码字符 | 已改为真实 Unicode 范围 `\u2500-\u257F` 等 |
| Kotlin / Dart 注释中存在误编码字符 | 已改为可读 ASCII 注释 |
| 本地验证说明缺失 | 已补充 Node、Flutter、lint、APK 构建的验证命令和当前环境限制 |
| `bionic_bypass.js` 存在 ESLint 未使用变量 | 已将 `catch (e)` 改为 `catch`，并同步修复生成模板 |

---

## 附：关键文件快速索引

| 需求 | 看这个文件 |
|---|---|
| 了解整体架构 | `app.dart` + 本文档 |
| 改颜色/字体 | `app.dart` (`AppColors` / `_buildDarkTheme`) |
| 改安装流程 | `services/bootstrap_service.dart` |
| 改 Gateway 控制 | `services/gateway_service.dart` |
| 改节点通信 | `services/node_service.dart` + `node_ws_service.dart` |
| 加新页面 | `screens/dashboard_screen.dart`（看导航结构） |
| 加新能力 | `services/capabilities/` 下任选一个作模板 |
| 改中文文案 | `lib/l10n/app_strings_zh_hans.dart` |
| 加新 AI 提供商 | `models/ai_provider.dart` + `services/provider_config_service.dart` |
| 改终端行为 | `services/terminal_service.dart` |
| 改本地模型 | `services/local_model_service.dart` |
| 新增 Kotlin 方法 | `flutter_app/android/.../MainActivity.kt` + `native_bridge.dart` |
| 改 PRoot 行为 | `android/.../ProcessManager.kt` + `lib/bionic-bypass.js` |
