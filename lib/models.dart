import 'package:flutter/material.dart';

class ScheduleItem {
  String title;
  int startSlot;
  int durationSlots;
  Color color;
  String? ruleSetName;

  ScheduleItem(this.title, this.startSlot, this.durationSlots, this.color,
      {this.ruleSetName});
}

// 옵션(구 조건): 이름 + 소요시간만 (시작시간 없음)
class RoutineOption {
  String name;
  List<ScheduleBlock> blocks;
  RoutineOption({required this.name, required this.blocks});
}

class ConditionalRuleSet {
  String name;
  List<RoutineOption> options;
  Color? color;
  ConditionalRuleSet({required this.name, required this.options, this.color});
}

// 하위호환용 alias
typedef ConditionalRule = RoutineOption;

class ScheduleBlock {
  String title;
  int durationMinutes;
  ScheduleBlock({required this.title, required this.durationMinutes});
}

/// 색상 팔레트 6색 각각에 사용자가 붙이는 이름
class ColorLabel {
  final Color color;
  final String name;
  const ColorLabel({required this.color, required this.name});
  ColorLabel copyWith({Color? color, String? name}) =>
      ColorLabel(color: color ?? this.color, name: name ?? this.name);
}

class TimeSettings {
  final int slotMinutes;
  /// 하루 경계 시간 (기본 오전 5시).
  /// 이 시각 이전의 슬롯은 "전날의 연속"으로 간주해 타임라인을 이어 표시.
  final int dayBoundaryHour;

  const TimeSettings({
    this.slotMinutes = 10,
    this.dayBoundaryHour = 5,
    // 하위 호환용 — 무시됨
    int dayStartHour = 0,
    int dayEndHour   = 24,
  });

  /// 하루 전체 슬롯 수 (0시~24시 기준 절대 슬롯)
  int get totalSlotsInDay => (24 * 60) ~/ slotMinutes;

  // ── 하위 호환 getter ──
  int get dayStartHour => 0;
  int get dayEndHour   => 24;
  int get totalSlots   => totalSlotsInDay;
  int get startSlotOffset => 0;

  TimeSettings copyWith({int? slotMinutes, int? dayBoundaryHour}) {
    return TimeSettings(
      slotMinutes: slotMinutes ?? this.slotMinutes,
      dayBoundaryHour: dayBoundaryHour ?? this.dayBoundaryHour,
    );
  }
}