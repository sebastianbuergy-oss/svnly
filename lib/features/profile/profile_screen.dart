import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/design/effects.dart';
import '../../core/design/tokens.dart';
import 'my_take_card.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late Future<Map<String, dynamic>> profile;

  @override
  void initState() {
    super.initState();
    profile = ref.read(appRepositoryProvider).loadMyProfile();
  }

  void _reload() {
    ref.invalidate(myTakesProvider);
    setState(() => profile = ref.read(appRepositoryProvider).loadMyProfile());
  }

  Future<void> _edit() async {
    final changed = await context.push<bool>('/edit-profile');
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final takes = ref.watch(myTakesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('YOUR ERA'),
        actions: [
          IconButton(
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit profile',
          ),
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: NeonBackdrop(
        child: FutureBuilder<Map<String, dynamic>>(
          future: profile,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: OutlinedButton(
                  onPressed: _reload,
                  child: const Text('TRY AGAIN'),
                ),
              );
            }
            final value = snapshot.data ?? const {};
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                children: [
                  _ProfileHero(value: value, onEdit: _edit),
                  const SizedBox(height: 22),
                  _StatsRow(value: value),
                  const SizedBox(height: 24),
                  _StreakCard(value: value),
                  const SizedBox(height: 30),
                  const _SectionTitle(kicker: 'RIGHT NOW', title: 'MY TAKE'),
                  const SizedBox(height: 14),
                  takes.when(
                    loading: () => const SizedBox(
                      height: 220,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => _RetryCard(
                      onTap: () => ref.invalidate(myTakesProvider),
                    ),
                    data: (items) {
                      final today = items
                          .where((take) => take.isToday)
                          .firstOrNull;
                      if (today == null) {
                        return _EmptyTake(
                          title: 'Bro, dein Take wartet.',
                          body: '7 Sekunden. Kein Film schieben.',
                          onTap: () => context.push('/camera'),
                        );
                      }
                      return MyTakeCard(take: today, onRefresh: _reload);
                    },
                  ),
                  const SizedBox(height: 30),
                  _Badges(value: value),
                  const SizedBox(height: 30),
                  const _SectionTitle(
                    kicker: 'THE RECEIPTS',
                    title: 'TAKE HISTORY',
                  ),
                  const SizedBox(height: 14),
                  takes.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => _RetryCard(
                      onTap: () => ref.invalidate(myTakesProvider),
                    ),
                    data: (items) {
                      final history = items
                          .where((take) => !take.isToday)
                          .toList(growable: false);
                      if (history.isEmpty) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(22),
                            child: Text(
                              'Die History ist noch leer. Lowkey mysterious.',
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (final take in history) ...[
                            MyTakeCard(
                              take: take,
                              compact: true,
                              onRefresh: _reload,
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.value, required this.onEdit});
  final Map<String, dynamic> value;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final name = value['display_name'] as String? ?? 'SVNLY';
    final avatarUrl = value['avatar_url'] as String?;
    return GradientBorderCard(
      gradient: SvnlyGradients.heroPop,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: 'my-avatar',
                  child: Container(
                    width: 104,
                    height: 104,
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SvnlyGradients.heroPop,
                    ),
                    child: CircleAvatar(
                      backgroundColor: SvnlyColors.elevated,
                      backgroundImage: avatarUrl == null
                          ? null
                          : NetworkImage(avatarUrl),
                      child: avatarUrl == null
                          ? Text(
                              name.characters.first.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                color: SvnlyColors.lime,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -6),
                        child: Text(
                          name,
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(fontSize: 42, height: .86),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '@${value['username'] ?? ''}  ${_flag(value['country_code'] as String? ?? '')}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: SvnlyColors.cyan,
                        ),
                      ),
                      const SizedBox(height: 10),
                      StickerTag(
                        label: '#${value['best_rank'] ?? '—'} RANK',
                        color: SvnlyColors.lime,
                        rotation: .03,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if ((value['bio'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                value['bio'] as String,
                style: const TextStyle(fontSize: 16, color: SvnlyColors.text),
              ),
            ],
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('EDIT THE VIBE'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.value});
  final Map<String, dynamic> value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _Stat('${value['total_takes'] ?? 0}', 'TAKES', SvnlyColors.lime),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _Stat(
          '${value['followers_count'] ?? 0}',
          'FOLLOWERS',
          SvnlyColors.hotPink,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _Stat(
          '${value['following_count'] ?? 0}',
          'FOLLOWING',
          SvnlyColors.cyan,
        ),
      ),
    ],
  );
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.value});
  final Map<String, dynamic> value;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -.012,
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: SvnlyGradients.fire,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: SvnlyColors.hotPink.withValues(alpha: .3),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 48)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${value['current_streak'] ?? 0} DAY STREAK',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Best: ${value['longest_streak'] ?? 0} · Bro is cooking.',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Badges extends StatelessWidget {
  const _Badges({required this.value});
  final Map<String, dynamic> value;

  @override
  Widget build(BuildContext context) {
    final badges = value['badges'] as List<dynamic>? ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(kicker: 'COLLECT THE FLEX', title: 'BADGES'),
        const SizedBox(height: 12),
        if (badges.isEmpty)
          const Text('Dein erstes Badge ist nur sieben Sekunden entfernt.')
        else
          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: badges.indexed
                .map((entry) {
                  final raw = entry.$2;
                  final map = raw is Map
                      ? Map<String, dynamic>.from(raw)
                      : <String, dynamic>{'name': raw.toString()};
                  return StickerTag(
                    label: (map['name'] as String? ?? 'BADGE').toUpperCase(),
                    color: entry.$1.isEven
                        ? SvnlyColors.lime
                        : SvnlyColors.hotPink,
                    rotation: entry.$1.isEven ? -.035 : .035,
                  );
                })
                .toList(growable: false),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.kicker, required this.title});
  final String kicker;
  final String title;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        kicker,
        style: const TextStyle(
          color: SvnlyColors.hotPink,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.8,
        ),
      ),
      Transform.translate(
        offset: const Offset(-2, 0),
        child: Text(
          title,
          style: Theme.of(context).textTheme.displayLarge
              ?.copyWith(fontSize: 38, height: .9),
        ),
      ),
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      border: Border.all(color: color.withValues(alpha: .55)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
        ),
      ],
    ),
  );
}

class _EmptyTake extends StatelessWidget {
  const _EmptyTake({
    required this.title,
    required this.body,
    required this.onTap,
  });
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GradientBorderCard(
    gradient: SvnlyGradients.heroPop,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(body),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onTap,
            child: const Text('OKAYYY LET’S GO 😤'),
          ),
        ],
      ),
    ),
  );
}

class _RetryCard extends StatelessWidget {
  const _RetryCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: OutlinedButton(
        onPressed: onTap,
        child: const Text('RELOAD MY TAKES'),
      ),
    ),
  );
}

String _flag(String code) {
  if (code.length != 2) return code;
  return String.fromCharCodes(
    code.toUpperCase().codeUnits.map((unit) => unit + 127397),
  );
}
