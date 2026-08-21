import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/design/tokens.dart';
import '../../core/widgets/brand.dart';

class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('LANGUAGE')),
    body: ListView(
      children: [
        ListTile(
          leading: Localizations.localeOf(context).languageCode == 'en'
              ? const Icon(Icons.check_circle, color: SvnlyColors.lime)
              : const Icon(Icons.circle_outlined),
          title: const Text('English'),
          onTap: () async {
            await ref
                .read(appRepositoryProvider)
                .updateSetting('language_code', 'en');
          },
        ),
        ListTile(
          leading: Localizations.localeOf(context).languageCode == 'de'
              ? const Icon(Icons.check_circle, color: SvnlyColors.lime)
              : const Icon(Icons.circle_outlined),
          title: const Text('Deutsch'),
          onTap: () async {
            await ref
                .read(appRepositoryProvider)
                .updateSetting('language_code', 'de');
          },
        ),
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'The selected language is synced to your account and applies after the app restarts.',
          ),
        ),
      ],
    ),
  );
}

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsState();
}

class _NotificationSettingsState
    extends ConsumerState<NotificationSettingsScreen> {
  final values = <String, bool>{
    'daily_challenge_push': true,
    'streak_push': true,
    'reaction_push': true,
    'comment_push': true,
    'follower_push': true,
    'moderation_push': true,
    'product_news_push': false,
  };
  static const labels = {
    'daily_challenge_push': 'Daily Challenge',
    'streak_push': 'Streak Reminder',
    'reaction_push': 'Reactions',
    'comment_push': 'Comments',
    'follower_push': 'Followers',
    'moderation_push': 'Moderation',
    'product_news_push': 'Product News',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('NOTIFICATIONS')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'SVNLY asks for system notification permission only after you enable a useful category. Your choices are stored per account.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...values.keys.map(
          (key) => SwitchListTile.adaptive(
            key: ValueKey('notification_$key'),
            title: Text(labels[key]!),
            value: values[key]!,
            onChanged: (value) async {
              if (value) {
                final registered = await ref
                    .read(appRepositoryProvider)
                    .registerForPush(promptIfNeeded: true);
                if (!registered) {
                  if (mounted) setState(() => values[key] = false);
                  return;
                }
              }
              if (!mounted) return;
              setState(() => values[key] = value);
              await ref.read(appRepositoryProvider).updateSetting(key, value);
            },
          ),
        ),
      ],
    ),
  );
}

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});
  @override
  ConsumerState<PrivacySettingsScreen> createState() => _PrivacySettingsState();
}

class _PrivacySettingsState extends ConsumerState<PrivacySettingsScreen> {
  bool private = false;
  String comments = 'everyone';
  String retention = 'forever';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('PRIVACY')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile.adaptive(
          key: const ValueKey('privacy_private_profile'),
          title: const Text('Private profile'),
          subtitle: const Text(
            'New followers require approval. Country and World feeds exclude your takes.',
          ),
          value: private,
          onChanged: (value) async {
            setState(() => private = value);
            await ref
                .read(appRepositoryProvider)
                .updateSetting('is_private', value);
          },
        ),
        const Divider(),
        DropdownButtonFormField<String>(
          key: const ValueKey('privacy_comment_permission'),
          initialValue: comments,
          decoration: const InputDecoration(labelText: 'Who can comment'),
          items: const [
            DropdownMenuItem(
              value: 'everyone',
              child: Text('All signed-in users'),
            ),
            DropdownMenuItem(value: 'followers', child: Text('Followers only')),
            DropdownMenuItem(value: 'disabled', child: Text('Comments off')),
          ],
          onChanged: (value) async {
            if (value == null) return;
            setState(() => comments = value);
            await ref
                .read(appRepositoryProvider)
                .updateSetting('comment_permission', value);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: const ValueKey('privacy_auto_delete'),
          initialValue: retention,
          decoration: const InputDecoration(
            labelText: 'Automatically delete takes',
          ),
          items: const [
            DropdownMenuItem(
              value: 'forever',
              child: Text('Keep until I delete'),
            ),
            DropdownMenuItem(value: '30', child: Text('After 30 days')),
            DropdownMenuItem(value: '90', child: Text('After 90 days')),
            DropdownMenuItem(value: '365', child: Text('After one year')),
          ],
          onChanged: (value) async {
            if (value == null) return;
            setState(() => retention = value);
            await ref
                .read(appRepositoryProvider)
                .updateSetting(
                  'auto_delete_days',
                  value == 'forever' ? null : int.parse(value),
                );
          },
        ),
        const SizedBox(height: 22),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'SVNLY never requests GPS, contacts, advertising identifiers or biometric face data. Media metadata is removed during server processing.',
            ),
          ),
        ),
      ],
    ),
  );
}

