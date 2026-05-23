import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'widgets/time_goal.dart';

// ─────────────────────────────────────────
// 영구 저장소 헬퍼
// ─────────────────────────────────────────
// pubspec.yaml 에 아래 의존성을 추가하세요:
//   shared_preferences: ^2.3.0

class AppPersistence {
  static const _keyTimeSettings = 'time_settings_v2';
  static const _keyRuleSets = 'rule_sets_v2';
  static const _keyDaySchedules = 'day_schedules_v2';
  static const _keyColorLabels = 'color_labels';
  static const _keyTimeGoals = 'time_goals';
  // 날짜별 일정: 'schedules_v2_YYYY-MM-DD'

  // ── Color 직렬화 ──────────────────────────────────────────────
  static int _colorToInt(Color c) => c.toARGB32();
  static Color _intToColor(int v) => Color(v);

  // ── ScheduleItem (분 기준) ────────────────────────────────────
  static Map<String, dynamic> _scheduleItemToJson(ScheduleItem item) => {
        'title': item.title,
        'startMinute': item.startMinute,
        'durationMinutes': item.durationMinutes,
        'color': _colorToInt(item.color),
        if (item.ruleSetName != null) 'ruleSetName': item.ruleSetName,
      };

  static ScheduleItem _scheduleItemFromJson(Map<String, dynamic> j) {
    // 구버전(슬롯 기반) 호환: startSlot + durationSlots 가 있고 startMinute 없는 경우
    if (j.containsKey('startMinute')) {
      return ScheduleItem(
        j['title'] as String,
        j['startMinute'] as int,
        j['durationMinutes'] as int,
        _intToColor(j['color'] as int),
        ruleSetName: j['ruleSetName'] as String?,
      );
    } else {
      // 구버전: slotMinutes 를 알 수 없으므로 10분 단위 가정
      const legacySlot = 10;
      final startSlot = j['startSlot'] as int? ?? 0;
      final durationSlots = j['durationSlots'] as int? ?? 1;
      return ScheduleItem(
        j['title'] as String,
        startSlot * legacySlot,
        durationSlots * legacySlot,
        _intToColor(j['color'] as int),
        ruleSetName: j['ruleSetName'] as String?,
      );
    }
  }

  // ── TimeSettings ──────────────────────────────────────────────
  static Map<String, dynamic> _timeSettingsToJson(TimeSettings t) => {
        'slotMinutes': t.slotMinutes,
        'dayBoundaryHour': t.dayBoundaryHour,
        'defaultStartHour': t.defaultStartHour,
      };

  static TimeSettings _timeSettingsFromJson(Map<String, dynamic> j) =>
      TimeSettings(
        slotMinutes: j['slotMinutes'] as int,
        dayBoundaryHour: (j['dayBoundaryHour'] as int?) ?? 5,
        defaultStartHour: (j['defaultStartHour'] as int?) ?? 8,
      );

  // ── ScheduleBlock ─────────────────────────────────────────────
  static Map<String, dynamic> _blockToJson(ScheduleBlock b) => {
        'title': b.title,
        'durationMinutes': b.durationMinutes,
      };
  static ScheduleBlock _blockFromJson(Map<String, dynamic> j) =>
      ScheduleBlock(
          title: j['title'] as String,
          durationMinutes: j['durationMinutes'] as int);

  // ── RoutineOption ─────────────────────────────────────────────
  static Map<String, dynamic> _optionToJson(RoutineOption o) => {
        'name': o.name,
        'blocks': o.blocks.map(_blockToJson).toList(),
      };
  static RoutineOption _optionFromJson(Map<String, dynamic> j) =>
      RoutineOption(
        name: j['name'] as String,
        blocks: (j['blocks'] as List)
            .map((b) => _blockFromJson(b as Map<String, dynamic>))
            .toList(),
      );

  // ── ConditionalRuleSet ────────────────────────────────────────
  static Map<String, dynamic> _ruleSetToJson(ConditionalRuleSet r) => {
        'name': r.name,
        'options': r.options.map(_optionToJson).toList(),
        if (r.color != null) 'color': _colorToInt(r.color!),
        'singleUsePerDay': r.singleUsePerDay,
      };
  static ConditionalRuleSet _ruleSetFromJson(Map<String, dynamic> j) =>
      ConditionalRuleSet(
        name: j['name'] as String,
        options: (j['options'] as List)
            .map((o) => _optionFromJson(o as Map<String, dynamic>))
            .toList(),
        color: j['color'] != null ? _intToColor(j['color'] as int) : null,
        singleUsePerDay: (j['singleUsePerDay'] as bool?) ?? false,
      );

  // ── ColorLabel ────────────────────────────────────────────────
  static Map<String, dynamic> _colorLabelToJson(ColorLabel cl) =>
      {'color': _colorToInt(cl.color), 'name': cl.name};
  static ColorLabel _colorLabelFromJson(Map<String, dynamic> j) =>
      ColorLabel(
          color: _intToColor(j['color'] as int),
          name: j['name'] as String);

  // ── 날짜별 일정 저장/불러오기 ──────────────────────────────────
  static String _schedulesKey(DateTime date) =>
      'schedules_v2_${_dateString(date)}';

