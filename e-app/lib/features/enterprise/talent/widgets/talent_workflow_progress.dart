import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../data/talent_detail_data_source.dart';
import '../models/talent_detail_view_data.dart';
import '../models/talent_workflow_progress.dart';

class TalentWorkflowProgress extends StatefulWidget {
  const TalentWorkflowProgress({
    super.key,
    required this.candidateId,
    required this.source,
    this.job,
    this.revision = 0,
  });
  final int? candidateId;
  final TalentDetailDataSource source;
  final TalentJobContext? job;
  final int revision;

  @override
  State<TalentWorkflowProgress> createState() => _TalentWorkflowProgressState();
}

class _TalentWorkflowProgressState extends State<TalentWorkflowProgress> {
  final _scroll = ScrollController();
  bool _loading = true, _left = false, _right = false, _partial = false;
  String? _error;
  List<TalentWorkflowStage> _stages = [];
  int _request = 0;
  double _lastViewport = -1, _lastContent = -1;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateEdges);
    _load();
  }

  @override
  void didUpdateWidget(covariant TalentWorkflowProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candidateId != widget.candidateId ||
        oldWidget.job?.positionId != widget.job?.positionId ||
        oldWidget.job?.currentStage != widget.job?.currentStage ||
        oldWidget.revision != widget.revision ||
        oldWidget.source != widget.source) {
      _load();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    final candidateId = widget.candidateId;
    final job = widget.job;
    setState(() {
      _loading = true;
      _error = null;
      _partial = false;
    });
    if (candidateId == null || job == null) {
      setState(() {
        _stages = [];
        _loading = false;
      });
      return;
    }
    try {
      final results = await Future.wait<Object>([
        widget.source.loadWorkflow(job.positionId),
        widget.source.loadCandidatePlan(candidateId, job.positionId),
      ]);
      final workflow = results[0] as Map<String, dynamic>;
      final appointments = results[1] as List<Map<String, dynamic>>;
      final sessions = <int, Map<String, dynamic>>{};
      final needed = appointments
          .where(
            (row) =>
                talentId(row['candidateId']) == candidateId &&
                talentId(row['positionId']) == job.positionId &&
                talentId(row['stageId']) != null &&
                int.tryParse('${row['status']}') != 2 &&
                int.tryParse('${row['status']}') != 3,
          )
          .map((row) => talentId(row['sessionId']))
          .whereType<int>()
          .toSet()
          .toList();
      var partial = false;
      // 每批最多三个只读会话查询，不因一个无权访问或缺失的会话清空整个流程。
      for (var start = 0; start < needed.length; start += 3) {
        if (!mounted || request != _request) return;
        await Future.wait(
          needed.skip(start).take(3).map((id) async {
            try {
              sessions[id] = await widget.source.loadWorkflowSession(id);
            } catch (_) {
              partial = true;
            }
          }),
        );
      }
      final stages = talentWorkflowStages(
        workflow: workflow,
        appointments: appointments,
        candidateId: candidateId,
        positionId: job.positionId,
        sessions: sessions,
        currentStage: job.currentStage,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _stages = stages;
        _loading = false;
        _partial = partial;
        _left = false;
        _right = false;
        _lastViewport = -1;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.jumpTo(0);
          _updateEdges();
        }
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(() {
          _loading = false;
          _error = '流程暂不可用';
        });
      }
    }
  }

  void _updateEdges() {
    if (!mounted ||
        !_scroll.hasClients ||
        !_scroll.position.hasContentDimensions) {
      return;
    }
    final left = _scroll.offset > .5;
    final right = _scroll.offset < _scroll.position.maxScrollExtent - .5;
    if (left != _left || right != _right) {
      setState(() {
        _left = left;
        _right = right;
      });
    }
  }

  void _move(bool next) {
    if (!_scroll.hasClients) return;
    final target =
        (_scroll.offset +
                (next ? 1 : -1) * _scroll.position.viewportDimension * .8)
            .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.job == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text(
          '选择岗位后查看流程',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      );
    }
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (_error != null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          TextButton(onPressed: _load, child: const Text('重试')),
        ],
      );
    }
    if (_stages.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text(
          '暂无招聘流程',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final baseWidth = math.max(82.0, 72 * scale);
            final overflow =
                _stages.length * baseWidth > constraints.maxWidth + .5;
            final viewport = math.max(
              1.0,
              constraints.maxWidth - (overflow ? 88 : 0),
            );
            final cellWidth = overflow
                ? baseWidth
                : constraints.maxWidth / _stages.length;
            final contentWidth = cellWidth * _stages.length;
            final height = 30 + 28 * scale;
            if (_lastViewport != viewport || _lastContent != contentWidth) {
              _lastViewport = viewport;
              _lastContent = contentWidth;
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _updateEdges(),
              );
            }
            return Row(
              children: [
                if (overflow)
                  SizedBox(
                    width: 44,
                    child: _left
                        ? IconButton(
                            key: const Key('talent-flow-prev'),
                            tooltip: '上一阶段',
                            onPressed: () => _move(false),
                            icon: const Icon(Icons.chevron_left),
                          )
                        : null,
                  ),
                Expanded(
                  child: SizedBox(
                    height: height,
                    child: Stack(
                      children: [
                        NotificationListener<ScrollMetricsNotification>(
                          onNotification: (_) {
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => _updateEdges(),
                            );
                            return false;
                          },
                          child: SingleChildScrollView(
                            key: const Key('talent-flow-scroll'),
                            controller: _scroll,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: contentWidth,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (
                                    var index = 0;
                                    index < _stages.length;
                                    index++
                                  )
                                    _node(index, cellWidth),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (overflow && _left)
                          Positioned(
                            left: 0,
                            top: 0,
                            child: _ellipsis('talent-flow-hidden-left'),
                          ),
                        if (overflow && _right)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: _ellipsis('talent-flow-hidden-right'),
                          ),
                      ],
                    ),
                  ),
                ),
                if (overflow)
                  SizedBox(
                    width: 44,
                    child: _right
                        ? IconButton(
                            key: const Key('talent-flow-next'),
                            tooltip: '下一阶段',
                            onPressed: () => _move(true),
                            icon: const Icon(Icons.chevron_right),
                          )
                        : null,
                  ),
              ],
            );
          },
        ),
        if (_partial)
          Row(
            children: [
              const Expanded(
                child: Text(
                  '部分参加记录待核实',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
              IconButton(
                tooltip: '重试参加记录',
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
      ],
    );
  }

  Widget _ellipsis(String key) => IgnorePointer(
    child: Container(
      key: ValueKey(key),
      width: 18,
      height: 24,
      alignment: Alignment.center,
      color: AppColors.canvas,
      child: const Text('...', style: TextStyle(color: AppColors.textMuted)),
    ),
  );

  Widget _node(int index, double width) {
    final stage = _stages[index];
    final color = stage.attended
        ? AppColors.success
        : stage.current
        ? AppColors.interactive
        : AppColors.textMuted;
    return SizedBox(
      width: width,
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 24,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (index > 0)
                  Positioned(
                    left: 0,
                    right: width / 2,
                    top: 11,
                    child: Container(
                      key: ValueKey('talent-flow-line-in-${stage.id}'),
                      height: 2,
                      color: _stages[index - 1].attended
                          ? AppColors.success
                          : AppColors.hairline,
                    ),
                  ),
                if (index < _stages.length - 1)
                  Positioned(
                    left: width / 2,
                    right: 0,
                    top: 11,
                    child: Container(
                      key: ValueKey('talent-flow-line-${stage.id}'),
                      height: 2,
                      color: stage.attended
                          ? AppColors.success
                          : AppColors.hairline,
                    ),
                  ),
                Container(
                  key: ValueKey('talent-flow-dot-${stage.id}'),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: stage.attended || stage.current
                          ? color
                          : AppColors.canvas,
                      shape: BoxShape.circle,
                      border: Border.all(color: color),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Tooltip(
            message:
                '${stage.name} · ${stage.attended
                    ? '已参加'
                    : stage.current
                    ? '当前阶段，参加情况未核实'
                    : '暂无已参加记录'}',
            child: Text(
              stage.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, height: 1.15, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
