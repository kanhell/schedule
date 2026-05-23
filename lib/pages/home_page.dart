import 'package:flutter/material.dart';
import '../models.dart';
import '../utils.dart';
import 'routine_settings_page.dart';
import 'day_schedule_settings_page.dart';
import 'general_settings_page.dart';

class ScheduleApp extends StatefulWidget {
  const ScheduleApp({super.key});
  @override
  State<ScheduleApp> createState() => _ScheduleAppState();
}

class _ScheduleAppState extends State<ScheduleApp> {
  List<ScheduleItem> schedules = [];
  final ScrollController _scrollController = ScrollController();

  TimeSettings timeSettings = const TimeSettings();

  List<ConditionalRuleSet> conditionalRuleSets = [
    ConditionalRuleSet(
      name: '저녁 루틴',
      rules: [
        ConditionalRule(
          name: '8시',
          time: const TimeOfDay(hour: 20, minute: 0),
          blocks: [ScheduleBlock(title: '저녁 루틴 A', durationMinutes: 80)],
        ),
        ConditionalRule(
          name: '8시 반',
          time: const TimeOfDay(hour: 20, minute: 30),
          blocks: [ScheduleBlock(title: '저녁 루틴 B', durationMinutes: 40)],
        ),
      ],
    ),
  ];

  final List<String> _dayNames = ['월', '화', '수', '목', '금', '토', '일'];
  late List<List<ScheduleItem>> _daySchedules;

  double get slotHeight => 25.0;

  int get _totalSlots => timeSettings.totalSlots;
  int get _slotMinutes => timeSettings.slotMinutes;
  int get _dayStartHour => timeSettings.dayStartHour;

  @override
  void initState() {
    super.initState();
    _daySchedules = List.generate(7, (_) => []);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentTime());
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

  /// 현재 시간의 슬롯 인덱스 (표시 범위 기준 상대값)
  double get _currentTimeRelativeOffset {
    final now = DateTime.now();
    final totalMinutes = now.hour * 60 + now.minute;
    final currentSlot = totalMinutes / _slotMinutes;
    final startSlot = (_dayStartHour * 60) / _slotMinutes;
    return (currentSlot - startSlot) * slotHeight;
  }

  Color _colorForRuleSet(String ruleSetName) {
    final idx = conditionalRuleSets.indexWhere((r) => r.name == ruleSetName);
    if (idx < 0) return ruleSetColor(0);
    return conditionalRuleSets[idx].color ?? ruleSetColor(idx);
  }

  // minutes → slot 인덱스 (절대값 → 표시 범위 내 상대값)
  int _minutesToRelativeSlot(int hour, int minute) {
    final totalMinutes = hour * 60 + minute;
    final absoluteSlot = totalMinutes ~/ _slotMinutes;
    final startSlot = (_dayStartHour * 60) ~/ _slotMinutes;
    return absoluteSlot - startSlot;
  }

