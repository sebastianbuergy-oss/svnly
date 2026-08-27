import 'dart:io';

const requiredTables = <String>{
  'profiles',
  'user_private',
  'user_settings',
  'terms_acceptances',
  'challenges',
  'take_attempts',
  'takes',
  'challenge_participations',
  'take_metrics',
  'reactions',
  'comments',
  'follows',
  'blocks',
  'reports',
  'moderation_queue',
  'moderation_actions',
  'badges',
  'user_badges',
  'daily_rankings',
  'all_time_rankings',
  'device_tokens',
  'notification_preferences',
  'notifications',
  'entitlements',
  'support_tickets',
  'account_deletion_jobs',
  'admin_audit_log',
  'app_config',
  'analytics_events',
};

const requiredFunctions = <String>{
  'issue_take_attempt',
  'mark_attempt_started',
  'request_technical_retry',
  'reserve_take_upload',
  'finalize_take',
  'get_daily_feed',
  'block_profile',
  'create_report',
  'request_account_deletion',
};

void main() {
  final directory = Directory('supabase/migrations');
  if (!directory.existsSync()) {
    stderr.writeln('Missing supabase/migrations.');
    exitCode = 2;
    return;
  }

  final files =
      directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final sql = files
      .map((file) => file.readAsStringSync())
      .join('\n')
      .toLowerCase();
  final failures = <String>[];

  for (final table in requiredTables) {
    if (!sql.contains('create table public.$table')) {
      failures.add('Missing table public.$table');
    }
    if (!sql.contains('alter table public.$table enable row level security')) {
      failures.add('RLS not enabled for public.$table');
    }
  }
  for (final function in requiredFunctions) {
    if (!sql.contains('function public.$function(')) {
      failures.add('Missing secure RPC public.$function');
    }
  }
  for (final bucket in const [
    'avatars',
    'takes',
    'take-thumbnails',
    'moderation-artifacts',
  ]) {
    if (!sql.contains("'$bucket'")) {
      failures.add('Missing storage bucket $bucket');
    }
  }
  if (!sql.contains('revoke all on function')) {
    failures.add('RPC privilege revocation is missing');
  }
  if (!sql.contains('not public.is_blocked')) {
    failures.add('Block filtering is missing from read policies/functions');
  }
  if (!sql.contains('auth.uid()')) {
    failures.add('No authenticated ownership checks found');
  }

  if (failures.isNotEmpty) {
    for (final failure in failures) {
      stderr.writeln('FAIL: $failure');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Backend contract passed: ${requiredTables.length} tables have RLS; '
    '${requiredFunctions.length} critical RPCs and 4 private buckets found.',
  );
}
