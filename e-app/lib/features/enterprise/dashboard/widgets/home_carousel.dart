import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../home_models.dart';

class HomeCarousel extends StatefulWidget {
  const HomeCarousel({
    super.key,
    this.identity,
    this.stats,
    this.nextInterview,
    this.interviewsLoaded = false,
  });
  final HomeIdentity? identity;
  final HomeStats? stats;
  final HomeInterview? nextInterview;
  final bool interviewsLoaded;
  @override
  State<HomeCarousel> createState() => _HomeCarouselState();
}

class _HomeCarouselState extends State<HomeCarousel>
    with WidgetsBindingObserver {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;
  bool _enabled = true;
  bool _foreground = true;
  bool _dragging = false;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled = TickerMode.valuesOf(context).enabled;
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _restart();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    if (!_enabled || !_foreground || _dragging || _reducedMotion) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted ||
          !_controller.hasClients ||
          _controller.position.isScrollingNotifier.value) {
        return;
      }
      _controller.animateToPage(
        (_index + 1) % 3,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  bool _scroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification) {
      _dragging = true;
      _timer?.cancel();
    } else if (notification is ScrollEndNotification) {
      _dragging = false;
      _restart();
    }
    return false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final greeting = widget.identity == null
        ? '欢迎来到招聘工作台'
        : '欢迎回来，${widget.identity!.nickname}';
    final progress = widget.stats?.activePositions == null
        ? '查看岗位与候选人，让每一次沟通有序推进'
        : '当前在招 ${widget.stats!.activePositions} 个岗位，及时关注候选人进展';
    final interview = widget.nextInterview;
    final reminder = interview != null
        ? '${interview.timeLabel} · ${interview.position}'
        : widget.interviewsLoaded
        ? '暂无即将进行的面试，留出时间发现合适的人才'
        : '查看近期面试，提前安排每一次交流';
    final slides = <(String, String, String, IconData, List<Color>)>[
      (
        '每一次相遇，都值得期待',
        greeting,
        '从这里开始今天的招聘工作',
        Icons.handshake_outlined,
        [AppColors.brand, AppColors.brandDeep],
      ),
      (
        '招聘进度',
        '让合适的人，更快相遇',
        progress,
        Icons.trending_up_outlined,
        [AppColors.ink, AppColors.brandDeep],
      ),
      (
        '面试提醒',
        interview == null ? '为下一场面试做好准备' : '${interview.candidate}的面试安排',
        reminder,
        Icons.event_available_outlined,
        [AppColors.brandDeep, AppColors.brand],
      ),
    ];
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return Column(
      children: [
        SizedBox(
          height: 184 * scale,
          child: NotificationListener<ScrollNotification>(
            onNotification: _scroll,
            child: PageView.builder(
              key: const ValueKey('home-carousel'),
              controller: _controller,
              itemCount: slides.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) {
                final slide = slides[index];
                return Container(
                  key: ValueKey('home-carousel-page-$index'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(colors: slide.$5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              slide.$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.canvas.withValues(alpha: .8),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              slide.$2,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.canvas,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              slide.$3,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.canvas.withValues(alpha: .9),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.canvas.withValues(
                          alpha: .12,
                        ),
                        child: Icon(
                          slide.$4,
                          color: AppColors.canvas,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        Semantics(
          label: '轮播图，第 ${_index + 1} 页，共 3 页',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < 3; index++)
                Semantics(
                  button: true,
                  selected: _index == index,
                  label: '第 ${index + 1} 张',
                  child: GestureDetector(
                    key: ValueKey('home-carousel-dot-$index'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _controller.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOutCubic,
                    ),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _index == index
                                ? AppColors.interactive
                                : AppColors.hairline,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
