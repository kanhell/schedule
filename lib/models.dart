import 'package:flutter/material.dart';

class ScheduleItem {
  String title;
  /// 시작 시각 (자정 기준 분, 0~1439).
  /// 예) 오전 8시 30분 → 510
  int startMinute;
  /// 소요 시간 (분).
  int durationMinutes;
  Color color;
  String? ruleSetName;

  ScheduleItem(
    this.title,
    this.startMinute,
    this.durationMinutes,
    this.color, {
    this.ruleSetName,
  });

  // ── 슬롯 기반 뷰 계산용 헬퍼 ──────────────────────────────────
  int startSlot(int slotMinutes) => startMinute ~/ slotMinutes;
  int durationSlots(int slotMinutes) => (durationMinutes / slotMinutes).ceil();
  int endMinute() => startMinute + durationMinutes;
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
  /// true → 하루에 한 번만 적용 (재적용 시 기존 블록 교체)
  /// false(기본) → 하루에 여러 번 적용 가능
  bool singleUsePerDay;

  ConditionalRuleSet({
    required this.name,
    required this.options,
    this.color,
    this.singleUsePerDay = false,
  });
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

  /// 오늘 일정이 없을 때 새 일정 추가 다이얼로그의 기본 시작 시간 (시, 기본 8시)
  final int defaultStartHour;

  const TimeSettings({
    this.slotMinutes = 10,
    this.dayBoundaryHour = 5,
    this.defaultStartHour = 8,
    // 하위 호환용 — 무시됨
    int dayStartHour = 0,
    int dayEndHour = 24,
  });

  /// 하루 전체 슬롯 수 (0시~24시 기준 절대 슬롯)
  int get totalSlotsInDay => (24 * 60) ~/ slotMinutes;

  // ── 하위 호환 getter ──
  int get dayStartHour => 0;
  int get dayEndHour => 24;
  int get totalSlots => totalSlotsInDay;
  int get startSlotOffset => 0;

  TimeSettings copyWith({
    int? slotMinutes,
    int? dayBoundaryHour,
    int? defaultStartHour,
  }) {
    return TimeSettings(
      slotMinutes: slotMinutes ?? this.slotMinutes,
      dayBoundaryHour: dayBoundaryHour ?? this.dayBoundaryHour,
      defaultStartHour: defaultStartHour ?? this.defaultStartHour,
    );
  }
}