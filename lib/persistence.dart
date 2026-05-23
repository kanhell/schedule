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
  static const _keyTimeSettings  = 'time_settings';
  static const _keyRuleSets      = 'rule_sets';
  static const _keyDaySchedules  = 'day_schedules';
  static const _keyColorLabels   = 'color_labels';
  static const _keyTimeGoals     = 'time_goals';
  // 날짜별 일정: 'schedules_YYYY-MM-DD'

  // ── Color 직렬화 ──────────────────────────────────────────────
  static int   _colorToInt(Color c) => c.toARGB32();
  static Color _intToColor(int v)   => Color(v);

  // ── ScheduleItem ──────────────────────────────────────────────
  static Map<String, dynamic> _scheduleItemToJson(ScheduleItem item) => {
        'title': item.title,
        'startSlot': item.startSlot,
        'durationSlots': item.durationSlots,
        'color': _colorToInt(item.color),
        if (item.ruleSetName != null) 'ruleSetName': item.ruleSetName,
      };

  static ScheduleItem _scheduleItemFromJson(Map<String, dynamic> j) =>
      ScheduleItem(
        j['title'] as String,
        j['startSlot'] as int,
        j['durationSlots'] as int,
        _intToColor(j['color'] as int),
        ruleSetName: j['ruleSetName'] as String?,
      );

  // ── TimeSettings ──────────────────────────────────────────────
  static Map<String, dynamic> _timeSettingsToJson(TimeSettings t) => {
        'slotMinutes': t.slotMinutes,
        'dayStartHour': t.dayStartHour,
        'dayEndHour': t.dayEndHour,
      };

  static TimeSettings _timeSettingsFromJson(Map<String, dynamic> j) =>
      TimeSettings(
        slotMinutes:  j['slotMinutes']  as int,
        dayStartHour: j['dayStartHour'] as int,
        dayEndHour:   j['dayEndHour']   as int,
      );

  // ── ScheduleBlock ─────────────────────────────────────────────
  static Map<String, dynamic> _blockToJson(ScheduleBlock b) => {
        'title': b.title, 'durationMinutes': b.durationMinutes,
      };
  static ScheduleBlock _blockFromJson(Map<String, dynamic> j) =>
      ScheduleBlock(title: j['title'] as String,
                    durationMinutes: j['durationMinutes'] as int);

  // ── RoutineOption ─────────────────────────────────────────────
  static Map<String, dynamic> _optionToJson(RoutineOption o) => {
        'name': o.name, 'blocks': o.blocks.map(_blockToJson).toList(),
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
      };
  static ConditionalRuleSet _ruleSetFromJson(Map<String, dynamic> j) =>
      ConditionalRuleSet(
        name: j['name'] as String,
        options: (j['options'] as List)
            .map((o) => _optionFromJson(o as Map<String, dynamic>))
            .toList(),
        color: j['color'] != null ? _intToColor(j['color'] as int) : null,
      );

  // ── ColorLabel ────────────────────────────────────────────────
  static Map<String, dynamic> _colorLabelToJson(ColorLabel cl) =>
      {'color': _colorToInt(cl.color), 'name': cl.name};
  static ColorLabel _colorLabelFromJson(Map<String, dynamic> j) =>
      ColorLabel(color: _intToColor(j['color'] as int), name: j['name'] as String);

  // ── 날짜별 일정 저장/불러오기 ──────────────────────────────────
  /// key: 'schedules_YYYY-MM-DD'
  static String _schedulesKey(DateTime date) =>
      'schedules_${_dateString(date)}';

  static Future<void> saveSchedulesForDate(
      DateTime date, List<ScheduleItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _schedulesKey(date), jsonEncode(items.map(_scheduleItemToJson).toList()));
  }

  static Future<List<ScheduleItem>> loadSchedulesForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_schedulesKey(date));
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
    final raw = prefs.getString(_keyTimeSettings);
    if (raw == null) return const TimeSettings();
    return _timeSettingsFromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  // ── RuleSets ──────────────────────────────────────────────────
  static Future<void> saveRuleSets(List<ConditionalRuleSet> ruleSets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyRuleSets, jsonEncode(ruleSets.map(_ruleSetToJson).toList()));
  }

  static Future<List<ConditionalRuleSet>?> loadRuleSets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyRuleSets);
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
    final raw = prefs.getString(_keyDaySchedules);
    if (raw == null) return List.generate(7, (_) => []);
    final outer = jsonDecode(raw) as List;
    return outer
        .map((day) => (day as List)
            .map((e) => _scheduleItemFromJson(e as Map<String, dynamic>))
            .toList())
        .toList();
  }

  // ── 색상별 일정 이름 이력 ─────────────────────────────────────
  // key: 'title_history_RRGGBB' → JSON 배열 (최신순, 최대 30개)
  static String _titleHistoryKey(Color color) =>
      'title_history_${color.toARGB32().toRadixString(16)}';

  /// 일정 저장 시 호출 — 해당 색상의 이름 이력에 추가
  static Future<void> recordTitle(Color color, String title) async {
    if (title.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _titleHistoryKey(color);
    final raw = prefs.getString(key);
    final List<dynamic> list = raw != null ? jsonDecode(raw) as List : [];

    // 중복 제거 후 맨 앞에 삽입, 최대 30개 유지
    final titles = list.cast<String>();
    titles.remove(title);
    titles.insert(0, title);
    if (titles.length > 30) titles.removeRange(30, titles.length);

    await prefs.setString(key, jsonEncode(titles));
  }

  /// 해당 색상의 이름 이력 반환 (최신순)
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
        _keyColorLabels, jsonEncode(labels.map(_colorLabelToJson).toList()));
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
  static Map<String, dynamic> _timeGoalToJson(TimeGoal g) => {
        'id': g.id,
        'type': g.type.name,
        'color': _colorToInt(g.color),
        'targetMinutes': g.targetMinutes,
        'resetDays': g.resetDays,
      };

  static TimeGoal _timeGoalFromJson(Map<String, dynamic> j) => TimeGoal(
        id: j['id'] as String,
        type: GoalType.values.byName(j['type'] as String),
        color: _intToColor(j['color'] as int),
        targetMinutes: j['targetMinutes'] as int,
        resetDays: (j['resetDays'] as List).cast<int>(),
      );

  static Future<void> saveTimeGoals(List<TimeGoal> goals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyTimeGoals, jsonEncode(goals.map(_timeGoalToJson).toList()));
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

  // ── 전체 초기 로딩 (오늘 날짜 기준) ──────────────────────────
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
      'schedules':    results[0],
      'timeSettings': results[1],
      'ruleSets':     results[2],
      'daySchedules': results[3],
      'colorLabels':  results[4],
      'timeGoals':    results[5],
    };
  }

  // ── 내부 유틸 ─────────────────────────────────────────────────
  static String _dateString(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}