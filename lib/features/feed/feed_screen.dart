import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../app/providers.dart';
import '../../core/design/tokens.dart';
import '../../core/localization/app_strings.dart';
import '../challenge/models.dart';
import '../moderation/report_sheet.dart';
import '../social/comments_sheet.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});
  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController tabs;
  int activeIndex = 0;
  static const scopes = ['friends', 'country', 'world'];

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 3, vsync: this);
    tabs.addListener(() {
      if (!tabs.indexIsChanging) setState(() => activeIndex = 0);
    });
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final participation = ref.watch(hasTakeTodayProvider);
    return participation.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _locked(retry: true),
      data: (hasTake) {
        if (!hasTake) return _locked();
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black.withValues(alpha: .75),
            title: TabBar(
              controller: tabs,
              indicatorColor: SvnlyColors.lime,
              tabs: const [
                Tab(text: 'FRIENDS'),
                Tab(text: 'COUNTRY'),
                Tab(text: 'WORLD'),
              ],
            ),
          ),
          body: TabBarView(
            controller: tabs,
            children: scopes.map(_scopeView).toList(growable: false),
          ),
        );
      },
    );
  }

  Widget _locked({bool retry = false}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 56, color: SvnlyColors.lime),
          const SizedBox(height: 20),
          Text(
            AppStrings.of(context).locked,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 14),
          Text(
            retry
                ? 'We could not verify your participation.'
                : 'Everyone plays by the same rule.',
            textAlign: TextAlign.center,
          ),
          if (retry) ...[
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => ref.invalidate(hasTakeTodayProvider),
              child: const Text('TRY AGAIN'),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _scopeView(String scope) {
    final feed = ref.watch(feedProvider(scope));
    return feed.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: OutlinedButton(
          onPressed: () => ref.invalidate(feedProvider(scope)),
          child: const Text('RELOAD FEED'),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                scope == 'friends'
                    ? AppStrings.of(context).noFriends
                    : 'The world is still waking up.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          );
        }
        return PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: items.length,
          onPageChanged: (value) => setState(() => activeIndex = value),
          itemBuilder: (context, index) => FeedVideoCard(
            take: items[index],
            active: index == activeIndex,
            onChanged: () => ref.invalidate(feedProvider(scope)),
          ),
        );
      },
    );
  }
}

class FeedVideoCard extends ConsumerStatefulWidget {
  const FeedVideoCard({
    required this.take,
    required this.active,
    required this.onChanged,
    super.key,
  });
  final FeedTake take;
  final bool active;
  final VoidCallback onChanged;

  @override
  ConsumerState<FeedVideoCard> createState() => _FeedVideoCardState();
}

class _FeedVideoCardState extends ConsumerState<FeedVideoCard> {
  VideoPlayerController? player;
  bool muted = false;
  bool impressionRecorded = false;
  bool completionRecorded = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final next = VideoPlayerController.networkUrl(
      Uri.parse(widget.take.videoUrl),
    );
    player = next;
    await next.initialize();
    await next.setLooping(true);
    next.addListener(_trackCompletion);
    await _recordView(completed: false);
    if (widget.active) await next.play();
    if (mounted) setState(() {});
  }

  void _trackCompletion() {
    if (completionRecorded || player?.value.isInitialized != true) return;
    final value = player!.value;
    if (value.position >= const Duration(milliseconds: 6800)) {
      _recordView(completed: true);
    }
  }

  Future<void> _recordView({required bool completed}) async {
    if (completed ? completionRecorded : impressionRecorded) return;
    if (completed) {
      completionRecorded = true;
    } else {
      impressionRecorded = true;
    }
    try {
      await ref
          .read(appRepositoryProvider)
          .recordTakeView(widget.take.id, completed: completed);
    } catch (_) {
      if (completed) {
        completionRecorded = false;
      } else {
        impressionRecorded = false;
      }
    }
  }

  @override
  void didUpdateWidget(covariant FeedVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      widget.active ? player?.play() : player?.pause();
    }
  }

  @override
  void dispose() {
    player?.removeListener(_trackCompletion);
    player?.dispose();
    super.dispose();
  }

  Future<void> _reaction() async {
    const choices = ['heart', 'laugh', 'fire', 'wow'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: choices
              .map(
                (value) => IconButton(
                  iconSize: 34,
                  tooltip: value,
                  onPressed: () => Navigator.pop(context, value),
                  icon: Text(switch (value) {
                    'heart' => '❤️',
                    'laugh' => '😂',
                    'fire' => '🔥',
                    _ => '😮',
                  }),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (selected == null) return;
    await ref
        .read(appRepositoryProvider)
        .setReaction(
          widget.take.id,
          selected == widget.take.myReaction ? null : selected,
        );
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (player?.value.isInitialized == true)
        GestureDetector(
          onTap: () {
            setState(() => muted = !muted);
            player?.setVolume(muted ? 0 : 1);
          },
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: player!.value.size.width,
              height: player!.value.size.height,
              child: VideoPlayer(player!),
            ),
          ),
        )
      else
        const Center(child: CircularProgressIndicator()),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.transparent, Colors.black87],
          ),
        ),
      ),
      Positioned(
        left: 18,
        right: 78,
        bottom: 28,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.take.challengeTitle,
              style: const TextStyle(
                color: SvnlyColors.lime,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.take.displayName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            Text('@${widget.take.username} · ${widget.take.countryCode}'),
          ],
        ),
      ),
      Positioned(
        right: 10,
        bottom: 22,
        child: Column(
          children: [
            _FeedAction(
              icon: Icons.favorite,
              label: '${widget.take.reactionCount}',
              onTap: _reaction,
            ),
            _FeedAction(
              icon: Icons.mode_comment_outlined,
              label: '${widget.take.commentCount}',
              onTap: () => showCommentsSheet(context, ref, widget.take),
            ),
            _FeedAction(
              icon: Icons.person_add_alt,
              label: 'Follow',
              onTap: () async {
                await ref
                    .read(appRepositoryProvider)
                    .follow(widget.take.profileId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Follow updated.')),
                  );
                }
              },
            ),
            _FeedAction(
              icon: Icons.more_horiz,
              label: 'Safety',
              onTap: () => showReportSheet(
                context,
                ref,
                targetType: 'take',
                targetId: widget.take.id,
                profileId: widget.take.profileId,
              ),
            ),
          ],
        ),
      ),
      if (muted)
        const Positioned(top: 18, right: 18, child: Icon(Icons.volume_off)),
    ],
  );
}

class _FeedAction extends StatelessWidget {
  const _FeedAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(
          width: 60,
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black54,
                ),
                child: Icon(icon),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
