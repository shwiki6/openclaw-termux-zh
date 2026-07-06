# Open Source Source Access

This file documents how recipients can obtain source for copyleft and
system-image components distributed by generated APKs.

## PRoot, loaders, libtalloc, and libandroid-shmem

- Distributed in: generated APK path `lib/arm64-v8a/`.
- Binary files:
  - `libproot.so`
  - `libprootloader.so`
  - `libprootloader32.so`
  - `libtalloc.so`
  - `libandroid-shmem.so`
- Package source: fetched from the Termux stable package repository by
  `scripts/fetch-proot-binaries.sh`.
- Build script/config: `scripts/fetch-proot-binaries.sh` and
  `.github/workflows/flutter-build.yml`.
- Upstream package repository: https://packages.termux.dev/apt/termux-main
- PRoot upstream source: https://github.com/proot-me/proot
- libtalloc upstream source: https://talloc.samba.org/
- libandroid-shmem upstream source: https://github.com/termux/libandroid-shmem
- Local modifications: no source changes; binaries are copied or renamed into
  Android `jniLibs` packaging names.

For release builds, keep the build logs or package-index metadata showing the
exact Termux package versions used. If any local patch is added later, include
the patch and build instructions here before distributing the APK.

## Ubuntu Rootfs and apt packages

- Distributed in: optionally bundled asset
  `flutter_app/assets/bootstrap/ubuntu-base-24.04.3-base-arm64.tar.gz`, plus
  packages installed during first setup.
- Base distribution: Ubuntu Base 24.04.3 ("noble").
- License: mixed open-source package licenses.
- Source access:
  - Ubuntu package source repositories for the configured mirror.
  - Per-package copyright files inside the installed rootfs under
    `/usr/share/doc/*/copyright`.
  - Source packages can be obtained with `apt source <package>` after enabling
    matching `deb-src` entries for the selected Ubuntu mirror.
- Local modifications: apt mirror selection and setup scripts configure the
  runtime environment; package sources are not modified.

## Node.js runtime

- Distributed in: optionally bundled asset
  `flutter_app/assets/bootstrap/node-v24.14.1-linux-arm64.tar.xz`, or downloaded
  during setup from the configured mirror.
- License: MIT-style Node.js license with included third-party notices.
- Source access: https://github.com/nodejs/node and Node.js release source
  archives for the matching version.
- Local modifications: none.

## OpenClaw npm package

- Distributed in: installed at runtime into the proot environment by npm.
- Source access: npm package tarball and package metadata from the configured
  npm registry mirror or fallback official npm registry.
- Local modifications: none.

## Release Checklist

Before publishing a new APK:

- Run the build from a clean checkout.
- Record the exact Termux package versions used by
  `scripts/fetch-proot-binaries.sh`.
- Keep generated Flutter license output or dependency lock information for the
  exact resolved pub packages.
- Confirm `THIRD_PARTY_NOTICES.md` still matches bundled assets, native
  libraries, Gradle dependencies, Flutter dependencies, and runtime downloads.
