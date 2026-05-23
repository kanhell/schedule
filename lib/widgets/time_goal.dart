import 'package:flutter/material.dart';

// ─────────────────────────────────────────
// 목표 모델
// ─────────────────────────────────────────

enum GoalType { atLeast, lessThan }

class TimeGoal {
  final String id;
  final GoalType type;
  final Color color;
  final int targetMinutes; // 30분 단위
  final List<int> resetDays; // 0=월 ~ 6=일, 빈 리스트면 매일

  const TimeGoal({
    required this.id,
    required this.type,
    required this.color,
    required this.targetMinutes,
    required this.resetDays,
  });

  TimeGoal copyWith({
    String? id,
    GoalType? type,
    Color? color,
    int? targetMinutes,
    List<int>? resetDays,
  }) =>
      TimeGoal(
        id: id ?? this.id,
        type: type ?? this.type,
        color: color ?? this.color,
        targetMinutes: targetMinutes ?? this.targetMinutes,
        resetDays: resetDays ?? this.resetDays,
      );
}
