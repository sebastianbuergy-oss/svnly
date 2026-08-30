import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../app/providers.dart';
import '../../core/design/effects.dart';
import '../../core/design/tokens.dart';
import '../challenge/models.dart';
import '../social/comments_sheet.dart';

class MyTakeCard extends ConsumerStatefulWidget {
  const MyTakeCard({
    required this.take,
    this.compact = false,
    this.onRefresh,
    super.key,
  });

  final MyTake take;
  final bool compact;
  final VoidCallback? onRefresh;

  @override
  ConsumerState<MyTakeCard> createState() => _MyTakeCardState();
}

class _MyTakeCardState extends ConsumerState<MyTakeCard> {
  VideoPlayerController? controller;
  bool muted = false;
  bool deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MyTakeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.take.videoUrl != widget.take.videoUrl) {
      controller?.dispose();
      controller = null;
      _load();
    }
  }

  Future<void> _load() async {
    final url = widget.take.videoUrl;
    if (url == null || url.isEmpty) return;
    final next = VideoPlayerController.networkUrl(Uri.parse(url));
    controller = next;
    try {
      await next.initialize();
      await next.setLooping(true);
      if (mounted) setState(() {});
    } catch (_) {
      await next.dispose();
      if (identical(controller, next)) controller = null;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final player = controller;
    if (player?.value.isInitialized != true) return;
    if (player!.value.isPlaying) {
      await player.pause();
    } else {
      await player.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _confirmDelete() async {
    final takeId = widget.take.id;
    if (takeId == null || deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Take löschen?'),
        content: const Text(
          'Video, Thumbnail, Reactions und Kommentare werden entfernt. '
          'Dein ONE TAKE bleibt verbraucht – heute gibt es keinen Retake.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ABBRECHEN'),
          ),
          FilledButton(
            key: const ValueKey('confirm_delete_take'),
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: SvnlyColors.hotPink),
            child: const Text('TAKE LÖSCHEN'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => deleting = true);
    try {
      await controller?.pause();
      await ref.read(appRepositoryProvider).deleteTake(takeId);
      ref.invalidate(myTakesProvider);
      for (final scope in const ['friends', 'country', 'world']) {
        ref.invalidate(feedProvider(scope));
      }
      widget.onRefresh?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Take gelöscht. Heute bleibt's bei diesem einen Versuch 👀",
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Take konnte nicht gelöscht werden.')),
        );
      }
    } finally {
      if (mounted) setState(() => deleting = false);
    }
  }

  Color get statusColor => switch (widget.take.status) {
    'published' => SvnlyColors.lime,
    'under_review' => SvnlyColors.orange,
    'processing' => SvnlyColors.electricBlue,
    _ => SvnlyColors.purple,
  };

  @override
  Widget build(BuildContext context) {
    if (widget.take.isDeleted) return _deletedReceipt();
    return GradientBorderCard(
      gradient: widget.take.status == 'published'
          ? SvnlyGradients.heroPop
          : SvnlyGradients.social,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SvnlyRadius.large - 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: widget.compact ? 16 / 10 : 9 / 13,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _media(),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black12,
                          Colors.transparent,
                          Colors.black87,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: NeonBadge(
                      label: widget.take.displayStatus,
                      color: statusColor,
                      icon: widget.take.status == 'published'
                          ? Icons.bolt
                          : Icons.hourglass_top,
                    ),
                  ),
                  if (widget.take.id != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: PopupMenuButton<String>(
                        key: ValueKey('my_take_menu_${widget.take.id}'),
                        tooltip: 'Take options',
                        enabled: !deleting,
                        onSelected: (value) {
                          if (value == 'delete') _confirmDelete();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline),
                                SizedBox(width: 10),
                                Text('Take löschen'),
                              ],
                            ),
                          ),
                        ],
                        icon: deleting
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.more_horiz),
                      ),
                    ),
                  if (widget.take.isPlayable)
                    Center(
                      child: Semantics(
                        button: true,
                        label: controller?.value.isPlaying == true
                            ? 'Pause your take'
                            : 'Play your take',
                        child: IconButton.filled(
                          key: ValueKey('my_take_play_${widget.take.id}'),
                          onPressed: _togglePlayback,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withValues(
                              alpha: .58,
                            ),
                            foregroundColor: SvnlyColors.lime,
                            minimumSize: const Size(66, 66),
                          ),
                          iconSize: 38,
                          icon: Icon(
                            controller?.value.isPlaying == true
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.take.challengeTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: widget.compact ? 18 : 24,
                            height: .98,
                            fontWeight: FontWeight.w900,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 12),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat('dd MMM yyyy')
                              .format(widget.take.challengeDate),
                          style: const TextStyle(
                            color: SvnlyColors.secondaryText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                children: [
                  _Metric(
                    icon: Icons.favorite,
                    value: widget.take.reactionCount,
                  ),
                  const SizedBox(width: 16),
                  _Metric(
                    icon: Icons.mode_comment_outlined,
                    value: widget.take.commentCount,
                  ),
                  const SizedBox(width: 16),
                  _Metric(
                    icon: Icons.visibility_outlined,
                    value: widget.take.viewCount,
                  ),
                  const Spacer(),
                  if (widget.take.id != null)
                    TextButton.icon(
                      key: ValueKey('my_take_comments_${widget.take.id}'),
                      onPressed: () async {
                        await showCommentsSheet(context, ref, widget.take.id!);
                        widget.onRefresh?.call();
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('COMMENTS'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deletedReceipt() => GradientBorderCard(
    gradient: SvnlyGradients.social,
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.delete_outline,
            color: SvnlyColors.hotPink,
            size: 34,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TAKE GELÖSCHT',
                  style: TextStyle(
                    color: SvnlyColors.hotPink,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  widget.take.isToday
                      ? "Heute bleibt's bei diesem einen Versuch 👀"
                      : 'Take deleted. One take means one take 😏',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _media() {
    if (controller?.value.isInitialized == true) {
      return ColoredBox(
        color: Colors.black,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: controller!.value.size.width,
            height: controller!.value.size.height,
            child: VideoPlayer(controller!),
          ),
        ),
      );
    }
    final thumbnail = widget.take.thumbnailUrl;
    if (thumbnail != null && thumbnail.isNotEmpty) {
      return Image.network(thumbnail, fit: BoxFit.contain);
    }
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: SvnlyGradients.midnightPop),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.take.isPlayable
                  ? Icons.play_circle_outline
                  : Icons.cloud_upload_outlined,
              size: 54,
              color: statusColor,
            ),
            const SizedBox(height: 10),
            Text(
              widget.take.isPlayable
                  ? 'PREPARING VIDEO…'
                  : 'UPLOAD IN PROGRESS',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value});
  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: SvnlyColors.hotPink),
      const SizedBox(width: 5),
      Text('$value', style: const TextStyle(fontWeight: FontWeight.w900)),
    ],
  );
}
