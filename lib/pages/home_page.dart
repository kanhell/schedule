import 'package:flutter/material.dart';
import '../../models.dart';
import '../widgets/utils.dart';
import 'routine_settings_page.dart';
import 'day_schedule_settings_page.dart';
import 'general_settings_page.dart';
import 'color_label_settings_page.dart';
import '../widgets/schedule_dialogs.dart';

// ─── 홈(타임라인) 페이지 ──────────────────────────────────────
class HomePage extends StatefulWidget {
  final DateTime selectedDate;
  final List<ScheduleItem> schedules;
  final TimeSettings timeSettings;
  final List<ConditionalRuleSet> conditionalRuleSets;
  final List<String> dayNames;
  final List<List<ScheduleItem>> daySchedules;
  final List<ColorLabel> colorLabels;
  final ValueChanged<List<ScheduleItem>> onSchedulesChanged;
  final ValueChanged<TimeSettings> onTimeSettingsChanged;
  final ValueChanged<List<ConditionalRuleSet>> onRuleSetsChanged;
  final ValueChanged<List<List<ScheduleItem>>> onDaySchedulesChanged;
  final ValueChanged<List<ColorLabel>> onColorLabelsChanged;
  final Future<void> Function(DateTime) onDateChanged;

  const HomePage({
    super.key,
    required this.selectedDate,
    required this.schedules,
    required this.timeSettings,
    required this.conditionalRuleSets,
    required this.dayNames,
    required this.daySchedules,
    required this.colorLabels,
    required this.onSchedulesChanged,
    required this.onTimeSettingsChanged,
    required this.onRuleSetsChanged,
    required this.onDaySchedulesChanged,
    required this.onColorLabelsChanged,
    required this.onDateChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();

  double get slotHeight => 25.0;
  int get _slotMinutes => widget.timeSettings.slotMinutes;
  List<ScheduleItem> get _schedules => widget.schedules;

  // ── 표시 범위 동적 계산 ───────────────────────────────────────
  //
  // 하루 경계(dayBoundaryHour, 기본 5시) 기준:
  //   • slotOffset = dayBoundaryHour × 60 / slotMinutes
  //   • 일정의 절대 슬롯이 [0, boundarySlot) 이면 "전날 새벽" → 슬롯에 totalInDay 추가
  //   • 뷰 범위 = 첫 일정 시작 ~ 마지막 일정 종료, 앞뒤 3슬롯 여백
  //   • 일정 없으면 현재 시각 기준 ±2시간
  static const int _padding = 3;

  int get _totalInDay     => (24 * 60) ~/ _slotMinutes;
  int get _boundarySlot   => (widget.timeSettings.dayBoundaryHour * 60) ~/ _slotMinutes;

  /// 절대 슬롯을 "경계 기준 슬롯"으로 변환.
  /// boundary=5시 이면: 0~4시59분 슬롯 → +totalInDay, 5시 이후는 그대로.
  int _boundedSlot(int absSlot) {
    return absSlot < _boundarySlot ? absSlot + _totalInDay : absSlot;
  }

  ({int start, int end}) get _viewRange {
    if (_schedules.isEmpty) {
      final now = DateTime.now();
      final cur = _boundedSlot((now.hour * 60 + now.minute) ~/ _slotMinutes);
      final twoH = 120 ~/ _slotMinutes;
      return (start: (cur - twoH).clamp(0, _totalInDay * 2),
              end: (cur + twoH).clamp(0, _totalInDay * 2));
    }
    final boundedStarts = _schedules.map((s) => _boundedSlot(s.startSlot));
    final boundedEnds   = _schedules.map((s) => _boundedSlot(s.startSlot) + s.durationSlots);
    final minStart = boundedStarts.reduce((a, b) => a < b ? a : b);
    final maxEnd   = boundedEnds.reduce((a, b) => a > b ? a : b);
    return (start: (minStart - _padding).clamp(0, _totalInDay * 2),
            end: maxEnd + _padding);
  }

  int get _viewStartSlot => _viewRange.start;
  int get _totalSlots    => _viewRange.end - _viewRange.start;

  /// 일정 블록의 뷰 내 상대 슬롯 (top 위치 계산용)
  int _relativeSlotFor(ScheduleItem item) =>
      _boundedSlot(item.startSlot) - _viewStartSlot;

  int get _dayStartHour => (_viewStartSlot * _slotMinutes) ~/ 60;

  // ── 오늘 기준 판단 ──
  bool get _isToday {
    final now = DateTime.now();
    final d = widget.selectedDate;
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentTime());
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeSettings != widget.timeSettings ||
        oldWidget.selectedDate != widget.selectedDate) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentTime());
    }
  }

  void _scrollToCurrentTime() {
    final now = DateTime.now();
    final currentSlot = (now.hour * 60 + now.minute) ~/ _slotMinutes;
    final relativeSlot = currentSlot - _viewStartSlot;
    final scrollPosition = (relativeSlot * slotHeight) - 200;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(
          scrollPosition.clamp(0.0, _scrollController.position.maxScrollExtent));
    }
  }

  double get _currentTimeRelativeOffset {
    final now = DateTime.now();
    final currentSlot = (now.hour * 60 + now.minute) / _slotMinutes;
    return (currentSlot - _viewStartSlot) * slotHeight;
  }

  Color _colorForRuleSet(String ruleSetName) {
    final idx = widget.conditionalRuleSets.indexWhere((r) => r.name == ruleSetName);
    if (idx < 0) return ruleSetColor(0);
    return widget.conditionalRuleSets[idx].color ?? ruleSetColor(idx);
  }

  // ── 날짜 표시 문자열 ──────────────────────────────────────────
  String _getDate() {
    final d = widget.selectedDate;
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final wd = weekdays[d.weekday - 1];
    return '${d.month}/${d.day} $wd';
  }
  String _dateLabel() {
    final d = widget.selectedDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = d.difference(today).inDays;

    if (diff == 0) return '오늘';
    if (diff == 1) return '내일';
    if (diff > 1) return '$diff일뒤';
    if (diff == -1) return '어제';
    if (diff < -1) return '${-diff}일전';
    return '';
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
                showManualAddDialog(
                  context: context,
                  slotMinutes: _slotMinutes,
                  dayStartHour: _dayStartHour,
                  schedules: _schedules,
                  onSave: widget.onSchedulesChanged,
                );
              },
            ),
            ...widget.conditionalRuleSets.asMap().entries.map((e) => ListTile(
                  leading: Icon(Icons.auto_awesome,
                      color: e.value.color ?? ruleSetColor(e.key)),
                  title: Text(e.value.name),
                  onTap: () {
                    Navigator.pop(context);
                    showRuleSetApplyDialog(
                      context: context,
                      ruleSet: e.value,
                      ruleSetColor: _colorForRuleSet(e.value.name),
                      slotMinutes: _slotMinutes,
                      dayStartHour: _dayStartHour,
                      schedules: _schedules,
                      onSave: widget.onSchedulesChanged,
                    );
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
                widget.onSchedulesChanged([]);
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
                      slotMinutes: widget.timeSettings.slotMinutes,
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
                      slotMinutes: widget.timeSettings.slotMinutes,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('색상 이름 설정'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ColorLabelSettingsPage(
                      colorLabels: widget.colorLabels,
                      onChanged: widget.onColorLabelsChanged,
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
                        // slotMinutes 가 바뀌면 슬롯 인덱스 불일치 → 일정 초기화
                        if (updated.slotMinutes != widget.timeSettings.slotMinutes) {
                          widget.onSchedulesChanged([]);
                        }
                        widget.onTimeSettingsChanged(updated);
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
        toolbarHeight: 48,
        elevation: 0,
        backgroundColor: Colors.white,
        title: _buildDateNavigator(),
        actions: [
          if (!_isToday)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () => widget.onDateChanged(
                  DateTime(DateTime.now().year, DateTime.now().month,
                      DateTime.now().day),
                ),
                icon: const Icon(Icons.today, size: 16),
                label: const Text('오늘', style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
        ],
      ),
      body: _buildTimeline(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showMainMenu,
        child: const Icon(Icons.add),
      ),
    );
  }

  // ── 날짜 네비게이터 ───────────────────────────────────────────
  Widget _buildDateNavigator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, size: 22),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () => widget.onDateChanged(
              widget.selectedDate.subtract(const Duration(days: 1))),
        ),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: widget.selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2099),
            );
            if (picked != null) widget.onDateChanged(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _isToday ? Colors.blue.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getDate(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _isToday ? Colors.blue.shade700 : Colors.black87,
                  ),
                ),
                const SizedBox(width: 6),
                if (!_isToday)
                GestureDetector(
                  onTap: () => widget.onDateChanged(
                    DateTime(DateTime.now().year, DateTime.now().month,
                        DateTime.now().day),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _dateLabel(),
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 22),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () => widget.onDateChanged(
              widget.selectedDate.add(const Duration(days: 1))),
        ),
      ],
    );
  }

  // ── 타임라인 ──────────────────────────────────────────────────
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
            if (_isToday) _buildCurrentTimeLine(totalSlots),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(int totalSlots) {
    return Column(
      children: List.generate(totalSlots, (i) {
        final absoluteMinutes = (_viewStartSlot + i) * _slotMinutes;
        final hour = (absoluteMinutes ~/ 60) % 24;
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
      final top = _relativeSlotFor(item) * slotHeight;
      final height = item.durationSlots * slotHeight;

      return Positioned(
        top: top,
        left: 54,
        right: 4,
        height: height,
        child: GestureDetector(
          onTap: () => showItemMenu(
            context: context,
            item: item,
            schedules: _schedules,
            onSave: widget.onSchedulesChanged,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 1),
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(4),
              border:
                  Border.all(color: item.color.withValues(alpha: 0.9), width: 1),
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