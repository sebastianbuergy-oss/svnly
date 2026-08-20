import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/design/tokens.dart';
import '../../core/domain/rules.dart';
import '../../core/localization/app_strings.dart';
import '../../core/widgets/brand.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? timer;
  DateTime now = DateTime.now().toUtc();

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => now = DateTime.now().toUtc());
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  String _countdown(DateTime expiresAt) {
    final remaining = challengeRemaining(expiresAt, now);
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(remaining.inHours)}:${two(remaining.inMinutes % 60)}:${two(remaining.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final challenge = ref.watch(currentChallengeProvider);
    final completed = ref.watch(hasTakeTodayProvider);
    final strings = AppStrings.of(context);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(currentChallengeProvider);
        ref.invalidate(hasTakeTodayProvider);
      },
      child: CustomScrollView(
        slivers: [
          const SliverAppBar(
            floating: true,
            title: SvnlyWordmark(),
            actions: [
              Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    '🔥 12',
                    semanticsLabel: 'Current streak: 12 days',
                  ),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            sliver: SliverList.list(
              children: [
                challenge.when(
                  loading: () => const SizedBox(
                    height: 390,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stack) => _StateCard(
                    icon: Icons.cloud_off,
                    title: 'Challenge unavailable',
                    body: 'Pull down to try again.',
                    action: () => ref.invalidate(currentChallengeProvider),
                  ),
                  data: (item) => completed.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => _StateCard(
                      icon: Icons.refresh,
                      title: 'Participation status unavailable',
                      body: 'Try again before recording.',
                      action: () => ref.invalidate(hasTakeTodayProvider),
                    ),
                    data: (done) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: SvnlyColors.lime,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                item.category.toUpperCase(),
                                style: const TextStyle(
                                  color: SvnlyColors.background,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _countdown(item.expiresAt),
                              style: const TextStyle(
                                fontFeatures: [FontFeature.tabularFigures()],
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Text(
                          strings.today,
                          style: const TextStyle(
                            color: SvnlyColors.secondaryText,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.title(
                            Localizations.localeOf(context).languageCode,
                          ),
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(fontSize: 46),
                        ),
                        if (item
                            .description(
                              Localizations.localeOf(context).languageCode,
                            )
                            .isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            item.description(
                              Localizations.localeOf(context).languageCode,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        const RuleChips(),
                        const SizedBox(height: 28),
                        if (!done)
                          FilledButton.icon(
                            onPressed: () => context.push('/camera'),
                            icon: const Icon(Icons.videocam),
                            label: Text(strings.take),
                          )
                        else
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: SvnlyColors.success,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'DONE ✓',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(strings.moderation),
                                  const SizedBox(height: 16),
                                  OutlinedButton(
                                    onPressed: () => context.go('/feed'),
                                    child: const Text('OPEN TODAY’S FEED'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            const Icon(
                              Icons.people_alt_outlined,
                              color: SvnlyColors.secondaryText,
                            ),
                            const SizedBox(width: 8),
                            Text('${item.participantCount} takes today'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
  });
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback action;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 40, color: SvnlyColors.lime),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(body),
          const SizedBox(height: 18),
          OutlinedButton(onPressed: action, child: const Text('TRY AGAIN')),
        ],
      ),
    ),
  );
}
