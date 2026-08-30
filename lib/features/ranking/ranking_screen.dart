import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design/tokens.dart';
import '../../core/design/effects.dart';
import '../../core/localization/app_strings.dart';

class RankingScreen extends ConsumerStatefulWidget {
  const RankingScreen({super.key});
  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends ConsumerState<RankingScreen> {
  String period = 'today';
  String scope = 'world';
  late Future<List<Map<String, dynamic>>> rankings;

  @override
  void initState() {
    super.initState();
    rankings = _load();
  }

  Future<List<Map<String, dynamic>>> _load() =>
      ref.read(appRepositoryProvider).loadRankings(period, scope);

  void _reload() {
    final next = _load();
    setState(() {
      rankings = next;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('WHO WON TODAY?'),
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: SvnlyGradients.social),
      ),
    ),
    body: NeonBackdrop(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'BRO IS\nCOOKING 🔥',
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(fontSize: 39, height: .82),
                        ),
                      ),
                      const StickerTag(
                        label: 'FLEX IT',
                        color: SvnlyColors.lime,
                        rotation: .06,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'today', label: Text('TODAY')),
                      ButtonSegment(value: 'all_time', label: Text('ALL TIME')),
                    ],
                    selected: {period},
                    onSelectionChanged: (value) {
                      period = value.first;
                      _reload();
                    },
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'friends', label: Text('Friends')),
                      ButtonSegment(value: 'country', label: Text('Country')),
                      ButtonSegment(value: 'world', label: Text('World')),
                    ],
                    selected: {scope},
                    onSelectionChanged: (value) {
                      scope = value.first;
                      _reload();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: rankings,
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
                  final items = snapshot.data ?? const [];
                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          AppStrings.of(context).noRanking,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                    );
                  }
                  Map<String, dynamic>? current;
                  for (final item in items) {
                    if (item['is_current_user'] == true) current = item;
                  }
                  final rest = items.skip(items.length >= 3 ? 3 : 0).toList();
                  return Column(
                    children: [
                      if (current != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                          child: NeonBadge(
                            label:
                                '#${current['rank']} ${scope.toUpperCase()} 🌍 · ${AppStrings.of(context).flexIt}',
                            color: SvnlyColors.orange,
                            icon: Icons.bolt,
                          ),
                        ),
                      if (items.length >= 3)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(child: _Podium(item: items[1], rank: 2)),
                              const SizedBox(width: 8),
                              Expanded(child: _Podium(item: items[0], rank: 1)),
                              const SizedBox(width: 8),
                              Expanded(child: _Podium(item: items[2], rank: 3)),
                            ],
                          ),
                        ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async => _reload(),
                          child: ListView.separated(
                            itemCount: rest.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) => _RankingRow(
                              item: rest[index],
                              fallbackRank: index + 4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Podium extends StatelessWidget {
  const _Podium({required this.item, required this.rank});
  final Map<String, dynamic> item;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final color = switch (rank) {
      1 => SvnlyColors.lime,
      2 => SvnlyColors.electricBlue,
      _ => SvnlyColors.orange,
    };
    return Transform.rotate(
      angle: rank == 1 ? 0 : (rank == 2 ? -.025 : .025),
      child: Container(
        height: rank == 1 ? 164 : 138,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: .34), SvnlyColors.deepNavy],
          ),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: .28), blurRadius: 28),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              rank == 1 ? '👑' : '#$rank',
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 8),
            Text(
              item['display_name'] as String? ?? 'SVNLY member',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            Text(
              '${item['score'] ?? 0}',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.item, required this.fallbackRank});
  final Map<String, dynamic> item;
  final int fallbackRank;

  @override
  Widget build(BuildContext context) {
    final rank = item['rank'] as int? ?? fallbackRank;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: item['is_current_user'] == true
            ? SvnlyColors.purple.withValues(alpha: .18)
            : SvnlyColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: SizedBox(
          width: 42,
          child: Text(
            '#$rank',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
        title: Text(item['display_name'] as String? ?? 'SVNLY member'),
        subtitle: Text(
          '@${item['username'] ?? ''} · ${item['country_code'] ?? ''}',
        ),
        trailing: Text(
          '${item['score'] ?? 0}',
          semanticsLabel: '${item['score'] ?? 0} ranking points',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
