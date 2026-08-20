import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRepository {
  AdminRepository(this._client);
  final SupabaseClient _client;

  bool get isStaff => const {
    'admin',
    'moderator',
  }.contains(_client.auth.currentUser?.appMetadata['role']);

  Future<Map<String, dynamic>> dashboard() async =>
      Map<String, dynamic>.from(await _client.rpc('admin_dashboard') as Map);

  Future<List<Map<String, dynamic>>> queue() async {
    final value = await _client.rpc(
      'admin_moderation_queue',
      params: {'p_limit': 100},
    ) as List<dynamic>;
    return value
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Future<void> decide(String queueId, String decision, String reason) =>
      _client.rpc(
        'admin_apply_moderation',
        params: {
          'p_queue_id': queueId,
          'p_decision': decision,
          'p_reason': reason,
        },
      );
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(Supabase.instance.client);
});
