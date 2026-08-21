import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../core/design/tokens.dart';
import '../core/widgets/brand.dart';
import '../features/camera/pending_upload_store.dart';
import 'providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final config = ref.read(appConfigProvider);
    if (!config.hasBackendConfiguration) {
      if (mounted) context.go('/configuration');
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    if (!(preferences.getBool('onboarding_complete') ?? false)) {
      if (mounted) context.go('/onboarding');
      return;
    }
    final repository = ref.read(appRepositoryProvider);
    if (!repository.hasSession) {
      if (mounted) context.go('/auth');
      return;
    }
    try {
      await PendingUploadStore.resume(repository);
    } catch (_) {
      // The protected local take remains queued for the next authenticated launch.
    }
    try {
      await repository.registerForPush(promptIfNeeded: false);
    } catch (_) {
      // Token refresh is retried on the next launch or notification settings change.
    }
    final profileComplete = await repository.hasCompletedProfile();
    if (mounted) context.go(profileComplete ? '/home' : '/profile-setup');
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvnlyWordmark(fontSize: 48),
          SizedBox(height: 24),
          CircularProgressIndicator(color: SvnlyColors.lime),
        ],
      ),
    ),
  );
}

class ConfigurationScreen extends ConsumerWidget {
  const ConfigurationScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(
      minimum: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          const SvnlyWordmark(fontSize: 46),
          const SizedBox(height: 18),
          Text(
            'Secure setup required',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'This build contains no embedded secrets. Add the SVNLY Supabase URL and publishable key through the approved build environment, then relaunch.',
          ),
          const SizedBox(height: 16),
          const Text(
            'Expected build values: SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.',
            style: TextStyle(color: SvnlyColors.secondaryText),
          ),
          const Spacer(flex: 2),
        ],
      ),
    ),
  );
}
