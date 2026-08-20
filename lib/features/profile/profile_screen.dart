import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/design/tokens.dart';

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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('PROFILE'),
      actions: [
        IconButton(
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: profile,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: OutlinedButton(
              onPressed: () => setState(
                () => profile = ref.read(appRepositoryProvider).loadMyProfile(),
              ),
              child: const Text('TRY AGAIN'),
            ),
          );
        }
        final value = snapshot.data ?? const {};
        final badges = (value['badges'] as List<dynamic>? ?? const []);
        final history = (value['take_history'] as List<dynamic>? ?? const []);
        return RefreshIndicator(
          onRefresh: () async => setState(
            () => profile = ref.read(appRepositoryProvider).loadMyProfile(),
          ),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: SvnlyColors.elevated,
                    foregroundColor: SvnlyColors.lime,
                    child: Text(
                      (value['display_name'] as String? ?? 'S').characters.first
                          .toUpperCase(),
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value['display_name'] as String? ?? '',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text(
                          '@${value['username'] ?? ''} · ${value['country_code'] ?? ''}',
                        ),
                        if ((value['bio'] as String? ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(value['bio'] as String),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Stat('${value['total_takes'] ?? 0}', 'TAKES'),
                  _Stat('${value['followers_count'] ?? 0}', 'FOLLOWERS'),
                  _Stat('${value['following_count'] ?? 0}', 'FOLLOWING'),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Stat('🔥 ${value['current_streak'] ?? 0}', 'STREAK'),
                      _Stat('${value['longest_streak'] ?? 0}', 'BEST STREAK'),
                      _Stat('#${value['best_rank'] ?? '—'}', 'BEST RANK'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('BADGES', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (badges.isEmpty)
                const Text('Your first badge is seven seconds away.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: badges
                      .map(
                        (badge) => Chip(
                          avatar: const Icon(Icons.bolt, size: 18),
                          label: Text(badge.toString()),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 24),
              Text(
                'TAKE HISTORY',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (history.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Your 7 seconds are waiting.'),
                  ),
                )
              else
                ...history.map((raw) {
                  final take = Map<String, dynamic>.from(raw as Map);
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.play_circle_outline),
                      title: Text(
                        take['challenge_title'] as String? ?? 'Daily SVNLY',
                      ),
                      subtitle: Text(take['challenge_date'] as String? ?? ''),
                      trailing: Text('#${take['rank'] ?? '—'}'),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: SvnlyColors.secondaryText,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}
