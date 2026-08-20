import 'package:flutter_test/flutter_test.dart';
import 'package:svnly/core/config/app_config.dart';

void main() {
  test('backend configuration requires URL and publishable key', () {
    const valid = AppConfig(
      environment: AppEnvironment.production,
      supabaseUrl: 'https://example.supabase.co',
      supabasePublishableKey: 'sb_publishable_example',
      revenueCatIosApiKey: '',
      legalBaseUrl: 'https://svnly.app',
    );
    const missingKey = AppConfig(
      environment: AppEnvironment.production,
      supabaseUrl: 'https://example.supabase.co',
      supabasePublishableKey: '',
      revenueCatIosApiKey: '',
      legalBaseUrl: 'https://svnly.app',
    );

    expect(valid.hasBackendConfiguration, isTrue);
    expect(missingKey.hasBackendConfiguration, isFalse);
  });

  test('premium is feature-gated by RevenueCat configuration', () {
    const free = AppConfig(
      environment: AppEnvironment.local,
      supabaseUrl: '',
      supabasePublishableKey: '',
      revenueCatIosApiKey: '',
      legalBaseUrl: 'https://svnly.app',
    );
    const premium = AppConfig(
      environment: AppEnvironment.production,
      supabaseUrl: '',
      supabasePublishableKey: '',
      revenueCatIosApiKey: 'appl_example',
      legalBaseUrl: 'https://svnly.app',
    );

    expect(free.premiumEnabled, isFalse);
    expect(premium.premiumEnabled, isTrue);
  });
}
