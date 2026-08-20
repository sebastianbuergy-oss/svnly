import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design/tokens.dart';

const reportReasons = [
  'Spam',
  'Harassment',
  'Hate or discrimination',
  'Nudity or sexual content',
  'Minor safety',
  'Violence',
  'Graphic content',
  'Dangerous activity',
  'Illegal activity',
  'Impersonation',
  'Privacy violation',
  'Copyright',
  'Other',
];

Future<void> showReportSheet(
  BuildContext outerContext,
  WidgetRef ref, {
  required String targetType,
  required String targetId,
  String? profileId,
}) async {
  await showModalBottomSheet<void>(
    context: outerContext,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Safety', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text(
              'Reports are confidential. Immediate danger should be reported to local emergency services.',
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: reportReasons
                    .map(
                      (reason) => ListTile(
                        title: Text(reason),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await ref
                              .read(appRepositoryProvider)
                              .report(
                                targetType: targetType,
                                targetId: targetId,
                                reason: reason,
                              );
                          if (context.mounted) Navigator.pop(context);
                          if (outerContext.mounted) {
                            ScaffoldMessenger.of(outerContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Report submitted. Thank you for helping keep SVNLY safe.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
            if (profileId != null) ...[
              const Divider(),
              ListTile(
                textColor: SvnlyColors.error,
                iconColor: SvnlyColors.error,
                leading: const Icon(Icons.block),
                title: const Text('Block this user'),
                subtitle: const Text(
                  'You will no longer see each other anywhere on SVNLY.',
                ),
                onTap: () async {
                  await ref.read(appRepositoryProvider).block(profileId);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
