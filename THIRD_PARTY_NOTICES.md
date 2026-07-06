# Third-Party Notices

This file records third-party material used by this repository or distributed
in generated APKs. Project-owned code is licensed under the MIT License in
`LICENSE`; entries below keep their original licenses.

This is engineering compliance documentation, not legal advice. Before a public
release, regenerate notices from the exact dependency lockfile and built APK.

## Flutter SDK and Dart SDK

- Version: resolved by the build environment.
- License: BSD-style.
- Used as: Flutter application framework and Dart runtime/toolchain.
- Upstream: https://github.com/flutter/flutter and https://github.com/dart-lang/sdk
- Source for distributed binary: upstream SDK repositories and release archives.
- Modifications: none.
- Required notices: preserve upstream copyright and BSD-style license text.

## Flutter Pub Dependencies

- Version: resolved from `flutter_app/pubspec.yaml` by `flutter pub get`.
- License: package-specific; most direct dependencies are BSD-style or MIT.
- Used as: Flutter plugins and Dart libraries.
- Upstream: https://pub.dev/
- Source for distributed binary: package archives from pub.dev or mirrored pub
  package hosts.
- Modifications: none.
- Required notices: preserve each package `LICENSE`, `NOTICE`, and copyright.

Direct dependencies currently declared:

- `webview_flutter`, `webview_flutter_android`
- `dio`
- `http`
- `provider`
- `shared_preferences`
- `path_provider`
- `permission_handler`
- `url_launcher`
- `web_socket_channel`
- `cryptography`
- `google_fonts`
- `uuid`
- `camera`
- `geolocator`
- `flutter_blue_plus` 1.35.12 (BSD-3-Clause; pinned to avoid later commercial-license versions)
- `usb_serial`
- `flutter_markdown_plus`

## Termux Terminal View

- Version: v0.118.0.
- License: Apache-2.0 for the terminal-view/terminal-emulator library modules
  used by this app.
- Used as: Android native terminal UI and emulator library.
- Upstream: https://github.com/termux/termux-app
- Source for distributed binary: https://github.com/termux/termux-app/tree/v0.118.0
- Modifications: none.
- Required notices: preserve upstream license and notices.

## PRoot From Termux Packages

- Version: resolved from the Termux stable package index at build time.
- License: GPL-2.0-or-later for PRoot.
- Used as: native binary packaged as `libproot.so` plus loader files in APK
  `lib/arm64-v8a/`.
- Upstream: https://github.com/proot-me/proot
- Source for distributed binary: see `OPEN_SOURCE_SOURCES.md`.
- Modifications: renamed/copied into Android `jniLibs`; no source changes.
- Required notices: provide corresponding source for the distributed binary.

## libtalloc From Termux Packages

- Version: resolved from the Termux stable package index at build time.
- License: LGPL-3.0-or-later.
- Used as: native runtime library packaged as `libtalloc.so`.
- Upstream: https://talloc.samba.org/
- Source for distributed binary: see `OPEN_SOURCE_SOURCES.md`.
- Modifications: renamed/copied into Android `jniLibs`; no source changes.
- Required notices: provide library source and modification information.

## libandroid-shmem From Termux Packages

- Version: resolved from the Termux stable package index at build time.
- License: BSD-style.
- Used as: native runtime library packaged as `libandroid-shmem.so`.
- Upstream: https://github.com/termux/libandroid-shmem
- Source for distributed binary: see `OPEN_SOURCE_SOURCES.md`.
- Modifications: renamed/copied into Android `jniLibs`; no source changes.
- Required notices: preserve upstream license and copyright notices.

## Apache Commons Compress

- Version: 1.26.0.
- License: Apache-2.0.
- Used as: Android archive extraction dependency.
- Upstream: https://commons.apache.org/proper/commons-compress/
- Source for distributed binary: Maven Central source artifact or upstream tag.
- Modifications: none.
- Required notices: preserve Apache-2.0 license and NOTICE if present.

## XZ for Java

- Version: 1.9.
- License: public domain / XZ for Java upstream terms.
- Used as: XZ archive support.
- Upstream: https://tukaani.org/xz/java.html
- Source for distributed binary: Maven Central source artifact or upstream source.
- Modifications: none.
- Required notices: record provenance.

## zstd-jni

- Version: 1.5.6-4.
- License: BSD-style.
- Used as: Zstandard archive support.
- Upstream: https://github.com/luben/zstd-jni
- Source for distributed binary: Maven Central source artifact or upstream tag.
- Modifications: none.
- Required notices: preserve upstream license and copyright notices.

## Node.js

- Version: 24.14.1 for arm64, 22.22.2 for armv7 configuration.
- License: MIT-style Node.js license with third-party notices.
- Used as: bundled or downloaded Node.js runtime archive.
- Upstream: https://nodejs.org/
- Source for distributed binary: https://github.com/nodejs/node
- Modifications: none.
- Required notices: preserve Node.js license and included third-party notices.

## Ubuntu Base Rootfs

- Version: Ubuntu Base 24.04.3 ("noble").
- License: mixed open-source package licenses.
- Used as: bundled or downloaded Linux rootfs archive for the proot environment.
- Upstream: https://ubuntu.com/download/base
- Source for distributed binary: Ubuntu source package repositories and package
  copyright files under `/usr/share/doc/*/copyright` inside the installed rootfs.
- Modifications: apt sources are configured to domestic mirrors during setup.
- Required notices: each installed package keeps its own license terms.

## OpenClaw npm Package

- Version: selected by the user or setup flow; default recommended version is
  declared in `flutter_app/lib/models/openclaw_install_options.dart`.
- License: package-specific metadata from npm; currently treated as a runtime
  package installed by npm.
- Used as: OpenClaw CLI/runtime inside the proot environment.
- Upstream: https://www.npmjs.com/package/openclaw
- Source for distributed binary: npm package tarball and upstream package
  metadata.
- Modifications: none.
- Required notices: preserve package license and notices from the installed npm
  package.

## DejaVu Sans Mono Fonts

- Version: bundled font files in `flutter_app/assets/fonts/`.
- License: DejaVu Fonts license / Bitstream Vera derived font terms.
- Used as: terminal monospace font assets.
- Upstream: https://dejavu-fonts.github.io/
- Source for distributed binary: upstream DejaVu font release archives.
- Modifications: none.
- Required notices: preserve upstream font license and reserved notices.

## App Assets and Sample Configs

- Version: repository files under `flutter_app/assets/`.
- License: project-owned unless separately noted in the file or directory.
- Used as: app icon, resolver config, bionic bypass script, sample OpenClaw configs.
- Upstream: this repository unless otherwise noted.
- Source for distributed binary: this repository.
- Modifications: project-owned.
- Required notices: keep any per-file notices.
