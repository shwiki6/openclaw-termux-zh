class AppConstants {
  static const String appName = '次元虾';
  static const String version = '2.0.9';
  static const String packageName = 'com.openclaw.cyx';

  /// Matches ANSI escape sequences (e.g. color codes in terminal output).
  static final ansiEscape = RegExp(r'\x1b\[[0-9;]*[a-zA-Z]');

  static const String authorName = 'JunWan';
  static const String authorEmail = 'susuya0712@gmail.com';
  static const String githubRepoLabel = 'shwiki6/openclaw-termux-zh';
  static const String githubUrl =
      'https://github.com/shwiki6/openclaw-termux-zh';
  static const String thirdPartyNoticesUrl =
      '$githubUrl/blob/main/THIRD_PARTY_NOTICES.md';
  static const String openSourceSourcesUrl =
      '$githubUrl/blob/main/OPEN_SOURCE_SOURCES.md';
  static const String license = 'MIT for project-owned code';
  static const String licenseSummary =
      'Project-owned code is MIT; third-party components keep their own licenses.';

  static const String githubApiLatestRelease =
      'https://api.github.com/repos/shwiki6/openclaw-termux-zh/releases/latest';

  // NextGenX
  static const String orgName = 'NextGenX';
  static const String orgEmail = 'susuya0712@gmail.com';
  static const String instagramUrl =
      'https://www.instagram.com/nexgenxplorer_nxg';
  static const String youtubeUrl =
      'https://youtube.com/@nexgenxplorer?si=UG-wBC8UIyeT4bbw';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/dev?id=8262374975871504599';

  static const String gatewayHost = '127.0.0.1';
  static const int gatewayPort = 18789;
  static const String gatewayUrl = 'http://$gatewayHost:$gatewayPort';

  static const String ubuntuBaseMirrorUrl =
      'https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.3-base-';
  static const String ubuntuBaseMirrorFallbackUstcUrl =
      'https://mirrors.ustc.edu.cn/ubuntu-cdimage/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.3-base-';
  static const String ubuntuBaseMirrorFallbackAliyunUrl =
      'https://mirrors.aliyun.com/ubuntu-cdimage/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.3-base-';
  static const String ubuntuBaseOfficialUrl =
      'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.3-base-';
  static const String ubuntuRootfsUrl = ubuntuBaseMirrorUrl;
  static const String ubuntuCodename = 'noble';
  static const String bundledBootstrapAssetDir = 'assets/bootstrap';
  static const String rootfsArm64 = '${ubuntuRootfsUrl}arm64.tar.gz';
  static const String rootfsArmhf = '${ubuntuRootfsUrl}armhf.tar.gz';
  static const String rootfsAmd64 = '${ubuntuRootfsUrl}amd64.tar.gz';
  static const String prebuiltRootfsPrefix = 'openclaw-rootfs-$ubuntuCodename';

  // Node.js binary tarball is downloaded by Flutter and extracted by Java.
  // Bypasses curl/gpg/NodeSource which fail inside proot.
  static const String nodeVersion = '24.14.1';
  static const String nodeArmv7Version = '22.22.2';
  static const String openClawEstimatedSize = '~95 MB';
  static const String nodeMirrorBaseUrl =
      'https://npmmirror.com/mirrors/node/v$nodeVersion/node-v$nodeVersion-linux-';
  static const String nodeOfficialBaseUrl =
      'https://nodejs.org/dist/v$nodeVersion/node-v$nodeVersion-linux-';
  static const String nodeBaseUrl = nodeMirrorBaseUrl;
  static const String npmRegistryUrl = 'https://registry.npmmirror.com';
  static const String npmRegistryFallbackUrl = 'https://registry.npmjs.org';
  static const String npmNodeDistUrl = 'https://npmmirror.com/mirrors/node';
  static const String basicResourceReleaseBaseUrl =
      'https://github.com/JunWan666/openclaw-termux-zh/releases/download/basic-resource';
  static const String basicResourcePrebuiltRootfsArm64 =
      '$basicResourceReleaseBaseUrl/openclaw-rootfs-$ubuntuCodename-arm64.tar.gz';
  static const String basicResourceUbuntuRootfsArm64 =
      '$basicResourceReleaseBaseUrl/ubuntu-base-24.04.3-base-arm64.tar.gz';
  static const String basicResourceNodeArm64 =
      '$basicResourceReleaseBaseUrl/node-v$nodeVersion-linux-arm64.tar.xz';

  static bool isArmv7Arch(String arch) {
    final normalized = arch.trim().toLowerCase();
    return normalized == 'arm' ||
        normalized == 'armv7l' ||
        normalized == 'armeabi-v7a' ||
        normalized == 'armhf';
  }

  static String getNodeVersionForArch(String arch) {
    if (isArmv7Arch(arch)) {
      return nodeArmv7Version;
    }
    return nodeVersion;
  }

  static String getNodeTarballUrl(String arch) {
    return getNodeTarballUrlForVersion(arch, getNodeVersionForArch(arch));
  }

  static String getNodeTarballUrlForVersion(String arch, String version) {
    return getNodeTarballUrlCandidatesForVersion(arch, version).first;
  }

  static List<String> getNodeTarballUrlCandidates(String arch) {
    return getNodeTarballUrlCandidatesForVersion(
      arch,
      getNodeVersionForArch(arch),
    );
  }

  static List<String> getNodeTarballUrlCandidatesForVersion(
    String arch,
    String version,
  ) {
    final mirrorBaseUrl =
        'https://npmmirror.com/mirrors/node/v$version/node-v$version-linux-';
    final officialBaseUrl =
        'https://nodejs.org/dist/v$version/node-v$version-linux-';

    String suffix;

    switch (arch) {
      case 'aarch64':
        suffix = 'arm64.tar.xz';
        break;
      case 'arm':
        suffix = 'armv7l.tar.xz';
        break;
      case 'x86_64':
        suffix = 'x64.tar.xz';
        break;
      default:
        suffix = 'arm64.tar.xz';
    }

    return [
      '$mirrorBaseUrl$suffix',
      '$officialBaseUrl$suffix',
    ];
  }

  static String bundledBootstrapAssetPathForUrl(String url) {
    final uri = Uri.parse(url);
    final fileName = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    return '$bundledBootstrapAssetDir/$fileName';
  }

  static String ubuntuRootfsArchiveArch(String arch) {
    final normalized = arch.trim().toLowerCase();
    if (normalized == 'aarch64' ||
        normalized == 'arm64' ||
        normalized == 'arm64-v8a') {
      return 'arm64';
    }
    if (isArmv7Arch(normalized)) {
      return 'armhf';
    }
    if (normalized == 'x86_64' || normalized == 'amd64') {
      return 'amd64';
    }
    return 'arm64';
  }

  static String prebuiltRootfsAssetPathForArch(String arch) {
    final rootfsArch = ubuntuRootfsArchiveArch(arch);
    return '$bundledBootstrapAssetDir/$prebuiltRootfsPrefix-$rootfsArch.tar.gz';
  }

  static bool isUbuntuPortsArch(String arch) {
    switch (arch) {
      case 'aarch64':
      case 'arm':
        return true;
      default:
        return false;
    }
  }

  static List<String> ubuntuMirrorCandidates(String arch) {
    final isPorts = isUbuntuPortsArch(arch);
    final paths = isPorts
        ? <String>[
            'http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports',
            'http://mirrors.ustc.edu.cn/ubuntu-ports',
            'http://mirrors.aliyun.com/ubuntu-ports',
            'http://ports.ubuntu.com/ubuntu-ports',
          ]
        : <String>[
            'http://mirrors.tuna.tsinghua.edu.cn/ubuntu',
            'http://mirrors.ustc.edu.cn/ubuntu',
            'http://mirrors.aliyun.com/ubuntu',
            'http://archive.ubuntu.com/ubuntu',
          ];
    return paths;
  }

  static String buildUbuntuSourcesList(String baseUrl) {
    final suites = <String>[
      ubuntuCodename,
      '$ubuntuCodename-updates',
      '$ubuntuCodename-backports',
      '$ubuntuCodename-security',
    ];
    final buffer = StringBuffer();
    for (final suite in suites) {
      buffer.writeln(
        'deb $baseUrl $suite main restricted universe multiverse',
      );
    }
    return buffer.toString();
  }

  static const int healthCheckIntervalMs = 5000;
  static const int maxAutoRestarts = 5;

  // Node constants
  static const int wsReconnectBaseMs = 350;
  static const double wsReconnectMultiplier = 1.7;
  static const int wsReconnectCapMs = 8000;
  static const String nodeRole = 'node';
  static const int pairingTimeoutMs = 300000;

  static const String channelName = 'com.openclaw.cyx/native';
  static const String eventChannelName =
      'com.openclaw.cyx/gateway_logs';
  static const String setupLogEventChannelName =
      'com.openclaw.cyx/setup_logs';

  static String getRootfsUrl(String arch) {
    return getRootfsUrlCandidates(arch).first;
  }

  static List<String> getRootfsUrlCandidates(String arch) {
    String suffix;
    switch (arch) {
      case 'aarch64':
        suffix = 'arm64.tar.gz';
        break;
      case 'arm':
        suffix = 'armhf.tar.gz';
        break;
      case 'x86_64':
        suffix = 'amd64.tar.gz';
        break;
      default:
        suffix = 'arm64.tar.gz';
    }

    return [
      '$ubuntuBaseMirrorUrl$suffix',
      '$ubuntuBaseMirrorFallbackUstcUrl$suffix',
      '$ubuntuBaseMirrorFallbackAliyunUrl$suffix',
      '$ubuntuBaseOfficialUrl$suffix',
    ];
  }
}
