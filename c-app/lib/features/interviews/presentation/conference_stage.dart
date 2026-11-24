import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

const _background = Color(0xFF0B0D12);
const _surface = Color(0xFF151922);
const _text = Color(0xFFF2F5FA);
const _muted = Color(0xFF94A0B3);
const _blue = Color(0xFF2B63D9);
const _green = Color(0xFF34C759);
const _red = Color(0xFFFF453A);

/// One camera or screen share. Identity remains stable across roster updates.
class ConferenceStageFeed {
  const ConferenceStageFeed({
    required this.id,
    required this.name,
    this.track,
    this.microphone = false,
    this.speaking = false,
    this.local = false,
    this.screenShare = false,
  });

  final String id, name;
  final lk.VideoTrack? track;
  final bool microphone, speaking, local, screenShare;
}

/// First page: selectable main view. Subsequent pages: up to four feeds each.
class ConferenceStage extends StatefulWidget {
  const ConferenceStage({super.key, required this.feeds});
  final List<ConferenceStageFeed> feeds;

  @override
  State<ConferenceStage> createState() => _ConferenceStageState();
}

class _ConferenceStageState extends State<ConferenceStage> {
  final _pages = PageController();
  String? _selected;
  int _page = 0;
  int get _pageCount => 1 + (widget.feeds.length / 4).ceil();

  @override
  void didUpdateWidget(ConferenceStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Removal of the last gallery page must not leave an empty viewport.
    if (_page >= _pageCount) {
      _page = _pageCount - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) _pages.jumpToPage(_page);
      });
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  ConferenceStageFeed get _featured {
    for (final feed in widget.feeds) {
      if (feed.id == _selected) return feed;
    }
    return widget.feeds.where((f) => f.screenShare).firstOrNull ??
        widget.feeds.where((f) => !f.local).firstOrNull ??
        widget.feeds.first;
  }

  void _showPage(int page) {
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.feeds.isEmpty) return const ColoredBox(color: _background);
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            key: const ValueKey('conference-stage-pages'),
            controller: _pages,
            itemCount: _pageCount,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (_, page) => page == 0
                ? _focus()
                : _gallery(widget.feeds.skip((page - 1) * 4).take(4).toList()),
          ),
        ),
        SizedBox(
          height: 44,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < _pageCount; index++)
                  Semantics(
                    selected: index == _page,
                    child: IconButton(
                      tooltip: index == 0 ? '主画面' : '宫格视图 $index',
                      onPressed: () => _showPage(index),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      icon: Icon(
                        Icons.circle,
                        size: index == _page ? 8 : 6,
                        color: index == _page ? _text : _muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _focus() {
    final featured = _featured;
    final others = widget.feeds.where((f) => f.id != featured.id).toList();
    return LayoutBuilder(
      builder: (context, bounds) {
        final compact = bounds.maxHeight < 340;
        return Column(
          children: [
            if (others.isNotEmpty)
              SizedBox(
                height: compact ? 72 : 104,
                child: ListView.separated(
                  key: const ValueKey('conference-thumbnail-strip'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  itemCount: others.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 4),
                  itemBuilder: (_, index) {
                    final feed = others[index];
                    return SizedBox(
                      width: compact ? 94 : 116,
                      child: _tile(
                        feed,
                        compact: true,
                        onTap: () => setState(() => _selected = feed.id),
                      ),
                    );
                  },
                ),
              ),
            Expanded(
              child: _tile(
                featured,
                key: ValueKey('conference-featured-${featured.id}'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _gallery(List<ConferenceStageFeed> feeds) => LayoutBuilder(
    builder: (context, bounds) {
      final landscape = bounds.maxWidth > bounds.maxHeight;
      Widget tile(ConferenceStageFeed feed) => Expanded(
        child: _tile(
          feed,
          key: ValueKey('conference-grid-${feed.id}'),
          onTap: () {
            setState(() => _selected = feed.id);
            _showPage(0);
          },
        ),
      );
      Widget row(List<ConferenceStageFeed> cells) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final feed in cells) tile(feed)],
      );
      if (feeds.length == 1) return _tile(feeds.single);
      if (feeds.length == 2) {
        return landscape
            ? row(feeds)
            : Column(children: [for (final feed in feeds) tile(feed)]);
      }
      return Column(
        children: [
          Expanded(child: row(feeds.take(2).toList())),
          Expanded(
            child: feeds.length == 3
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),
                      Expanded(
                        flex: 2,
                        child: _tile(
                          feeds[2],
                          key: ValueKey('conference-grid-${feeds[2].id}'),
                          onTap: () {
                            setState(() => _selected = feeds[2].id);
                            _showPage(0);
                          },
                        ),
                      ),
                      const Spacer(),
                    ],
                  )
                : row(feeds.skip(2).toList()),
          ),
        ],
      );
    },
  );

  Widget _tile(
    ConferenceStageFeed feed, {
    Key? key,
    bool compact = false,
    VoidCallback? onTap,
  }) => Padding(
    padding: const EdgeInsets.all(1),
    child: Semantics(
      button: onTap != null,
      label: onTap == null ? feed.name : '选择${feed.name}为主画面',
      child: GestureDetector(
        key: key ?? ValueKey('conference-thumbnail-${feed.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConferenceFeedTile(feed: feed, compact: compact),
      ),
    ),
  );
}

class ConferenceFeedTile extends StatelessWidget {
  const ConferenceFeedTile({
    super.key,
    required this.feed,
    this.compact = false,
  });
  final ConferenceStageFeed feed;
  final bool compact;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: _surface,
      border: Border.all(
        color: feed.speaking ? _green : _background,
        width: feed.speaking ? 2 : 1,
      ),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (feed.track != null)
          lk.VideoTrackRenderer(
            feed.track!,
            fit: feed.screenShare
                ? lk.VideoViewFit.contain
                : lk.VideoViewFit.cover,
            mirrorMode: feed.local && !feed.screenShare
                ? lk.VideoViewMirrorMode.auto
                : lk.VideoViewMirrorMode.off,
          )
        else
          Center(
            child: LayoutBuilder(
              builder: (_, bounds) {
                final radius = (bounds.biggest.shortestSide * .2).clamp(
                  14.0,
                  compact ? 24.0 : 48.0,
                );
                return CircleAvatar(
                  radius: radius,
                  backgroundColor: _blue,
                  child: Text(
                    feed.name.characters.firstOrNull ?? '人',
                    style: TextStyle(fontSize: radius * .85, color: _text),
                  ),
                );
              },
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(6, compact ? 6 : 18, 6, 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: .75),
                ],
              ),
            ),
            child: Row(
              children: [
                Icon(
                  feed.microphone ? Icons.mic : Icons.mic_off,
                  color: feed.microphone ? _text : _red,
                  size: compact ? 12 : 16,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    feed.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _text, fontSize: compact ? 11 : 13),
                  ),
                ),
                if (feed.screenShare)
                  const Icon(
                    Icons.screen_share_outlined,
                    size: 14,
                    color: _text,
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