  // ── 직접 일정 추가 ──
  void _showManualAddDialog() {
    TimeOfDay selectedTime =
        roundToNearestSlot(TimeOfDay.now(), _slotMinutes);
    int duration = _slotMinutes * 3; // 기본 3슬롯
    final titleController = TextEditingController();
    Color selectedColor = kUserPaletteColors[0];
    bool showTitleError = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final startAbsMin =
              selectedTime.hour * 60 + selectedTime.minute;
          final endAbsMin = startAbsMin + duration;
          final endHour = (endAbsMin ~/ 60) % 24;
          final endMin = endAbsMin % 60;

          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)),
            title: const Text('일정 추가',
                style: TextStyle(fontWeight: FontWeight.bold)),
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
                          color: showTitleError ? Colors.red : Colors.grey,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: showTitleError ? Colors.red : Colors.grey.shade300,
                        ),
                      ),
                    ),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) {
                      if (showTitleError) setDialogState(() => showTitleError = false);
                    },
                  ),
                  if (showTitleError)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        '제목을 입력해 주세요.',
                        style: TextStyle(fontSize: 11, color: Colors.red.shade400),
                      ),
                    ),
                  const SizedBox(height: 14),
                  // ── 색상 선택 ──
                  const Text('색상', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
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
                                : Border.all(color: Colors.transparent, width: 2.5),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 14, color: Colors.black54)
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
                              context: context,
                              initialTime: selectedTime);
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
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
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
                    children: [
                      _slotMinutes,
                      _slotMinutes * 3,
                      60
                    ].map((val) {
                      return OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          shape: const StadiumBorder(),
                          side: const BorderSide(color: Colors.blue),
                        ),
                        onPressed: () =>
                            setDialogState(() => duration += val),
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
                    _addSchedule(title, selectedTime.hour,
                        selectedTime.minute, duration, selectedColor);
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

  void _addSchedule(
      String title, int hour, int min, int durationMinutes, Color color) {
    setState(() {
      final relSlot = _minutesToRelativeSlot(hour, min);
      final durationSlots =
          (durationMinutes / _slotMinutes).ceil();
      schedules.add(ScheduleItem(
          title, relSlot, durationSlots, color));
    });
  }

  // ── 루틴 적용 ──
  void _showRuleSetApplyMenu(ConditionalRuleSet ruleSet) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(ruleSet.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.access_time_filled),
              title: const Text('지금 시간으로 적용'),
              onTap: () {
                Navigator.pop(context);
                _applyRuleSetByCurrentTime(ruleSet);
              },
            ),
            if (ruleSet.rules.isNotEmpty) ...[
              const Divider(height: 1),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('조건 선택',
                    style:
                        TextStyle(color: Colors.grey, fontSize: 13)),
              ),
              ...ruleSet.rules.map((rule) => ListTile(
                    leading: const Icon(Icons.schedule),
                    title: Text(rule.name),
                    subtitle: Text(
                        '${rule.time.hour}시 ${rule.time.minute.toString().padLeft(2, '0')}분'),
                    onTap: () {
                      Navigator.pop(context);
                      _applyRuleDirectly(ruleSet, rule);
                    },
                  )),
            ],
          ],
        ),
      ),
    );
  }

  void _removeRuleSetItems(String ruleSetName) {
    schedules.removeWhere((s) => s.ruleSetName == ruleSetName);
  }

  void _applyRuleSetByCurrentTime(ConditionalRuleSet ruleSet) {
    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;
    ConditionalRule? matched;
    for (final rule in ruleSet.rules) {
      final ruleMin = rule.time.hour * 60 + rule.time.minute;
      if (ruleMin <= nowMin) matched = rule;
    }
    final rule = matched ??
        (ruleSet.rules.isNotEmpty ? ruleSet.rules.first : null);
    if (rule != null) _applyRuleDirectly(ruleSet, rule);
  }

  void _applyRuleDirectly(
      ConditionalRuleSet ruleSet, ConditionalRule rule) {
    final color = _colorForRuleSet(ruleSet.name);
    setState(() {
      _removeRuleSetItems(ruleSet.name);
      int relSlot = _minutesToRelativeSlot(
          rule.time.hour, rule.time.minute);
      for (final block in rule.blocks) {
        final durationSlots =
            (block.durationMinutes / _slotMinutes).ceil();
        schedules.add(ScheduleItem(
          block.title,
          relSlot,
          durationSlots,
          color,
          ruleSetName: ruleSet.name,
        ));
        relSlot += durationSlots;
      }
    });
  }

  // ── 설정 ──
  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('설정',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('루틴 설정'),
              onTap: () {
                Navigator.pop(context);
                _showConditionalRuleSettings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('요일별 일정 설정'),
              onTap: () {
                Navigator.pop(context);
                _showDayScheduleSettings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('기타 설정'),
              onTap: () {
                Navigator.pop(context);
                _showGeneralSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showConditionalRuleSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConditionalRuleSettingsPage(
          ruleSets: conditionalRuleSets,
          onChanged: (updated) =>
              setState(() => conditionalRuleSets = updated),
        ),
      ),
    );
  }

  void _showDayScheduleSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DayScheduleSettingsPage(
          dayNames: _dayNames,
          daySchedules: _daySchedules,
          onChanged: (updated) =>
              setState(() => _daySchedules = updated),
        ),
      ),
    );
  }

  void _showGeneralSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GeneralSettingsPage(
          settings: timeSettings,
          onChanged: (updated) {
            setState(() {
              timeSettings = updated;
              // 설정 변경 시 기존 일정 초기화 (슬롯 기준이 바뀌므로)
              schedules.clear();
            });
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => _scrollToCurrentTime());
          },
        ),
      ),
    );
  }

  // ── 메인 메뉴 ──
  void _showMainMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
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
            ...conditionalRuleSets.asMap().entries.map((e) =>
                ListTile(
                  leading: Icon(Icons.auto_awesome,
                      color: e.value.color ?? ruleSetColor(e.key)),
                  title: Text(e.value.name),
                  onTap: () {
                    Navigator.pop(context);
                    _showRuleSetApplyMenu(e.value);
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
              leading:
                  const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('오늘 비우기',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                setState(() => schedules.clear());
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── 빌드: 핵심 수정 ──
  // ListView 하나의 itemBuilder 안에서 Stack으로 격자 + 일정블록 + 빨간선을 함께 그린다.
  // → 스크롤 오프셋 계산 불필요, 항상 정확히 위치
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar:
          AppBar(toolbarHeight: 0, elevation: 0, backgroundColor: Colors.white),
      body: _buildTimeline(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showMainMenu,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTimeline() {
    final totalSlots = _totalSlots;

    return LayoutBuilder(builder: (context, constraints) {
      final totalHeight = totalSlots * slotHeight;

      return SingleChildScrollView(
        controller: _scrollController,
        child: SizedBox(
          height: totalHeight,
          child: Stack(
            children: [
              // ① 격자 배경
              _buildGrid(totalSlots),

              // ② 일정 블록들
              ..._buildScheduleBlocks(),

              // ③ 현재 시간 빨간 선
              _buildCurrentTimeLine(totalSlots),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildGrid(int totalSlots) {
    return Column(
      children: List.generate(totalSlots, (i) {
        final absoluteMinutes =
            (_dayStartHour * 60) + (i * _slotMinutes);
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
    return schedules.map((item) {
      final top = item.startSlot * slotHeight;
      final height = item.durationSlots * slotHeight;

      return Positioned(
        top: top,
        left: 54,
        right: 4,
        height: height,
        child: GestureDetector(
          onLongPress: () => _confirmDelete(item),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 1),
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: item.color.withOpacity(0.9), width: 1),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              item.title,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w500),
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
    // 범위 밖이면 숨김
    if (top < 0 || top > totalSlots * slotHeight) {
      return const SizedBox.shrink();
    }
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
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
            ),
            Expanded(child: Container(height: 1.5, color: Colors.red)),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(ScheduleItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.title),
        content: const Text('이 일정을 삭제할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => schedules.remove(item));
              Navigator.pop(ctx);
            },
            child:
                const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}