  static Future<void> saveSchedulesForDate(
      DateTime date, List<ScheduleItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_schedulesKey(date),
        jsonEncode(items.map(_scheduleItemToJson).toList()));
  }

  static Future<List<ScheduleItem>> loadSchedulesForDate(
      DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    // 새 키 먼저 시도
    String? raw = prefs.getString(_schedulesKey(date));
    // 없으면 구버전 키 시도
    raw ??= prefs.getString('schedules_${_dateString(date)}');
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => _scheduleItemFromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── TimeSettings ──────────────────────────────────────────────
  static Future<void> saveTimeSettings(TimeSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyTimeSettings, jsonEncode(_timeSettingsToJson(settings)));
  }

  static Future<TimeSettings> loadTimeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // 새 키 먼저, 없으면 구버전
    String? raw = prefs.getString(_keyTimeSettings);
    raw ??= prefs.getString('time_settings');
    if (raw == null) return const TimeSettings();
    return _timeSettingsFromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  // ── RuleSets ──────────────────────────────────────────────────
  static Future<void> saveRuleSets(
      List<ConditionalRuleSet> ruleSets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyRuleSets,
        jsonEncode(ruleSets.map(_ruleSetToJson).toList()));
  }

  static Future<List<ConditionalRuleSet>?> loadRuleSets() async {
    final prefs = await SharedPreferences.getInstance();
    String? raw = prefs.getString(_keyRuleSets);
    raw ??= prefs.getString('rule_sets');
    if (raw == null) return null;
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => _ruleSetFromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── DaySchedules (요일별 기본 일정) ───────────────────────────
  static Future<void> saveDaySchedules(
      List<List<ScheduleItem>> daySchedules) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(daySchedules
        .map((day) => day.map(_scheduleItemToJson).toList())
        .toList());
    await prefs.setString(_keyDaySchedules, json);
  }

  static Future<List<List<ScheduleItem>>> loadDaySchedules() async {
    final prefs = await SharedPreferences.getInstance();
    String? raw = prefs.getString(_keyDaySchedules);
    raw ??= prefs.getString('day_schedules');
    if (raw == null) return List.generate(7, (_) => []);
    final outer = jsonDecode(raw) as List;
    return outer
        .map((day) => (day as List)
            .map((e) =>
                _scheduleItemFromJson(e as Map<String, dynamic>))
            .toList())
        .toList();
  }

  // ── 색상별 일정 이름 이력 ─────────────────────────────────────
  static String _titleHistoryKey(Color color) =>
      'title_history_${color.toARGB32().toRadixString(16)}';

  static Future<void> recordTitle(Color color, String title) async {
    if (title.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _titleHistoryKey(color);
    final raw = prefs.getString(key);
    final List<dynamic> list =
        raw != null ? jsonDecode(raw) as List : [];

    final titles = list.cast<String>();
    titles.remove(title);
    titles.insert(0, title);
    if (titles.length > 30) titles.removeRange(30, titles.length);

    await prefs.setString(key, jsonEncode(titles));
  }

  static Future<List<String>> loadTitleHistory(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_titleHistoryKey(color));
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<String>();
  }

  // ── ColorLabels ───────────────────────────────────────────────
  static Future<void> saveColorLabels(List<ColorLabel> labels) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyColorLabels,
        jsonEncode(labels.map(_colorLabelToJson).toList()));
  }

  static Future<List<ColorLabel>?> loadColorLabels() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyColorLabels);
    if (raw == null) return null;
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => _colorLabelFromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── TimeGoal ──────────────────────────────────────────────────
  static Map<String, dynamic> _subGoalToJson(SubGoal g) => {
        'id': g.id,
        'titleKeyword': g.titleKeyword,
        'type': g.type.name,
        'targetMinutes': g.targetMinutes,
        'resetDays': g.resetDays,
      };

  static SubGoal _subGoalFromJson(Map<String, dynamic> j) => SubGoal(
        id: j['id'] as String,
        titleKeyword: j['titleKeyword'] as String,
        type: GoalType.values.byName(j['type'] as String),
        targetMinutes: j['targetMinutes'] as int,
        resetDays: (j['resetDays'] as List).cast<int>(),
      );

  static Map<String, dynamic> _timeGoalToJson(TimeGoal g) => {
        'id': g.id,
        'type': g.type.name,
        'color': _colorToInt(g.color),
        'targetMinutes': g.targetMinutes,
        'resetDays': g.resetDays,
        'subGoals': g.subGoals.map(_subGoalToJson).toList(),
      };

  static TimeGoal _timeGoalFromJson(Map<String, dynamic> j) => TimeGoal(
        id: j['id'] as String,
        type: GoalType.values.byName(j['type'] as String),
        color: _intToColor(j['color'] as int),
        targetMinutes: j['targetMinutes'] as int,
        resetDays: (j['resetDays'] as List).cast<int>(),
        subGoals: j['subGoals'] != null
            ? (j['subGoals'] as List)
                .map((s) =>
                    _subGoalFromJson(s as Map<String, dynamic>))
                .toList()
            : [],
      );

  static Future<void> saveTimeGoals(List<TimeGoal> goals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyTimeGoals,
        jsonEncode(goals.map(_timeGoalToJson).toList()));
  }

  static Future<List<TimeGoal>> loadTimeGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyTimeGoals);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => _timeGoalFromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── 전체 초기 로딩 ────────────────────────────────────────────
  static Future<Map<String, dynamic>> loadAll() async {
    final results = await Future.wait([
      loadSchedulesForDate(DateTime.now()),
      loadTimeSettings(),
      loadRuleSets(),
      loadDaySchedules(),
      loadColorLabels(),
      loadTimeGoals(),
    ]);
    return {
      'schedules': results[0],
      'timeSettings': results[1],
      'ruleSets': results[2],
      'daySchedules': results[3],
      'colorLabels': results[4],
      'timeGoals': results[5],
    };
  }

  // ── 내부 유틸 ─────────────────────────────────────────────────
  static String _dateString(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}