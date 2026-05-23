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
  final List<TimeGoal> timeGoals;
  final ValueChanged<List<ColorLabel>> onColorLabelsChanged;
  final ValueChanged<List<TimeGoal>> onTimeGoalsChanged;
  final Future<List<ScheduleItem>> Function(DateTime) onLoadSchedulesForDate;

  const AnalysisPage({
    super.key,
    required this.schedules,
    required this.timeSettings,
    required this.colorLabels,
    required this.timeGoals,
    required this.onColorLabelsChanged,
    required this.onTimeGoalsChanged,
    required this.onLoadSchedulesForDate,
  });

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  late List<TimeGoal> _goals;
  final Set<String> _expandedGoalIds = {};

  // ── 주간 집계 캐시 ──
  Map<Color, int> _weeklyMinutesByColor = {};
  bool _weeklyLoaded = false;

  @override
  void initState() {
    super.initState();
    _goals = List.from(widget.timeGoals);
    _refreshPeriodCache();
    _loadWeeklyData();
  }

  @override
  void didUpdateWidget(AnalysisPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeGoals != widget.timeGoals) {
      _goals = List.from(widget.timeGoals);
    }
    if (oldWidget.schedules != widget.schedules ||
        oldWidget.timeGoals != widget.timeGoals) {
      _periodCache.clear();
      _refreshPeriodCache();
    }
    if (oldWidget.schedules != widget.schedules) {
      _loadWeeklyData();
    }
  }

  Future<void> _loadWeeklyData() async {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final byColor = <Color, int>{};
    for (int i = 6; i >= 0; i--) {
      final date = todayOnly.subtract(Duration(days: i));
      final items = await widget.onLoadSchedulesForDate(date);
      for (final item in items) {
        final minutes = item.durationMinutes;
        byColor[item.color] = (byColor[item.color] ?? 0) + minutes;
      }
    }
    if (mounted) {
      setState(() {
        _weeklyMinutesByColor = byColor;
        _weeklyLoaded = true;
      });
    }
  }

  void _saveGoals() => widget.onTimeGoalsChanged(_goals);

  // ── 목표 기간 계산 (TimeGoal 또는 SubGoal 공통) ──
  DateTimeRange _calcPeriod(List<int> resetDays) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    if (resetDays.isEmpty) {
      return DateTimeRange(start: todayOnly, end: todayOnly);
    }

    final todayWeekday = todayOnly.weekday - 1;
    final sorted = List<int>.from(resetDays)..sort();

    int? latestResetWeekday;
    int daysBack = 0;

    for (int d = 0; d <= 6; d++) {
      final candidateWeekday = (todayWeekday - d) % 7;
      final candidate = (candidateWeekday + 7) % 7;
      if (sorted.contains(candidate)) {
        latestResetWeekday = candidate;
        daysBack = d;
        break;
      }
    }

    if (latestResetWeekday == null) {
      return DateTimeRange(start: todayOnly, end: todayOnly);
    }

    final periodStart = daysBack == 0
        ? todayOnly
        : todayOnly.subtract(Duration(days: daysBack - 1));

    return DateTimeRange(start: periodStart, end: todayOnly);
  }

  DateTimeRange _goalPeriod(TimeGoal goal) => _calcPeriod(goal.resetDays);

  // ── 기간 캐시: goalId → (기간, 집계결과) ──
  // subGoal도 같은 캐시: key = 'goalId:subGoalId'
  final Map<String, ({DateTimeRange range, Map<Color, int> byColor, Map<String, Map<Color, int>> byTitle})>
      _periodCache = {};

  Future<void> _refreshPeriodCache() async {
    final allGoals = [..._goals];
    for (final goal in allGoals) {
      await _ensureCached(goal.id, goal.resetDays);
      for (final sub in goal.subGoals) {
        await _ensureCached('${goal.id}:${sub.id}', sub.resetDays);
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _ensureCached(String key, List<int> resetDays) async {
    final range = _calcPeriod(resetDays);
    final existing = _periodCache[key];
    if (existing != null &&
        existing.range.start == range.start &&
        existing.range.end == range.end) {
      return;
    }

    final byColor = <Color, int>{};
    final byTitle = <String, Map<Color, int>>{};

    DateTime cursor = range.start;
    while (!cursor.isAfter(range.end)) {
      final items = await widget.onLoadSchedulesForDate(cursor);
      for (final item in items) {
        final minutes = item.durationMinutes;
        byColor[item.color] = (byColor[item.color] ?? 0) + minutes;
        byTitle[item.title] ??= {};
        byTitle[item.title]![item.color] =
            (byTitle[item.title]![item.color] ?? 0) + minutes;
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    _periodCache[key] = (range: range, byColor: byColor, byTitle: byTitle);
  }

  // ── 오늘 하루 색상별 총 시간(분) — 도넛 차트용 ──
  Map<Color, int> _calcMinutesByColor() {
    final map = <Color, int>{};
    for (final item in widget.schedules) {
      final minutes = item.durationMinutes;
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

  // ── 목표 달성 여부 (초록) or 목표 실패 여부 (주황) ──
  bool _isGoalAchieved(TimeGoal goal) {
    final actual = _goalMinutesByColor(goal)[goal.color] ?? 0;
    return goal.type == GoalType.atLeast
        ? actual >= goal.targetMinutes
        : actual < goal.targetMinutes;
  }

  bool _isSubGoalAchieved(TimeGoal goal, SubGoal sub) {
    final actual = _subGoalActualMinutes(goal, sub);
    return sub.type == GoalType.atLeast
        ? actual >= sub.targetMinutes
        : actual < sub.targetMinutes;
  }

  /// 세부목표 실제 시간: 해당 goal 색상 + titleKeyword 일치하는 일정의 기간 합산
  int _subGoalActualMinutes(TimeGoal goal, SubGoal sub) {
    final cacheKey = '${goal.id}:${sub.id}';
    final byTitle = _periodCache[cacheKey]?.byTitle ?? {};
    int total = 0;
    for (final entry in byTitle.entries) {
      if (entry.key == sub.titleKeyword) {
        total += entry.value[goal.color] ?? 0;
      }
    }
    return total;
  }

  // ── 목표 추가/수정 공통 다이얼로그 빌더 ──
  Future<void> _showGoalDialog({TimeGoal? editing}) async {
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
              if (editing != null)
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _deleteGoal(editing.id);
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('삭제'),
                ),
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
                    subGoals: editing?.subGoals ?? [],
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
                  _saveGoals();
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

  // ── 목표 기간의 색상별 시간 (캐시에서) ──
  Map<Color, int> _goalMinutesByColor(TimeGoal goal) =>
      _periodCache[goal.id]?.byColor ?? {};

  // ── 목표 기간의 이름별 시간 (해당 색상만, 캐시에서) ──
  Map<String, int> _goalMinutesByTitle(TimeGoal goal) {
    final byTitle = _periodCache[goal.id]?.byTitle ?? {};
    final result = <String, int>{};
    for (final entry in byTitle.entries) {
      final minutes = entry.value[goal.color];
      if (minutes != null && minutes > 0) {
        result[entry.key] = minutes;
      }
    }
    return result;
  }

  // ── 기간 레이블 (예: "5/19 ~ 5/23") ──
  String _periodLabel(TimeGoal goal) {
    final range = _periodCache[goal.id]?.range;
    if (range == null) return '';
    final s = range.start;
    final e = range.end;
    if (s == e) return '${s.month}/${s.day}';
    return '${s.month}/${s.day} ~ ${e.month}/${e.day}';
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

  // ── 세부목표 추가/수정 다이얼로그 ──
  Future<void> _showSubGoalDialog(TimeGoal goal, {SubGoal? editing}) async {
    GoalType goalType = editing?.type ?? GoalType.atLeast;
    int targetMinutes = editing?.targetMinutes ?? 60;
    List<int> resetDays = List.from(editing?.resetDays ?? []);
    final titleController = TextEditingController(text: editing?.titleKeyword ?? '');
    bool showTitleError = false;

    const dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

    // 이 목표 색상에 속하는 기존 일정 이름 목록 (자동완성용)
    final titleSuggestions = (_goalMinutesByTitle(goal).keys.toList()
      ..sort());

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: goal.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(editing == null ? '세부목표 추가' : '세부목표 수정',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 일정 이름 ──
                  const Text('일정 이름',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText: '집계할 일정 이름',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: showTitleError ? Colors.red : Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: showTitleError
                                ? Colors.red
                                : Colors.grey.shade300),
                      ),
                    ),
                    onChanged: (_) {
                      if (showTitleError) setDlgState(() => showTitleError = false);
                    },
                  ),
                  if (showTitleError)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text('이름을 입력해 주세요.',
                          style: TextStyle(
                              fontSize: 11, color: Colors.red.shade400)),
                    ),
                  if (titleSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: titleSuggestions.map((t) {
                        return GestureDetector(
                          onTap: () {
                            titleController.text = t;
                            setDlgState(() => showTitleError = false);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: goal.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: goal.color.withValues(alpha: 0.4)),
                            ),
                            child: Text(t,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.black87)),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 18),

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

                  // ── 목표 시간 ──
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
                    style: const TextStyle(
                        fontSize: 11, color: Colors.blueGrey),
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
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }),
                  ),
                ],
              ),
            ),
            actions: [
              if (editing != null)
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    final goalIdx = _goals.indexWhere((g) => g.id == goal.id);
                    if (goalIdx >= 0) {
                      setState(() {
                        final updated = _goals[goalIdx].copyWith(
                          subGoals: _goals[goalIdx]
                              .subGoals
                              .where((s) => s.id != editing.id)
                              .toList(),
                        );
                        _goals[goalIdx] = updated;
                      });
                      _saveGoals();
                    }
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('삭제'),
                ),
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('취소')),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty) {
                    setDlgState(() => showTitleError = true);
                    return;
                  }
                  final sub = SubGoal(
                    id: editing?.id ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    titleKeyword: titleController.text.trim(),
                    type: goalType,
                    targetMinutes: targetMinutes,
                    resetDays: resetDays,
                  );
                  final goalIdx = _goals.indexWhere((g) => g.id == goal.id);
                  if (goalIdx >= 0) {
                    List<SubGoal> newSubs;
                    if (editing != null) {
                      newSubs = _goals[goalIdx].subGoals.map((s) {
                        return s.id == editing.id ? sub : s;
                      }).toList();
                    } else {
                      newSubs = [..._goals[goalIdx].subGoals, sub];
                    }
                    setState(() {
                      _goals[goalIdx] =
                          _goals[goalIdx].copyWith(subGoals: newSubs);
                    });
                    _periodCache.remove('${goal.id}:${sub.id}');
                    _ensureCached('${goal.id}:${sub.id}', sub.resetDays)
                        .then((_) { if (mounted) setState(() {}); });
                    _saveGoals();
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('저장'),
              ),
            ],
          );
        },
      ),
    );
    titleController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutesByColor = _calcMinutesByColor();
    final totalMinutes = minutesByColor.values.fold(0, (a, b) => a + b);

    // 기타설정 기준 하루 전체 시간(분)
    final dayTotalMinutes =
        (widget.timeSettings.dayEndHour - widget.timeSettings.dayStartHour) * 60;
    final unallocatedMinutes = (dayTotalMinutes - totalMinutes).clamp(0, dayTotalMinutes);

    final entries = widget.colorLabels.map((label) {
      final minutes = minutesByColor[label.color] ?? 0;
      return ColorStat(
        label: label,
        minutes: minutes,
        ratio: dayTotalMinutes > 0 ? minutes / dayTotalMinutes : 0,
      );
    }).toList();

    final usedEntries = entries.where((e) => e.minutes > 0).toList()
      ..sort((a, b) => b.minutes.compareTo(a.minutes));

    // 미할당 시간 ColorStat (회색, 도넛 마지막)
    final unallocatedStat = ColorStat(
      label: ColorLabel(color: Colors.grey.shade300, name: '미할당'),
      minutes: unallocatedMinutes,
      ratio: dayTotalMinutes > 0 ? unallocatedMinutes / dayTotalMinutes : 0,
    );

    // 도넛용: 색상 항목 + 미할당
    final donutEntries = [
      ...usedEntries,
      if (unallocatedMinutes > 0) unallocatedStat,
    ];

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
                  _buildDonutPageView(donutEntries, usedEntries, totalMinutes, dayTotalMinutes, unallocatedMinutes),
                  const SizedBox(height: 16),
                ],
                _buildGoalsCard(),
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

  // ── 오늘 + 일주일 도넛을 좌우 스와이프로 보여주는 PageView ──
  Widget _buildDonutPageView(
    List<ColorStat> donutEntries,
    List<ColorStat> usedEntries,
    int totalMinutes,
    int dayTotalMinutes,
    int unallocatedMinutes,
  ) {
    // 주간 도넛 데이터 계산
    final weeklyTotal = _weeklyMinutesByColor.values.fold(0, (a, b) => a + b);
    final weeklyUsedEntries = widget.colorLabels
        .map((label) {
          final minutes = _weeklyMinutesByColor[label.color] ?? 0;
          return ColorStat(
            label: label,
            minutes: minutes,
            ratio: weeklyTotal > 0 ? minutes / weeklyTotal : 0,
          );
        })
        .where((e) => e.minutes > 0)
        .toList()
      ..sort((a, b) => b.minutes.compareTo(a.minutes));

    final pageController = PageController();
    final pageNotifier = ValueNotifier<int>(0);

    return StatefulBuilder(
      builder: (context, setPageState) {
        return Column(
          children: [
            SizedBox(
              height: 420,
              child: PageView(
                controller: pageController,
                onPageChanged: (i) => pageNotifier.value = i,
                children: [
                  _buildDonutCard(donutEntries, usedEntries, totalMinutes,
                      dayTotalMinutes, unallocatedMinutes, title: '오늘 시간 분포'),
                  _buildWeeklyDonutCard(weeklyUsedEntries, weeklyTotal),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<int>(
              valueListenable: pageNotifier,
              builder: (_, page, _) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(2, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: page == i ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: page == i ? Colors.blue : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                )),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── 일주일 도넛 카드 ──
  Widget _buildWeeklyDonutCard(List<ColorStat> usedEntries, int totalMinutes) {
    if (!_weeklyLoaded) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        child: const SizedBox(
          height: 300,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final weekStart = todayOnly.subtract(const Duration(days: 6));
    final dateLabel =
        '${weekStart.month}/${weekStart.day} ~ ${todayOnly.month}/${todayOnly.day}';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('일주일 시간 분포',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(dateLabel,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                      const Text('7일 합계',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (usedEntries.isEmpty)
              Text('이번 주 데이터가 없습니다.',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade400))
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: usedEntries.map((e) {
                  final pct = totalMinutes > 0
                      ? (e.minutes / totalMinutes * 100).round()
                      : 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: e.label.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(e.label.name,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black87)),
                        ),
                        Text(_formatMinutes(e.minutes),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 36,
                          child: Text('($pct%)',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400),
                              textAlign: TextAlign.right),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonutCard(
    List<ColorStat> donutEntries,
    List<ColorStat> usedEntries,
    int totalMinutes,
    int dayTotalMinutes,
    int unallocatedMinutes, {
    String title = '오늘 시간 분포',
  }) {
    // 인덱스: 미할당 맨 위, 그 아래 색상 항목 (시간 많은 순)
    final legendEntries = [
      if (unallocatedMinutes > 0)
        ColorStat(
          label: ColorLabel(color: Colors.grey.shade400, name: '미할당'),
          minutes: unallocatedMinutes,
          ratio: dayTotalMinutes > 0 ? unallocatedMinutes / dayTotalMinutes : 0,
        ),
      ...usedEntries,
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(200, 200),
                    painter: DonutPainter(donutEntries),
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
                      Text(
                        '/ ${_formatMinutes(dayTotalMinutes)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 인덱스: 미할당 맨 위, 나머지 아래
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: legendEntries.map((e) {
                final pct = (e.ratio * 100).round();
                final isUnallocated = e.label.name == '미할당';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: e.label.color,
                          shape: BoxShape.circle,
                          border: isUnallocated
                              ? Border.all(color: Colors.grey.shade400, width: 1)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          e.label.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: isUnallocated
                                ? Colors.grey.shade500
                                : Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        _formatMinutes(e.minutes),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isUnallocated
                              ? Colors.grey.shade500
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 36,
                        child: Text(
                          '($pct%)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalsCard() {
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
              ..._goals.map((goal) => _buildGoalRow(goal)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGoalRow(TimeGoal goal) {
    final actual = _goalMinutesByColor(goal)[goal.color] ?? 0;
    final achieved = _isGoalAchieved(goal);
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () => _toggleGoalExpanded(goal.id),
        onLongPress: () => _showGoalDialog(editing: goal),
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
                      // ── 펼치기 힌트 ──
                      const SizedBox(width: 6),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ],
              ),

              // ── 펼쳐지는 세부목표 영역 ──
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                child: isExpanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(height: 1),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '세부목표',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _showSubGoalDialog(goal),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: goal.color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: goal.color.withValues(alpha: 0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add,
                                            size: 12, color: goal.color),
                                        const SizedBox(width: 3),
                                        Text('추가',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: goal.color,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (goal.subGoals.isEmpty) ...[
                              const SizedBox(height: 10),
                              Center(
                                child: Text(
                                  '+ 추가 버튼으로 세부목표를 설정해보세요.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade400),
                                ),
                              ),
                              const SizedBox(height: 4),
                            ] else ...[
                              const SizedBox(height: 8),
                              ...goal.subGoals.map((sub) =>
                                  _buildSubGoalRow(goal, sub)),
                            ],
                          ],
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

  Widget _buildSubGoalRow(TimeGoal goal, SubGoal sub) {
    final actual = _subGoalActualMinutes(goal, sub);
    final achieved = _isSubGoalAchieved(goal, sub);
    final isAtLeast = sub.type == GoalType.atLeast;
    final progress = (actual / sub.targetMinutes).clamp(0.0, 1.0);
    final typeColor = isAtLeast ? Colors.green : Colors.orange;

    const dayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    final resetLabel = sub.resetDays.isEmpty
        ? '매일'
        : sub.resetDays.map((d) => dayLabels[d]).join('·');

    return GestureDetector(
      onTap: () => _showSubGoalDialog(goal, editing: sub),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: achieved
              ? typeColor.withValues(alpha: 0.06)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: achieved
                ? typeColor.withValues(alpha: 0.25)
                : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: goal.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    sub.titleKeyword,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    isAtLeast ? '달성' : '미만',
                    style: TextStyle(
                        fontSize: 9,
                        color: typeColor,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  achieved ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 14,
                  color: achieved ? typeColor : Colors.grey.shade300,
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: isAtLeast
                    ? progress
                    : (1.0 - progress).clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(
                  achieved ? typeColor : typeColor.withValues(alpha: 0.4),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isAtLeast
                      ? '${_formatMinutes(actual)} / ${_formatMinutes(sub.targetMinutes)}'
                      : '현재 ${_formatMinutes(actual)}  목표 ${_formatMinutes(sub.targetMinutes)} 미만',
                  style: TextStyle(
                      fontSize: 11,
                      color: achieved ? typeColor : Colors.black54,
                      fontWeight: FontWeight.w500),
                ),
                Row(
                  children: [
                    Icon(Icons.refresh, size: 10, color: Colors.grey.shade400),
                    const SizedBox(width: 2),
                    Text(resetLabel,
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade400)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _deleteGoal(String id) {
    setState(() => _goals.removeWhere((g) => g.id == id));
    _saveGoals();
  }
}