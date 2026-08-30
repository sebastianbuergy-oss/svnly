import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/design/tokens.dart';
import '../../core/design/effects.dart';
import '../../core/domain/rules.dart';
import '../../core/localization/app_strings.dart';
import '../../core/widgets/brand.dart';
import '../profile/my_take_card.dart';

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
    return NeonBackdrop(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentChallengeProvider);
          ref.invalidate(hasTakeTodayProvider);
          ref.invalidate(myTakesProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: Colors.transparent,
              title: const SvnlyWordmark(),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: const Center(
                    child: NeonBadge(
                      label: '12 DAY STREAK',
                      color: SvnlyColors.orange,
                      icon: Icons.local_fire_department,
                    ),
                  ),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              sliver: SliverList.list(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          'YOOO 👀',
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(fontSize: 48, height: .82),
                        ),
                      ),
                      const StickerTag(
                        label: 'BE REAL',
                        color: SvnlyColors.hotPink,
                        rotation: .06,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
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
                      data: (done) => GradientBorderCard(
                        gradient: done
                            ? SvnlyGradients.social
                            : SvnlyGradients.hero,
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  NeonBadge(label: item.category.toUpperCase()),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: SvnlyColors.background.withValues(
                                        alpha: .72,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _countdown(item.expiresAt),
                                      style: const TextStyle(
                                        color: SvnlyColors.electricBlue,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              Text(
                                strings.today,
                                style: const TextStyle(
                                  color: SvnlyColors.lime,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.8,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                item.title(
                                  Localizations.localeOf(context).languageCode,
                                ),
                                style: Theme.of(context).textTheme.displayLarge
                                    ?.copyWith(fontSize: 54, height: .88),
                              ),
                              if (item
                                  .description(
                                    Localizations.localeOf(context)
                                        .languageCode,
                                  )
                                  .isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Text(
                                  item.description(
                                    Localizations.localeOf(context)
                                        .languageCode,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              const RuleChips(),
                              const SizedBox(height: 28),
                              if (!done) ...[
                                Center(
                                  child: Text(
                                    strings.takeTease,
                                    style: const TextStyle(
                                      color: SvnlyColors.hotPink,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Pulse(
                                  child: FilledButton.icon(
                                    key: const ValueKey('take_hero_cta'),
                                    onPressed: () => context.push('/camera'),
                                    icon: const Icon(Icons.fiber_manual_record),
                                    label: Text(strings.take),
                                  ),
                                ),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: SvnlyGradients.social,
                                    borderRadius: BorderRadius.circular(22),
                                    boxShadow: [
                                      BoxShadow(
                                        color: SvnlyColors.hotPink.withValues(
                                          alpha: .3,
                                        ),
                                        blurRadius: 30,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      StickerTag(
                                        label: strings.successTitle,
                                        color: SvnlyColors.lime,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(strings.successBody),
                                      const SizedBox(height: 16),
                                      OutlinedButton(
                                        onPressed: () => context.go('/feed'),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: Colors.white,
                                          ),
                                        ),
                                        child: const Text(
                                          'OPEN TODAY’S FEED →',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'MY TAKE',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayLarge
                                      ?.copyWith(fontSize: 38, height: .9),
                                ),
                                const SizedBox(height: 12),
                                ref
                                    .watch(myTakesProvider)
                                    .when(
                                      loading: () => const SizedBox(
                                        height: 180,
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                      error: (_, _) => OutlinedButton(
                                        onPressed: () =>
                                            ref.invalidate(myTakesProvider),
                                        child: const Text('RELOAD MY TAKE'),
                                      ),
                                      data: (takes) {
                                        final mine = takes
                                            .where((take) => take.isToday)
                                            .firstOrNull;
                                        if (mine == null) {
                                          return const Card(
                                            child: Padding(
                                              padding: EdgeInsets.all(20),
                                              child: Text(
                                                'Take received. Syncing the receipt…',
                                              ),
                                            ),
                                          );
                                        }
                                        return MyTakeCard(
                                          take: mine,
                                          onRefresh: () =>
                                              ref.invalidate(myTakesProvider),
                                        );
                                      },
                                    ),
                              ],
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
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
