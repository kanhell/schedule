import 'package:flutter/material.dart';
import '../models.dart';
import '../utils.dart';
import 'routine_settings_page.dart';
import 'day_schedule_settings_page.dart';
import 'general_settings_page.dart';
import 'analysis_page.dart';

// ─── 네비게이션 루트 ───────────────────────────────────────────
class ScheduleApp extends StatefulWidget {
  const ScheduleApp({super.key});
  @override
  State<ScheduleApp> createState() => _ScheduleAppState();
}

class _ScheduleAppState extends State<ScheduleApp> {
  int _currentIndex = 0;

  // 공유 상태 (홈 ↔ 분석 공유)
  List<ScheduleItem> schedules = [];
  TimeSettings timeSettings = const TimeSettings();
  List<ConditionalRuleSet> conditionalRuleSets = [
    ConditionalRuleSet(
      name: '저녁 루틴',
      color: kUserPaletteColors[0],
      options: [
        RoutineOption(
          name: '기본 (80분)',
          blocks: [ScheduleBlock(title: '저녁 루틴', durationMinutes: 80)],
        ),
        RoutineOption(
          name: '짧게 (40분)',
          blocks: [ScheduleBlock(title: '저녁 루틴', durationMinutes: 40)],
        ),
      ],
    ),
  ];
  final List<String> _dayNames = ['월', '화', '수', '목', '금', '토', '일'];
  late List<List<ScheduleItem>> _daySchedules;

  // 색상별 이름 (팔레트 6색 고정)
  late List<ColorLabel> colorLabels;

  @override
  void initState() {
    super.initState();
    _daySchedules = List.generate(7, (_) => []);
    colorLabels = List.generate(
      kUserPaletteColors.length,
      (i) => ColorLabel(color: kUserPaletteColors[i], name: kUserPaletteLabels[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomePage(
        schedules: schedules,
        timeSettings: timeSettings,
        conditionalRuleSets: conditionalRuleSets,
        dayNames: _dayNames,
        daySchedules: _daySchedules,
        onSchedulesChanged: (s) => setState(() => schedules = s),
        onTimeSettingsChanged: (t) => setState(() => timeSettings = t),
        onRuleSetsChanged: (r) => setState(() => conditionalRuleSets = r),
        onDaySchedulesChanged: (d) => setState(() => _daySchedules = d),
      ),
      AnalysisPage(
        schedules: schedules,
        timeSettings: timeSettings,
        colorLabels: colorLabels,
        onColorLabelsChanged: (updated) => setState(() => colorLabels = updated),
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: '오늘',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '분석',
          ),
        ],
      ),
    );
  }
}

// ─── 홈(타임라인) 페이지 ──────────────────────────────────────
class _HomePage extends StatefulWidget {
  final List<ScheduleItem> schedules;
  final TimeSettings timeSettings;
  final List<ConditionalRuleSet> conditionalRuleSets;
  final List<String> dayNames;
  final List<List<ScheduleItem>> daySchedules;
  final ValueChanged<List<ScheduleItem>> onSchedulesChanged;
  final ValueChanged<TimeSettings> onTimeSettingsChanged;
  final ValueChanged<List<ConditionalRuleSet>> onRuleSetsChanged;
  final ValueChanged<List<List<ScheduleItem>>> onDaySchedulesChanged;

  const _HomePage({
    required this.schedules,
    required this.timeSettings,
    required this.conditionalRuleSets,
    required this.dayNames,
    required this.daySchedules,
    required this.onSchedulesChanged,
    required this.onTimeSettingsChanged,
    required this.onRuleSetsChanged,
    required this.onDaySchedulesChanged,
  });

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  final ScrollController _scrollController = ScrollController();

  double get slotHeight => 25.0;
  int get _totalSlots => widget.timeSettings.totalSlots;
  int get _slotMinutes => widget.timeSettings.slotMinutes;
  int get _dayStartHour => widget.timeSettings.dayStartHour;

