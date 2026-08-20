import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/config/app_config.dart';
import '../../core/design/tokens.dart';
import '../moderation/admin_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseUrl = ref.watch(appConfigProvider).legalBaseUrl;
    Future<void> legal(String path) => launchUrl(
      Uri.parse('$baseUrl/$path'),
      mode: LaunchMode.externalApplication,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('SETTINGS')),
      body: ListView(
        children: [
          _Section('ACCOUNT'),
          _Tile(
            'Edit Profile',
            Icons.edit_outlined,
            () => context.push('/edit-profile'),
          ),
          _Tile('Language', Icons.language, () => context.push('/language')),
          _Tile(
            'Notifications',
            Icons.notifications_outlined,
            () => context.push('/notifications'),
          ),
          _Section('PRIVACY'),
          _Tile(
            'Privacy & Profile Visibility',
            Icons.lock_outline,
            () => context.push('/privacy-settings'),
          ),
          _Tile(
            'Blocked Users',
            Icons.block,
            () => context.push('/blocked-users'),
          ),
          _Section('PLUS'),
          _Tile('SVNLY Plus', Icons.bolt, () => context.push('/premium')),
          _Tile(
            'Restore Purchases',
            Icons.restore,
            () => context.push('/premium'),
          ),
          _Section('HELP & LEGAL'),
          _Tile(
            'Help & Contact Support',
            Icons.help_outline,
            () => context.push('/support'),
          ),
          _Tile(
            'Community Guidelines',
            Icons.groups_outlined,
            () => legal('community'),
          ),
          _Tile(
            'Privacy Policy',
            Icons.shield_outlined,
            () => legal('privacy'),
          ),
          _Tile(
            'Terms of Use',
            Icons.description_outlined,
            () => legal('terms'),
          ),
          _Tile(
            'About SVNLY',
            Icons.info_outline,
            () => context.push('/about'),
          ),
          if (ref.watch(adminRepositoryProvider).isStaff) ...[
            _Section('STAFF'),
            _Tile(
              'Admin & Moderation',
              Icons.admin_panel_settings_outlined,
              () => context.push('/admin'),
            ),
          ],
          _Section('SESSION'),
          _Tile('Log Out', Icons.logout, () async {
            await ref.read(appRepositoryProvider).signOut();
            if (context.mounted) context.go('/auth');
          }),
          ListTile(
            textColor: SvnlyColors.error,
            iconColor: SvnlyColors.error,
            leading: const Icon(Icons.delete_forever_outlined),
            title: const Text('Delete Account'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/delete-account'),
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
    child: Text(
      label,
      style: const TextStyle(
        color: SvnlyColors.lime,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
      ),
    ),
  );
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
