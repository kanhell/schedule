import 'package:flutter/material.dart';
import '../models.dart';
import '../widgets/utils.dart';
import '../widgets/donut_chart.dart';
import '../widgets/time_goal.dart';

// ─────────────────────────────────────────
// 분석 페이지
// ─────────────────────────────────────────

class AnalysisPage extends StatefulWidget {
  final List<ScheduleItem> schedules;
  final TimeSettings timeSettings;
  final List<ColorLabel> colorLabels;
  final ValueChanged<List<ColorLabel>> onColorLabelsChanged;

  const AnalysisPage({
    super.key,
    required this.schedules,
    required this.timeSettings,
    required this.colorLabels,
    required this.onColorLabelsChanged,
  });

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  final List<TimeGoal> _goals = [];
  final Set<String> _expandedGoalIds = {};

  // ── 색상별 총 시간(분) 계산 ──
  Map<Color, int> _calcMinutesByColor() {
    final map = <Color, int>{};
    for (final item in widget.schedules) {
      final minutes = item.durationSlots * widget.timeSettings.slotMinutes;
      map[item.color] = (map[item.color] ?? 0) + minutes;
    }
    return map;
  }

  String _labelName(Color c) {
    try {
      return widget.colorLabels.firstWhere((l) => l.color == c).name;
    } catch (_) {
      return '기타';
    }
  }

  String _formatMinutes(int minutes) {
    if (minutes == 0) return '0분';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '$h시간 $m분';
    if (h > 0) return '$h시간';
    return '$m분';
  }

  // ── 목표 달성 여부 ──
  bool _isGoalAchieved(TimeGoal goal, Map<Color, int> minutesByColor) {
    final actual = minutesByColor[goal.color] ?? 0;
    return goal.type == GoalType.atLeast
        ? actual >= goal.targetMinutes
        : actual < goal.targetMinutes;
  }