  List<ScheduleItem> get _schedules => widget.schedules;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentTime());
  }

  @override
  void didUpdateWidget(_HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeSettings != widget.timeSettings) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentTime());
    }
  }

  void _scrollToCurrentTime() {
    final now = DateTime.now();
    final totalMinutes = now.hour * 60 + now.minute;
    final currentSlot = totalMinutes ~/ _slotMinutes;
    final startSlot = (_dayStartHour * 60) ~/ _slotMinutes;
    final relativeSlot = currentSlot - startSlot;
    final scrollPosition = (relativeSlot * slotHeight) - 200;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(
          scrollPosition.clamp(0.0, _scrollController.position.maxScrollExtent));
    }
  }

  double get _currentTimeRelativeOffset {
    final now = DateTime.now();
    final totalMinutes = now.hour * 60 + now.minute;
    final currentSlot = totalMinutes / _slotMinutes;
    final startSlot = (_dayStartHour * 60) / _slotMinutes;
    return (currentSlot - startSlot) * slotHeight;
  }

  Color _colorForRuleSet(String ruleSetName) {
    final idx = widget.conditionalRuleSets.indexWhere((r) => r.name == ruleSetName);
    if (idx < 0) return ruleSetColor(0);
    return widget.conditionalRuleSets[idx].color ?? ruleSetColor(idx);
  }

  int _minutesToRelativeSlot(int hour, int minute) {
    final totalMinutes = hour * 60 + minute;
    final absoluteSlot = totalMinutes ~/ _slotMinutes;
    final startSlot = (_dayStartHour * 60) ~/ _slotMinutes;
    return absoluteSlot - startSlot;
  }

  void _updateSchedules(List<ScheduleItem> updated) {
    widget.onSchedulesChanged(updated);
  }

  // ── 직접 일정 추가 ──────────────────────────────────────────
  void _showManualAddDialog() {
    TimeOfDay selectedTime = roundToNearestSlot(TimeOfDay.now(), _slotMinutes);
    int duration = _slotMinutes * 3;
    final titleController = TextEditingController();
    Color selectedColor = kUserPaletteColors[0];
    bool showTitleError = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final startAbsMin = selectedTime.hour * 60 + selectedTime.minute;
          final endAbsMin = startAbsMin + duration;
          final endHour = (endAbsMin ~/ 60) % 24;
          final endMin = endAbsMin % 60;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text('일정 추가', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText: '일정 내용',
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
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) {
                      if (showTitleError)
                        setDialogState(() => showTitleError = false);
                    },
                  ),
                  if (showTitleError)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text('제목을 입력해 주세요.',
                          style: TextStyle(
                              fontSize: 11, color: Colors.red.shade400)),
                    ),
                  const SizedBox(height: 14),
                  const Text('색상',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(kUserPaletteColors.length, (ci) {
                      final c = kUserPaletteColors[ci];
                      final isSelected = selectedColor == c;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = c),
                        child: Container(
                          width: 28,
                          height: 28,
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
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('시작 시간'),
                      TextButton(
                        onPressed: () async {
                          final time = await showTimePicker(
                              context: context, initialTime: selectedTime);
                          if (time != null) {
                            setDialogState(() => selectedTime =
                                roundToNearestSlot(time, _slotMinutes));
                          }
                        },
                        child: Text(
                          '${selectedTime.hour}시 ${selectedTime.minute.toString().padLeft(2, '0')}분',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('소요 시간'),
                      Text(
                        '$endHour시 ${endMin.toString().padLeft(2, '0')}분 종료',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (duration > _slotMinutes)
                            setDialogState(() => duration -= _slotMinutes);
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      SizedBox(
                        width: 72,
                        child: Center(
                          child: Text('$duration분',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue)),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            setDialogState(() => duration += _slotMinutes),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [_slotMinutes, _slotMinutes * 3, 60].map((val) {
                      return OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          shape: const StadiumBorder(),
                          side: const BorderSide(color: Colors.blue),
                        ),
                        onPressed: () => setDialogState(() => duration += val),
                        child: Text('+$val분',
                            style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소')),
              ElevatedButton(
                onPressed: () {
                  final title = titleController.text.trim();
                  if (title.isEmpty) {
                    setDialogState(() => showTitleError = true);
                    return;
                  }
                  if (duration > 0) {
                    final relSlot =
                        _minutesToRelativeSlot(selectedTime.hour, selectedTime.minute);
                    final durationSlots = (duration / _slotMinutes).ceil();
                    final updated = List<ScheduleItem>.from(_schedules)
                      ..add(ScheduleItem(
                          title, relSlot, durationSlots, selectedColor));
                    _updateSchedules(updated);
                    Navigator.pop(context);
                  }
                },
                child: const Text('저장'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── 루틴 적용: 시작시간 + 옵션 선택 ────────────────────────
  void _showRuleSetApplyDialog(ConditionalRuleSet ruleSet) {
    TimeOfDay selectedTime = roundToNearestSlot(TimeOfDay.now(), _slotMinutes);
    RoutineOption? selectedOption =
        ruleSet.options.isNotEmpty ? ruleSet.options.first : null;
    final color = _colorForRuleSet(ruleSet.name);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // 종료시간 계산
          String endTimeStr = '';
          if (selectedOption != null) {
            final totalMin = selectedOption?.blocks
                .fold(0, (sum, b) => sum + b.durationMinutes);
            final startMin = selectedTime.hour * 60 + selectedTime.minute;
            final endMin = startMin + totalMin!;
            final eh = (endMin ~/ 60) % 24;
            final em = endMin % 60;
            endTimeStr =
                '→ $eh시 ${em.toString().padLeft(2, '0')}분 종료';
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)),
            title: Row(
              children: [
                CircleAvatar(backgroundColor: color, radius: 8),
                const SizedBox(width: 8),
                Text(ruleSet.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 시작 시간
                  const Text('시작 시간',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      final t = await showTimePicker(
                          context: ctx, initialTime: selectedTime);
                      if (t != null) {
                        setDialogState(() => selectedTime =
                            roundToNearestSlot(t, _slotMinutes));
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${selectedTime.hour}시 ${selectedTime.minute.toString().padLeft(2, '0')}분',
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue),
                          ),
                          const Icon(Icons.edit, size: 16, color: Colors.blue),
                        ],
                      ),
                    ),
                  ),
                  if (endTimeStr.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(endTimeStr,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ),
                  const SizedBox(height: 20),
                  // 옵션 선택
                  const Text('옵션',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  if (ruleSet.options.isEmpty)
                    const Text('등록된 옵션이 없습니다.',
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey))
                  else
                    ...ruleSet.options.map((opt) {
                      final totalMin = opt.blocks
                          .fold(0, (sum, b) => sum + b.durationMinutes);
                      final isSelected = selectedOption == opt;
                      return GestureDetector(
                        onTap: () =>
                            setDialogState(() => selectedOption = opt),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: 0.3)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? color : Colors.grey.shade200,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: isSelected
                                          ? Colors.blue
                                          : Colors.grey.shade400,
                                      width: 2),
                                  color: isSelected
                                      ? Colors.blue
                                      : Colors.transparent,
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check,
                                        size: 10, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(opt.name,
                                        style: TextStyle(
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal)),
                                    Text('$totalMin분',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('취소')),
              ElevatedButton(
                onPressed: selectedOption == null
                    ? null
                    : () {
                        _applyRoutine(ruleSet, selectedOption!, selectedTime);
                        Navigator.pop(ctx);
                      },
                child: const Text('적용'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _applyRoutine(
      ConditionalRuleSet ruleSet, RoutineOption option, TimeOfDay startTime) {
    final color = _colorForRuleSet(ruleSet.name);
    final updated = List<ScheduleItem>.from(_schedules)
      ..removeWhere((s) => s.ruleSetName == ruleSet.name);

    int relSlot = _minutesToRelativeSlot(startTime.hour, startTime.minute);
    for (final block in option.blocks) {
      final durationSlots = (block.durationMinutes / _slotMinutes).ceil();
      updated.add(ScheduleItem(
        block.title,
        relSlot,
        durationSlots,
        color,
        ruleSetName: ruleSet.name,
      ));
      relSlot += durationSlots;
    }
    _updateSchedules(updated);
  }

  // ── 일정 탭 → 삭제 옵션 ────────────────────────────────────
  void _showItemMenu(ScheduleItem item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: item.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('삭제', style: TextStyle(color: Colors.red)),
              onTap: () {
                final updated = List<ScheduleItem>.from(_schedules)..remove(item);
                _updateSchedules(updated);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('닫기'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  // ── 메인 메뉴 ───────────────────────────────────────────────
  void _showMainMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('일정 추가'),
              onTap: () {
                Navigator.pop(context);
                _showManualAddDialog();
              },
            ),
            ...widget.conditionalRuleSets.asMap().entries.map((e) => ListTile(
                  leading: Icon(Icons.auto_awesome,
                      color: e.value.color ?? ruleSetColor(e.key)),
                  title: Text(e.value.name),
                  onTap: () {
                    Navigator.pop(context);
                    _showRuleSetApplyDialog(e.value);
                  },
                )),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('설정'),
              onTap: () {
                Navigator.pop(context);
                _showSettingsMenu();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('오늘 비우기',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                _updateSchedules([]);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── 설정 메뉴 ────────────────────────────────────────────────
  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('설정',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('루틴 설정'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConditionalRuleSettingsPage(
                      ruleSets: widget.conditionalRuleSets,
                      onChanged: widget.onRuleSetsChanged,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('요일별 일정 설정'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DayScheduleSettingsPage(
                      dayNames: widget.dayNames,
                      daySchedules: widget.daySchedules,
                      onChanged: widget.onDaySchedulesChanged,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('기타 설정'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GeneralSettingsPage(
                      settings: widget.timeSettings,
                      onChanged: (updated) {
                        widget.onTimeSettingsChanged(updated);
                        widget.onSchedulesChanged([]);
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── 빌드 ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          toolbarHeight: 0, elevation: 0, backgroundColor: Colors.white),
      body: _buildTimeline(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showMainMenu,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTimeline() {
    final totalSlots = _totalSlots;
    final totalHeight = totalSlots * slotHeight;

    return SingleChildScrollView(
      controller: _scrollController,
      child: SizedBox(
        height: totalHeight,
        child: Stack(
          children: [
            _buildGrid(totalSlots),
            ..._buildScheduleBlocks(),
            _buildCurrentTimeLine(totalSlots),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(int totalSlots) {
    return Column(
      children: List.generate(totalSlots, (i) {
        final absoluteMinutes = (_dayStartHour * 60) + (i * _slotMinutes);
        final hour = absoluteMinutes ~/ 60;
        final minute = absoluteMinutes % 60;
        final isOnTheHour = minute == 0;
        final isHalfHour = minute == 30;

        return Container(
          height: slotHeight,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isOnTheHour
                    ? Colors.grey.shade300
                    : isHalfHour
                        ? Colors.grey.shade200
                        : Colors.grey.shade100,
                width: isOnTheHour ? 0.8 : 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                child: isOnTheHour
                    ? Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text('$hour시',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey)),
                      )
                    : null,
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        );
      }),
    );
  }

  List<Widget> _buildScheduleBlocks() {
    return _schedules.map((item) {
      final top = item.startSlot * slotHeight;
      final height = item.durationSlots * slotHeight;

      return Positioned(
        top: top,
        left: 54,
        right: 4,
        height: height,
        child: GestureDetector(
          onTap: () => _showItemMenu(item),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 1),
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: item.color.withValues(alpha: 0.9), width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              item.title,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildCurrentTimeLine(int totalSlots) {
    final top = _currentTimeRelativeOffset;
    if (top < 0 || top > totalSlots * slotHeight) return const SizedBox.shrink();
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Row(
          children: [
            const SizedBox(width: 44),
            Container(
              width: 8,
              height: 8,
              decoration:
                  const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            ),
            Expanded(child: Container(height: 1.5, color: Colors.red)),
          ],
        ),
      ),
    );
  }
}