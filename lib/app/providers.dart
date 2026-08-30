import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../features/auth/app_repository.dart';
import '../features/auth/supabase_repository.dart';
import '../features/challenge/models.dart';

final appRepositoryProvider = Provider<AppRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.hasBackendConfiguration) return const UnconfiguredRepository();
  return SupabaseAppRepository(Supabase.instance.client);
});

final currentChallengeProvider = FutureProvider<DailyChallenge>((ref) {
  return ref.watch(appRepositoryProvider).currentChallenge();
});

final hasTakeTodayProvider = FutureProvider<bool>((ref) {
  return ref.watch(appRepositoryProvider).hasTakeToday();
});

final feedProvider = FutureProvider.family<List<FeedTake>, String>((
  ref,
  scope,
) {
  return ref.watch(appRepositoryProvider).loadFeed(scope);
});

final myTakesProvider = FutureProvider<List<MyTake>>((ref) {
  return ref.watch(appRepositoryProvider).loadMyTakes();
});
