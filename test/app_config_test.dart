import 'package:flutter_test/flutter_test.dart';
import 'package:svnly/core/config/app_config.dart';

void main() {
  test('backend configuration requires URL and publishable key', () {
    const valid = AppConfig(
      environment: AppEnvironment.production,
      supabaseUrl: 'https://example.supabase.co',
      supabasePublishableKey: 'sb_publishable_example',
      revenueCatIosApiKey: '',
      premiumReleaseEnabled: false,
      legalBaseUrl: 'https://svnly.app',
    );
    const missingKey = AppConfig(
      environment: AppEnvironment.production,
      supabaseUrl: 'https://example.supabase.co',
      supabasePublishableKey: '',
      revenueCatIosApiKey: '',
      premiumReleaseEnabled: false,
      legalBaseUrl: 'https://svnly.app',
    );

    expect(valid.hasBackendConfiguration, isTrue);
    expect(missingKey.hasBackendConfiguration, isFalse);
  });

  test(
    'premium requires both release approval and RevenueCat configuration',
    () {
      const free = AppConfig(
        environment: AppEnvironment.local,
        supabaseUrl: '',
        supabasePublishableKey: '',
        revenueCatIosApiKey: '',
        premiumReleaseEnabled: false,
        legalBaseUrl: 'https://svnly.app',
      );
      const unapproved = AppConfig(
        environment: AppEnvironment.production,
        supabaseUrl: '',
        supabasePublishableKey: '',
        revenueCatIosApiKey: 'appl_example',
        premiumReleaseEnabled: false,
        legalBaseUrl: 'https://svnly.app',
      );
      const premium = AppConfig(
        environment: AppEnvironment.production,
        supabaseUrl: '',
        supabasePublishableKey: '',
        revenueCatIosApiKey: 'appl_example',
        premiumReleaseEnabled: true,
        legalBaseUrl: 'https://svnly.app',
      );

      expect(free.premiumEnabled, isFalse);
      expect(unapproved.premiumEnabled, isFalse);
      expect(premium.premiumEnabled, isTrue);
    },
  );
}