  // ── 목표 추가/수정 다이얼로그 ──
  void _showGoalDialog({TimeGoal? editing}) async {
    GoalType goalType = editing?.type ?? GoalType.atLeast;
    Color selectedColor = editing?.color ?? kUserPaletteColors[0];
    int targetMinutes = editing?.targetMinutes ?? 60;
    List<int> resetDays = List.from(editing?.resetDays ?? []);

    const dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(editing == null ? '목표 추가' : '목표 수정',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 목표 유형 ──
                  const Text('목표 유형',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: GoalTypeChip(
                          label: 'n시간 달성',
                          icon: Icons.check_circle_outline,
                          selected: goalType == GoalType.atLeast,
                          color: Colors.green,
                          onTap: () =>
                              setDlgState(() => goalType = GoalType.atLeast),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GoalTypeChip(
                          label: 'n시간 미만',
                          icon: Icons.do_not_disturb_alt_outlined,
                          selected: goalType == GoalType.lessThan,
                          color: Colors.orange,
                          onTap: () =>
                              setDlgState(() => goalType = GoalType.lessThan),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── 색상 선택 ──
                  const Text('색상',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(kUserPaletteColors.length, (ci) {
                      final c = kUserPaletteColors[ci];
                      final isSelected = selectedColor == c;
                      return GestureDetector(
                        onTap: () => setDlgState(() => selectedColor = c),
                        child: Container(
                          width: 30,
                          height: 30,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.black54, width: 2.5)
                                : Border.all(
                                    color: Colors.transparent, width: 2.5),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  size: 14, color: Colors.black54)
                              : null,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),

                  // ── 목표 시간 (30분 단위) ──
                  const Text('목표 시간',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: targetMinutes > 30
                            ? () => setDlgState(() => targetMinutes -= 30)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                        color: Colors.blue,
                      ),
                      SizedBox(
                        width: 90,
                        child: Center(
                          child: Text(
                            _formatMinutes(targetMinutes),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            setDlgState(() => targetMinutes += 30),
                        icon: const Icon(Icons.add_circle_outline),
                        color: Colors.blue,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [30, 60, 90, 120].map((val) {
                      return OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          shape: const StadiumBorder(),
                          side: const BorderSide(color: Colors.blue),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () =>
                            setDlgState(() => targetMinutes = val),
                        child: Text(_formatMinutes(val),
                            style: const TextStyle(fontSize: 11)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // ── 초기화 요일 ──
                  const Text('초기화 요일',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    resetDays.isEmpty ? '매일 초기화' : '선택한 요일에 초기화',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: List.generate(7, (i) {
                      final selected = resetDays.contains(i);
                      return FilterChip(
                        label: Text(dayLabels[i]),
                        selected: selected,
                        selectedColor: Colors.blue.shade100,
                        checkmarkColor: Colors.blue,
                        onSelected: (on) {
                          setDlgState(() {
                            if (on) {
                              resetDays.add(i);
                            } else {
                              resetDays.remove(i);
                            }
                          });
                        },
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: selected ? Colors.blue : Colors.black87,
                        ),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      );
                    }),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('취소')),
              ElevatedButton(
                onPressed: () {
                  final goal = TimeGoal(
                    id: editing?.id ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    type: goalType,
                    color: selectedColor,
                    targetMinutes: targetMinutes,
                    resetDays: resetDays,
                  );
                  setState(() {
                    if (editing != null) {
                      final idx =
                          _goals.indexWhere((g) => g.id == editing.id);
                      if (idx >= 0) _goals[idx] = goal;
                    } else {
                      _goals.add(goal);
                    }
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('저장'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── 특정 색상의 일정 이름별 시간(분) 집계 ──
  Map<String, int> _calcMinutesByTitleForColor(Color color) {
    final map = <String, int>{};
    for (final item in widget.schedules) {
      if (item.color != color) continue;
      final minutes = item.durationSlots * widget.timeSettings.slotMinutes;
      map[item.title] = (map[item.title] ?? 0) + minutes;
    }
    return map;
  }

  void _toggleGoalExpanded(String id) {
    setState(() {
      if (_expandedGoalIds.contains(id)) {
        _expandedGoalIds.remove(id);
      } else {
        _expandedGoalIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final minutesByColor = _calcMinutesByColor();
    final totalMinutes = minutesByColor.values.fold(0, (a, b) => a + b);

    final entries = widget.colorLabels.map((label) {
      final minutes = minutesByColor[label.color] ?? 0;
      return ColorStat(
        label: label,
        minutes: minutes,
        ratio: totalMinutes > 0 ? minutes / totalMinutes : 0,
      );
    }).toList();

    final usedEntries = entries.where((e) => e.minutes > 0).toList()
      ..sort((a, b) => b.minutes.compareTo(a.minutes));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('분석',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: widget.schedules.isEmpty && _goals.isEmpty
          ? _buildEmpty()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.schedules.isNotEmpty) ...[
                  _buildDonutCard(usedEntries, totalMinutes),
                  const SizedBox(height: 16),
                ],
                _buildGoalsCard(minutesByColor),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showGoalDialog(),
        tooltip: '목표 추가',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('아직 데이터가 없습니다.',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500)),
          const SizedBox(height: 6),
          Text('홈에서 일정을 추가하거나\n+ 버튼으로 목표를 설정해보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildDonutCard(List<ColorStat> usedEntries, int totalMinutes) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('오늘 시간 분포',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(200, 200),
                    painter: DonutPainter(usedEntries),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatMinutes(totalMinutes),
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                      const Text('총 시간',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: usedEntries.map((e) {
                final pct = (e.ratio * 100).round();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: e.label.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${e.label.name} ${_formatMinutes(e.minutes)} ($pct%)',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalsCard(Map<Color, int> minutesByColor) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('목표',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                Text('${_goals.length}개',
                    style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
            if (_goals.isEmpty) ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  '+ 버튼으로 목표를 추가해보세요.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(height: 4),
            ] else ...[
              const SizedBox(height: 12),
              ..._goals.map((goal) => _buildGoalRow(goal, minutesByColor)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGoalRow(TimeGoal goal, Map<Color, int> minutesByColor) {
    final actual = minutesByColor[goal.color] ?? 0;
    final achieved = _isGoalAchieved(goal, minutesByColor);
    final isAtLeast = goal.type == GoalType.atLeast;
    final isExpanded = _expandedGoalIds.contains(goal.id);

    final progress = (actual / goal.targetMinutes).clamp(0.0, 1.0);
    final typeColor = isAtLeast ? Colors.green : Colors.orange;
    final typeLabel = isAtLeast ? '달성' : '미만';
    final typeIcon =
        isAtLeast ? Icons.check_circle_outline : Icons.do_not_disturb_alt_outlined;

    const dayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    final resetLabel = goal.resetDays.isEmpty
        ? '매일'
        : goal.resetDays.map((d) => dayLabels[d]).join('·');

    final labelName = _labelName(goal.color);

    // 이름별 시간 집계 (내림차순 정렬)
    final titleMinutes = _calcMinutesByTitleForColor(goal.color).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () => _showGoalDialog(editing: goal),
        onLongPress: () => _showDeleteConfirm(goal),
        child: Container(
          decoration: BoxDecoration(
            color: achieved
                ? typeColor.withValues(alpha: 0.06)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: achieved
                  ? typeColor.withValues(alpha: 0.3)
                  : Colors.grey.shade200,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 헤더 행 ──
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                        color: goal.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(labelName,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(typeIcon, size: 11, color: typeColor),
                        const SizedBox(width: 3),
                        Text(typeLabel,
                            style: TextStyle(
                                fontSize: 10,
                                color: typeColor,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    achieved ? Icons.emoji_events : Icons.hourglass_top,
                    size: 18,
                    color: achieved ? typeColor : Colors.grey.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── 진행 바 ──
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value:
                      isAtLeast ? progress : (1.0 - progress).clamp(0.0, 1.0),
                  minHeight: 7,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    achieved ? typeColor : typeColor.withValues(alpha: 0.4),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── 하단 요약 행 ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isAtLeast
                        ? '${_formatMinutes(actual)} / ${_formatMinutes(goal.targetMinutes)}'
                        : '현재 ${_formatMinutes(actual)}  목표 ${_formatMinutes(goal.targetMinutes)} 미만',
                    style: TextStyle(
                        fontSize: 12,
                        color: achieved ? typeColor : Colors.black54,
                        fontWeight: FontWeight.w500),
                  ),
                  Row(
                    children: [
                      Icon(Icons.refresh,
                          size: 11, color: Colors.grey.shade400),
                      const SizedBox(width: 2),
                      Text(resetLabel,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade400)),
                      // ── 토글 버튼 ──
                      if (titleMinutes.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            _toggleGoalExpanded(goal.id);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: isExpanded
                                  ? goal.color.withValues(alpha: 0.18)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '내역',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isExpanded
                                        ? goal.color
                                        : Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 14,
                                  color: isExpanded
                                      ? goal.color
                                      : Colors.grey.shade500,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              // ── 펼쳐지는 이름별 내역 ──
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                child: isExpanded && titleMinutes.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: goal.color.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: goal.color.withValues(alpha: 0.2),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '일정별 내역',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...titleMinutes.map((entry) {
                                final ratio = actual > 0
                                    ? entry.value / actual
                                    : 0.0;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 7),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    entry.key,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.black87,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Text(
                                                  _formatMinutes(entry.value),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: goal.color
                                                        .withValues(alpha: 0.85),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                              child: LinearProgressIndicator(
                                                value: ratio,
                                                minHeight: 4,
                                                backgroundColor:
                                                    Colors.grey.shade200,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(
                                                  goal.color.withValues(
                                                      alpha: 0.6),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteGoal(String id) {
    setState(() => _goals.removeWhere((g) => g.id == id));
  }

  void _showDeleteConfirm(TimeGoal goal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('목표 삭제'),
        content: const Text('이 목표를 삭제할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _deleteGoal(goal.id);
              Navigator.pop(ctx);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}