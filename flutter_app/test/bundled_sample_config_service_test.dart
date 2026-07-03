import 'package:flutter_test/flutter_test.dart';
import 'package:openclaw/services/bundled_sample_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BundledSampleConfigService.loadForVersion', () {
    test('generates Android recommended config when bundled sample is absent',
        () async {
      final sample = await BundledSampleConfigService.loadForVersion(
        '2099.1.1',
      );

      expect(sample, isNotNull);
      expect(sample!.generated, isTrue);
      expect(sample.version, '2099.1.1');
      expect(sample.assetPath, 'generated://recommended-android-openclaw.json');

      final config = sample.config;
      final gateway = config['gateway'] as Map<String, dynamic>;
      final auth = gateway['auth'] as Map<String, dynamic>;
      final nodes = gateway['nodes'] as Map<String, dynamic>;
      final allowCommands = nodes['allowCommands'] as List<dynamic>;
      final agents = config['agents'] as Map<String, dynamic>;
      final defaults = agents['defaults'] as Map<String, dynamic>;
      final discovery = config['discovery'] as Map<String, dynamic>;
      final mdns = discovery['mdns'] as Map<String, dynamic>;
      final meta = config['meta'] as Map<String, dynamic>;

      expect(gateway['mode'], 'local');
      expect(gateway['bind'], 'loopback');
      expect(gateway['port'], 18789);
      expect(auth['mode'], 'token');
      expect((auth['token'] as String), hasLength(48));
      expect(defaults['workspace'], '/root/.openclaw/workspace');
      expect(mdns['mode'], 'off');
      expect(allowCommands, containsAll(['camera.snap', 'location.get']));
      expect(meta['lastTouchedVersion'], '2099.1.1');
    });
  });
}
