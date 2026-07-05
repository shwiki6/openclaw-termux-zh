# Project Instructions

- Build and release only the Android `arm64-v8a` APK for this project.
- Do not generate or publish `universal`, `armeabi-v7a`, `x86_64`, or AAB artifacts unless the user explicitly asks for them.
- Install Codex and Claude CLI tools inside the Ubuntu rootfs with dedicated prefixes under `/opt/openclaw-cli/<tool>` and wrapper scripts in `/usr/local/bin`.
- Do not switch Codex/Claude installation back to plain `npm install -g`; npm global rename operations are fragile under Android proot and can fail with stale `.claude-*` or `.codex-*` directories.
- Prefer domestic mirrors for tool installation defaults, especially `https://registry.npmmirror.com` for npm.
