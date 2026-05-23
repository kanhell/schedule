import 'package:flutter/material.dart';

// ─────────────────────────────────────────
// 목표 모델
// ─────────────────────────────────────────

enum GoalType { atLeast, lessThan }

/// 세부 목표: 색상 내 특정 일정 이름을 기준으로 하는 목표
class SubGoal {
  final String id;
  final String titleKeyword; // 집계 대상 일정 이름
  final GoalType type;
  final int targetMinutes;
  final List<int> resetDays;

  const SubGoal({
    required this.id,
    required this.titleKeyword,
    required this.type,
    required this.targetMinutes,
    required this.resetDays,
  });

  SubGoal copyWith({
    String? id,
    String? titleKeyword,
    GoalType? type,
    int? targetMinutes,
    List<int>? resetDays,
  }) =>
      SubGoal(
        id: id ?? this.id,
        titleKeyword: titleKeyword ?? this.titleKeyword,
        type: type ?? this.type,
        targetMinutes: targetMinutes ?? this.targetMinutes,
        resetDays: resetDays ?? this.resetDays,
      );
}

class TimeGoal {
  final String id;
  final GoalType type;
  final Color color;
  final int targetMinutes; // 30분 단위
  final List<int> resetDays; // 0=월 ~ 6=일, 빈 리스트면 매일
  final List<SubGoal> subGoals;

  const TimeGoal({
    required this.id,
    required this.type,
    required this.color,
    required this.targetMinutes,
    required this.resetDays,
    this.subGoals = const [],
  });

  TimeGoal copyWith({
    String? id,
    GoalType? type,
    Color? color,
    int? targetMinutes,
    List<int>? resetDays,
    List<SubGoal>? subGoals,
  }) =>
      TimeGoal(
        id: id ?? this.id,
        type: type ?? this.type,
        color: color ?? this.color,
        targetMinutes: targetMinutes ?? this.targetMinutes,
        resetDays: resetDays ?? this.resetDays,
        subGoals: subGoals ?? this.subGoals,
      );
}