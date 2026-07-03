import 'package:flutter_test/flutter_test.dart';
import 'package:openclaw/services/openclaw_version_service.dart';

void main() {
  group('OpenClawVersionService.isStableReleaseVersion', () {
    test('accepts calendar stable versions', () {
      expect(
        OpenClawVersionService.isStableReleaseVersion('2026.6.11'),
        isTrue,
      );
    });

    test('filters prerelease and test channel versions', () {
      const versions = [
        '2026.7.1-beta.1',
        '2026.6.11-rc.1',
        '2026.6.11-alpha.1',
        '2026.6.11-test.1',
        '2026.6.11-preview',
      ];

      for (final version in versions) {
        expect(
          OpenClawVersionService.isStableReleaseVersion(version),
          isFalse,
          reason: version,
        );
      }
    });
  });
}
