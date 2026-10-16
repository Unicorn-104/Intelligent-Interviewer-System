import 'dart:async';
import 'dart:math' as math;

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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _controller = PageController();
  late final AnimationController _ambient;
  Timer? _timer;
  int _index = 0;
  bool _enabled = true;
  bool _foreground = true;
  bool _dragging = false;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
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

  void _syncAmbient() {
    final animate = _enabled && _foreground && !_dragging && !_reducedMotion;
    if (animate && !_ambient.isAnimating) {
      _ambient.repeat();
    } else if (!animate && _ambient.isAnimating) {
      _ambient.stop();
    }
  }

  void _restart() {
    _syncAmbient();
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
      _syncAmbient();
    } else if (notification is ScrollEndNotification) {
      _dragging = false;
      _restart();
    }
    return false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ambient.dispose();
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
        [
          AppColors.brandDeep,
          AppColors.brand,
          Color.lerp(AppColors.brand, AppColors.interactive, .65)!,
        ],
      ),
      (
        '招聘进度',
        '让合适的人，更快相遇',
        progress,
        Icons.trending_up_outlined,
        [
          AppColors.brand,
          Color.lerp(AppColors.brand, AppColors.interactive, .6)!,
          AppColors.interactive,
        ],
      ),
      (
        '面试提醒',
        interview == null ? '为下一场面试做好准备' : '${interview.candidate}的面试安排',
        reminder,
        Icons.event_available_outlined,
        [
          AppColors.brandDeep,
          Color.lerp(AppColors.brandDeep, AppColors.interactive, .35)!,
          Color.lerp(AppColors.brand, AppColors.interactive, .85)!,
        ],
      ),
    ];
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: (constraints.maxWidth < 300 ? 304 : 272) * scale,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              NotificationListener<ScrollNotification>(
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
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: slide.$5,
                          stops: const [0, .6, 1],
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Positioned.fill(
                            child: ExcludeSemantics(
                              child: IgnorePointer(
                                child: AnimatedBuilder(
                                  animation: _controller,
                                  builder: (context, child) {
                                    final page =
                                        _controller.hasClients &&
                                            _controller
                                                .position
                                                .hasContentDimensions
                                        ? _controller.page ?? _index.toDouble()
                                        : _index.toDouble();
                                    final delta = (page - index).clamp(
                                      -1.0,
                                      1.0,
                                    );
                                    return Transform.translate(
                                      offset: Offset(
                                        _reducedMotion ? 0 : delta * 28,
                                        _reducedMotion ? 0 : delta.abs() * 10,
                                      ),
                                      child: child,
                                    );
                                  },
                                  child: RepaintBoundary(
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: CustomPaint(
                                            painter: _CarouselAmbientPainter(
                                              animation: _ambient,
                                              variant: index,
                                              active:
                                                  index == _index &&
                                                  !_reducedMotion,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          right: -88,
                                          bottom: -112,
                                          child: Container(
                                            width: 320,
                                            height: 320,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: AppColors.canvas
                                                    .withValues(alpha: .08),
                                                width: 40,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          right: -48,
                                          top: -76,
                                          child: Container(
                                            width: 208,
                                            height: 208,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: RadialGradient(
                                                colors: [
                                                  AppColors.canvas.withValues(
                                                    alpha: .16,
                                                  ),
                                                  AppColors.canvas.withValues(
                                                    alpha: 0,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          right: 22,
                                          top: 24,
                                          child: Transform.rotate(
                                            angle: index == 1 ? -.12 : .08,
                                            child: Icon(
                                              slide.$4,
                                              color: AppColors.canvas
                                                  .withValues(alpha: .12),
                                              size: 100,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          right: 114,
                                          top: 36,
                                          child: Icon(
                                            Icons.add_rounded,
                                            color: AppColors.canvas.withValues(
                                              alpha: .3,
                                            ),
                                            size: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 24, 22, 56),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.canvas.withValues(
                                      alpha: .1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: AppColors.canvas.withValues(
                                        alpha: .16,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ExcludeSemantics(
                                        child: Icon(
                                          slide.$4,
                                          size: 15,
                                          color: AppColors.canvas,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          slide.$1,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: AppColors.canvas.withValues(
                                              alpha: .9,
                                            ),
                                            fontSize: 12,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  slide.$2,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.canvas,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  slide.$3,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.canvas.withValues(
                                      alpha: .8,
                                    ),
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                left: 22,
                right: 14,
                bottom: 8,
                child: Semantics(
                  label: '轮播图，第 ${_index + 1} 页，共 3 页',
                  child: Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: ExcludeSemantics(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '0${_index + 1}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.canvas,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' / 03',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.canvas.withValues(
                                        alpha: .5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
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
                                child: AnimatedContainer(
                                  duration: _reducedMotion
                                      ? Duration.zero
                                      : const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  width: _index == index ? 24 : 6,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: AppColors.canvas.withValues(
                                      alpha: _index == index ? 1 : .35,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Repaints only the decorative layer; copy and controls remain still.
class _CarouselAmbientPainter extends CustomPainter {
  _CarouselAmbientPainter({
    required this.animation,
    required this.variant,
    required this.active,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final int variant;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = active ? animation.value : 0.0;
    final angle = phase * math.pi * 2;
    final center = Offset(size.width * .8, size.height * .54);
    final radius = size.shortestSide * .38;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // A drifting wash adds depth without affecting text contrast.
    final light = Offset(
      size.width * (.74 + .1 * math.sin(angle)),
      size.height * (.32 + .12 * math.cos(angle)),
    );
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.canvas.withValues(alpha: .1),
          AppColors.canvas.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: light, radius: radius * 1.5));
    canvas.drawCircle(light, radius * 1.5, glow);

    switch (variant) {
      case 0:
        // Welcome: softly expanding concentric ripples.
        for (var ring = 0; ring < 3; ring++) {
          final progress = (phase + ring / 3) % 1;
          stroke.color = AppColors.canvas.withValues(
            alpha: .14 * (1 - progress),
          );
          canvas.drawCircle(center, radius * (.45 + progress * 1.1), stroke);
        }
      case 1:
        // Progress: an ascending series of gently breathing columns.
        final barWidth = size.width * .035;
        final baseline = size.height * .84;
        for (var bar = 0; bar < 6; bar++) {
          final wave = (math.sin(angle + bar * .65) + 1) / 2;
          final height = size.height * (.08 + bar * .033 + wave * .055);
          final rect = Rect.fromLTWH(
            size.width * .61 + bar * barWidth * 1.6,
            baseline - height,
            barWidth,
            height,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(4)),
            Paint()
              ..color = AppColors.canvas.withValues(alpha: .08 + wave * .07),
          );
        }
      default:
        // Reminder: a slow orbital sweep around the calendar illustration.
        stroke
          ..color = AppColors.canvas.withValues(alpha: .12)
          ..strokeWidth = 1.5;
        canvas.drawCircle(center, radius, stroke);
        stroke
          ..color = AppColors.canvas.withValues(alpha: .25)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          angle - math.pi / 2,
          math.pi * .45,
          false,
          stroke,
        );
        final dot =
            center +
            Offset(
                  math.cos(angle - math.pi / 2),
                  math.sin(angle - math.pi / 2),
                ) *
                radius;
        canvas.drawCircle(
          dot,
          3.5,
          Paint()..color = AppColors.canvas.withValues(alpha: .55),
        );
    }

    // Small floating accents provide a shared visual rhythm across all slides.
    for (var dot = 0; dot < 5; dot++) {
      final offset = Offset(
        size.width * (.55 + dot * .085),
        size.height * (.2 + (dot % 3) * .18) + math.sin(angle + dot) * 7,
      );
      canvas.drawCircle(
        offset,
        dot.isEven ? 2 : 1.5,
        Paint()..color = AppColors.canvas.withValues(alpha: .22),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CarouselAmbientPainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.variant != variant ||
      oldDelegate.active != active;
}
