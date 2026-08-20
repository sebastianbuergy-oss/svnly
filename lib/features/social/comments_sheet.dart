import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design/tokens.dart';
import '../challenge/models.dart';
import '../moderation/report_sheet.dart';

Future<void> showCommentsSheet(
  BuildContext outerContext,
  WidgetRef ref,
  FeedTake take,
) async {
  await showModalBottomSheet<void>(
    context: outerContext,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: .82,
      child: _CommentsBody(take: take),
    ),
  );
}

class _CommentsBody extends ConsumerStatefulWidget {
  const _CommentsBody({required this.take});
  final FeedTake take;
  @override
  ConsumerState<_CommentsBody> createState() => _CommentsBodyState();
}

class _CommentsBodyState extends ConsumerState<_CommentsBody> {
  final input = TextEditingController();
  late Future<List<CommentItem>> comments;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    comments = ref.read(appRepositoryProvider).loadComments(widget.take.id);
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
    comments = ref.read(appRepositoryProvider).loadComments(widget.take.id);
  });

  Future<void> _send() async {
    final value = input.text.trim();
    if (value.isEmpty || value.length > 280) return;
    setState(() => sending = true);
    try {
      await ref
          .read(appRepositoryProvider)
          .createComment(widget.take.id, value);
      input.clear();
      _reload();
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 10),
      Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: SvnlyColors.mutedText,
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      const SizedBox(height: 14),
      Text('Comments', style: Theme.of(context).textTheme.titleLarge),
      const Divider(),
      Expanded(
        child: FutureBuilder<List<CommentItem>>(
          future: comments,
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
              return const Center(
                child: Text('Be the first to say something real.'),
              );
            }
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text(
                    '@${item.username}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(item.body),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) async {
                      if (action == 'delete') {
                        await ref
                            .read(appRepositoryProvider)
                            .deleteComment(item.id);
                        _reload();
                      } else if (action == 'report') {
                        if (context.mounted) {
                          await showReportSheet(
                            context,
                            ref,
                            targetType: 'comment',
                            targetId: item.id,
                            profileId: item.profileId,
                          );
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      if (item.isMine)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      if (!item.isMine)
                        const PopupMenuItem(
                          value: 'report',
                          child: Text('Report or block'),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(
          14,
          8,
          14,
          MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: input,
                maxLength: 280,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Add a comment…',
                  counterText: '',
                ),
              ),
            ),
            IconButton(
              onPressed: sending ? null : _send,
              tooltip: 'Send comment',
              icon: const Icon(Icons.send, color: SvnlyColors.lime),
            ),
          ],
        ),
      ),
    ],
  );
}
