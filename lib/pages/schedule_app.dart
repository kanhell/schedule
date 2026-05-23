import 'package:flutter/material.dart';
import '../models.dart';
import '../widgets/utils.dart';
import '../persistence.dart';
import 'home_page.dart';
import 'routine_settings_page.dart';
import 'day_schedule_settings_page.dart';
import 'general_settings_page.dart';
import 'color_label_settings_page.dart';
import 'analysis_page.dart';

// ─── 네비게이션 루트 ───────────────────────────────────────────
class ScheduleApp extends StatefulWidget {
  const ScheduleApp({super.key});
  @override
  State<ScheduleApp> createState() => _ScheduleAppState();
}

class _ScheduleAppState extends State<ScheduleApp> {
  int _currentIndex = 0;
  bool _loaded = false;

  // ── 선택된 날짜 (오늘 = 기본) ──
  DateTime _selectedDate = _today();

  // ── 공유 상태 ──
  /// 날짜별 일정 캐시. key = 'YYYY-MM-DD'
  final Map<String, List<ScheduleItem>> _schedulesCache = {};

  TimeSettings timeSettings = const TimeSettings();

  List<ConditionalRuleSet> conditionalRuleSets = _defaultRuleSets();

  final List<String> _dayNames = ['월', '화', '수', '목', '금', '토', '일'];
  late List<List<ScheduleItem>> _daySchedules;
  late List<ColorLabel> colorLabels;

  // ── 현재 선택 날짜의 일정 ──
  List<ScheduleItem> get _currentSchedules =>
      _schedulesCache[_dateKey(_selectedDate)] ?? [];

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static List<ConditionalRuleSet> _defaultRuleSets() => [
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

  @override
  void initState() {
    super.initState();
    _daySchedules = List.generate(7, (_) => []);
    colorLabels = List.generate(
      kUserPaletteColors.length,
      (i) => ColorLabel(color: kUserPaletteColors[i], name: kUserPaletteLabels[i]),
    );
    _loadAll();
  }

  Future<void> _loadAll() async {
    final data = await AppPersistence.loadAll();
    if (!mounted) return;
    setState(() {
      final todaySchedules = data['schedules'] as List<ScheduleItem>;
      _schedulesCache[_dateKey(_selectedDate)] = todaySchedules;

      timeSettings = data['timeSettings'] as TimeSettings;

      final savedRuleSets = data['ruleSets'] as List<ConditionalRuleSet>?;
      if (savedRuleSets != null) conditionalRuleSets = savedRuleSets;

      _daySchedules = data['daySchedules'] as List<List<ScheduleItem>>;

      final savedLabels = data['colorLabels'] as List<ColorLabel>?;
      if (savedLabels != null) colorLabels = savedLabels;

      _loaded = true;
    });
  }

  // ── 날짜 이동 ─────────────────────────────────────────────────
  Future<void> _changeDate(DateTime newDate) async {
    final key = _dateKey(newDate);
    if (!_schedulesCache.containsKey(key)) {
      final items = await AppPersistence.loadSchedulesForDate(newDate);
      if (!mounted) return;
      _schedulesCache[key] = items;
    }
    if (!mounted) return;
    setState(() => _selectedDate = newDate);
  }

  // ── 상태 변경 + 저장 ──────────────────────────────────────────
  void _setSchedules(List<ScheduleItem> s) {
    setState(() => _schedulesCache[_dateKey(_selectedDate)] = s);
    AppPersistence.saveSchedulesForDate(_selectedDate, s);
  }

  void _setTimeSettings(TimeSettings t) {
    setState(() => timeSettings = t);
    AppPersistence.saveTimeSettings(t);
  }

  void _setRuleSets(List<ConditionalRuleSet> r) {
    setState(() => conditionalRuleSets = r);
    AppPersistence.saveRuleSets(r);
  }

  void _setDaySchedules(List<List<ScheduleItem>> d) {
    setState(() => _daySchedules = d);
    AppPersistence.saveDaySchedules(d);
  }

  void _setColorLabels(List<ColorLabel> cl) {
    setState(() => colorLabels = cl);
    AppPersistence.saveColorLabels(cl);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pages = [
      HomePage(
        selectedDate: _selectedDate,
        schedules: _currentSchedules,
        timeSettings: timeSettings,
        conditionalRuleSets: conditionalRuleSets,
        dayNames: _dayNames,
        daySchedules: _daySchedules,
        colorLabels: colorLabels,
        onSchedulesChanged: _setSchedules,
        onTimeSettingsChanged: _setTimeSettings,
        onRuleSetsChanged: _setRuleSets,
        onDaySchedulesChanged: _setDaySchedules,
        onColorLabelsChanged: _setColorLabels,
        onDateChanged: _changeDate,
      ),
      AnalysisPage(
        schedules: _currentSchedules,
        timeSettings: timeSettings,
        colorLabels: colorLabels,
        onColorLabelsChanged: _setColorLabels,
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
