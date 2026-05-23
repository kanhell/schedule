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

class ConditionalRule {
  String name;
  TimeOfDay time;
  List<ScheduleBlock> blocks;
  ConditionalRule({required this.name, required this.time, required this.blocks});
}

class ConditionalRuleSet {
  String name;
  List<ConditionalRule> rules;
  Color? color; // 사용자 지정 색상 (null이면 인덱스 기본색 사용)
  ConditionalRuleSet({required this.name, required this.rules, this.color});
}

class ScheduleBlock {
  String title;
  int durationMinutes;
  ScheduleBlock({required this.title, required this.durationMinutes});
}

class TimeSettings {
  final int slotMinutes;  // 최소 시간 단위 (5, 10, 15, 30)
  final int dayStartHour; // 하루 시작 시간 (0~23)
  final int dayEndHour;   // 하루 끝 시간 (1~24)

  const TimeSettings({
    this.slotMinutes = 10,
    this.dayStartHour = 0,
    this.dayEndHour = 24,
  });

  int get totalSlots => ((dayEndHour - dayStartHour) * 60) ~/ slotMinutes;
  int get startSlotOffset => (dayStartHour * 60) ~/ slotMinutes;
  // 하루 전체 슬롯 수 (offset 포함)
  int get totalSlotsInDay => (24 * 60) ~/ slotMinutes;

  TimeSettings copyWith({int? slotMinutes, int? dayStartHour, int? dayEndHour}) {
    return TimeSettings(
      slotMinutes: slotMinutes ?? this.slotMinutes,
      dayStartHour: dayStartHour ?? this.dayStartHour,
      dayEndHour: dayEndHour ?? this.dayEndHour,
    );
  }
}