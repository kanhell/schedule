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

// 하위호환용 alias (routine_settings_page 내부에서만 씀)
typedef ConditionalRule = RoutineOption;

class ScheduleBlock {
  String title;
  int durationMinutes;
  ScheduleBlock({required this.title, required this.durationMinutes});
}

class TimeSettings {
  final int slotMinutes;
  final int dayStartHour;
  final int dayEndHour;

  const TimeSettings({
    this.slotMinutes = 10,
    this.dayStartHour = 0,
    this.dayEndHour = 24,
  });

  int get totalSlots => ((dayEndHour - dayStartHour) * 60) ~/ slotMinutes;
  int get startSlotOffset => (dayStartHour * 60) ~/ slotMinutes;
  int get totalSlotsInDay => (24 * 60) ~/ slotMinutes;

  TimeSettings copyWith({int? slotMinutes, int? dayStartHour, int? dayEndHour}) {
    return TimeSettings(
      slotMinutes: slotMinutes ?? this.slotMinutes,
      dayStartHour: dayStartHour ?? this.dayStartHour,
      dayEndHour: dayEndHour ?? this.dayEndHour,
    );
  }
}