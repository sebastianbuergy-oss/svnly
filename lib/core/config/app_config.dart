import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppEnvironment { local, staging, production }

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.revenueCatIosApiKey,
    required this.legalBaseUrl,
  });

  factory AppConfig.fromEnvironment() {
    const environmentName = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'local',
    );
    final environment = AppEnvironment.values.firstWhere(
      (value) => value.name == environmentName,
      orElse: () => AppEnvironment.local,
    );
    return AppConfig(
      environment: environment,
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabasePublishableKey: const String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
      ),
      revenueCatIosApiKey: const String.fromEnvironment(
        'REVENUECAT_IOS_API_KEY',
      ),
      legalBaseUrl: const String.fromEnvironment(
        'LEGAL_BASE_URL',
        defaultValue: 'https://svnly.app',
      ),
    );
  }

  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabasePublishableKey;
  final String revenueCatIosApiKey;
  final String legalBaseUrl;

  bool get hasBackendConfiguration =>
      Uri.tryParse(supabaseUrl)?.hasScheme == true &&
      supabasePublishableKey.isNotEmpty;
  bool get premiumEnabled => revenueCatIosApiKey.isNotEmpty;
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw StateError('AppConfig must be overridden in main.'),
);