class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});
  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersState();
}

class _BlockedUsersState extends ConsumerState<BlockedUsersScreen> {
  late Future<List<Map<String, dynamic>>> users;
  @override
  void initState() {
    super.initState();
    users = ref.read(appRepositoryProvider).loadBlockedUsers();
  }

  void reload() => setState(
    () => users = ref.read(appRepositoryProvider).loadBlockedUsers(),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('BLOCKED USERS')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: users,
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
        final values = snapshot.data ?? const [];
        if (values.isEmpty) {
          return const Center(child: Text('You have not blocked anyone.'));
        }
        return ListView.builder(
          itemCount: values.length,
          itemBuilder: (context, index) {
            final user = values[index];
            return ListTile(
              title: Text(user['display_name'] as String? ?? ''),
              subtitle: Text('@${user['username'] ?? ''}'),
              trailing: TextButton(
                onPressed: () async {
                  await ref
                      .read(appRepositoryProvider)
                      .unblock(user['profile_id'] as String);
                  reload();
                },
                child: const Text('UNBLOCK'),
              ),
            );
          },
        );
      },
    ),
  );
}

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});
  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final subject = TextEditingController();
  final body = TextEditingController();
  bool sent = false;
  @override
  void dispose() {
    subject.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SUPPORT')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'How can we help?',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 10),
        const Text(
          'For safety reports about content or users, use the in-app Report action. Support tickets must not include passwords or private keys.',
        ),
        const SizedBox(height: 20),
        TextField(
          controller: subject,
          onChanged: (_) => setState(() {}),
          maxLength: 100,
          decoration: const InputDecoration(labelText: 'Subject'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: body,
          onChanged: (_) => setState(() {}),
          maxLength: 2000,
          minLines: 5,
          maxLines: 10,
          decoration: const InputDecoration(labelText: 'Message'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed:
              sent ||
                  subject.text.trim().length < 3 ||
                  body.text.trim().length < 10
              ? null
              : () async {
                  await ref
                      .read(appRepositoryProvider)
                      .createSupportTicket(subject.text, body.text);
                  if (mounted) setState(() => sent = true);
                },
          child: Text(sent ? 'TICKET SENT' : 'SEND SECURELY'),
        ),
      ],
    ),
  );
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ABOUT')),
    body: const SafeArea(
      minimum: EdgeInsets.all(24),
      child: Column(
        children: [
          Spacer(),
          SvnlyWordmark(fontSize: 52),
          SizedBox(height: 14),
          Text('7 seconds. One take. Be real.'),
          SizedBox(height: 30),
          Text('Version 1.0.0 (1)'),
          Spacer(),
          Text(
            'Everyone gets the same prompt.\nEveryone gets seven seconds.\nEveryone gets one take.',
            textAlign: TextAlign.center,
          ),
          Spacer(),
        ],
      ),
    ),
  );
}

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});
  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountState();
}

class _DeleteAccountState extends ConsumerState<DeleteAccountScreen> {
  final confirmation = TextEditingController();
  bool loading = false;
  @override
  void dispose() {
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('DELETE ACCOUNT')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.warning_amber, size: 64, color: SvnlyColors.error),
        const SizedBox(height: 18),
        Text(
          'This cannot be undone.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 14),
        const Text(
          'Your account is locked immediately, active sessions end, and a protected server job removes or anonymizes your profile, takes, media, comments, reactions, follows, blocks, device tokens and personal analytics. Minimal anonymized safety records may be retained where legally necessary.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 26),
        TextField(
          controller: confirmation,
          onChanged: (_) => setState(() {}),
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Type DELETE to confirm',
          ),
        ),
        const SizedBox(height: 16),
        AsyncActionButton(
          label: 'DELETE MY ACCOUNT',
          destructive: true,
          onPressed: () async {
            if (confirmation.text != 'DELETE') return;
            await ref.read(appRepositoryProvider).requestAccountDeletion();
            if (context.mounted) context.go('/auth');
          },
        ),
      ],
    ),
  );
}
