import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import 'admin_repository.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});
  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  late Future<Map<String, dynamic>> dashboard;
  late Future<List<Map<String, dynamic>>> queue;

  @override
  void initState() {
    super.initState();
    final repository = ref.read(adminRepositoryProvider);
    dashboard = repository.dashboard();
    queue = repository.queue();
  }

  void reload() {
    final repository = ref.read(adminRepositoryProvider);
    setState(() {
      dashboard = repository.dashboard();
      queue = repository.queue();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(adminRepositoryProvider).isStaff) {
      return const Scaffold(
        body: Center(child: Text('This area is restricted.')),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SVNLY ADMIN'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'DASHBOARD'),
              Tab(text: 'MODERATION'),
            ],
          ),
        ),
        body: TabBarView(children: [_dashboard(), _queue()]),
      ),
    );
  }

  Widget _dashboard() => FutureBuilder<Map<String, dynamic>>(
    future: dashboard,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: OutlinedButton(
            onPressed: reload,
            child: const Text('TRY AGAIN'),
          ),
        );
      }
      final value = snapshot.data ?? const {};
      return RefreshIndicator(
        onRefresh: () async => reload(),
        child: GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: 2,
          childAspectRatio: 1.15,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            _Metric(
              'USERS TODAY',
              value['active_users_today'] ?? 0,
              Icons.people_outline,
            ),
            _Metric(
              'TAKES TODAY',
              value['takes_today'] ?? 0,
              Icons.videocam_outlined,
            ),
            _Metric(
              'UPLOAD FAILURES',
              value['upload_failures'] ?? 0,
              Icons.cloud_off_outlined,
            ),
            _Metric(
              'OPEN REPORTS',
              value['open_reports'] ?? 0,
              Icons.flag_outlined,
            ),
            _Metric(
              'UNDER REVIEW',
              value['under_review'] ?? 0,
              Icons.policy_outlined,
            ),
            _Metric('SUSPENDED', value['suspended_users'] ?? 0, Icons.block),
          ],
        ),
      );
    },
  );

  Widget _queue() => FutureBuilder<List<Map<String, dynamic>>>(
    future: queue,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: OutlinedButton(
            onPressed: reload,
            child: const Text('TRY AGAIN'),
          ),
        );
      }
      final items = snapshot.data ?? const [];
      if (items.isEmpty) {
        return const Center(child: Text('Moderation queue is clear.'));
      }
      return ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Card(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: ListTile(
              leading: CircleAvatar(child: Text('${item['priority']}')),
              title: Text('${item['target_type']} · ${item['source']}'),
              subtitle: Text(item['target_id'] as String),
              trailing: PopupMenuButton<String>(
                onSelected: (decision) =>
                    _decide(item['queue_id'] as String, decision),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'publish',
                    child: Text('Publish / Clear'),
                  ),
                  PopupMenuItem(
                    value: 'review',
                    child: Text('Keep under review'),
                  ),
                  PopupMenuItem(value: 'remove', child: Text('Remove')),
                  PopupMenuItem(value: 'suspend', child: Text('Suspend user')),
                  PopupMenuItem(value: 'ban', child: Text('Ban user')),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  Future<void> _decide(String queueId, String decision) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(decision.toUpperCase()),
        content: TextField(
          controller: controller,
          maxLength: 500,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Required moderation reason',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.length < 3) return;
    await ref.read(adminRepositoryProvider).decide(queueId, decision, reason);
    reload();
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label;
  final Object value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: SvnlyColors.lime),
          const Spacer(),
          Text('$value', style: Theme.of(context).textTheme.headlineLarge),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}
