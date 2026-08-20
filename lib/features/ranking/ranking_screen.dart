import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design/tokens.dart';
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

  void _reload() => setState(() => rankings = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('RANKING')),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
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
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final rank = item['rank'] as int? ?? index + 1;
                      return ListTile(
                        leading: SizedBox(
                          width: 42,
                          child: Text(
                            '#$rank',
                            style: TextStyle(
                              color: rank <= 3
                                  ? SvnlyColors.lime
                                  : SvnlyColors.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        title: Text(
                          item['display_name'] as String? ?? 'SVNLY member',
                        ),
                        subtitle: Text(
                          '@${item['username'] ?? ''} · ${item['country_code'] ?? ''}',
                        ),
                        trailing: Text(
                          '${item['score'] ?? 0}',
                          semanticsLabel:
                              '${item['score'] ?? 0} ranking points',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
