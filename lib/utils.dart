import 'package:flutter/material.dart';

// ─────────────────────────────────────────
// 색상 팔레트 (루틴셋별 고유)
// ─────────────────────────────────────────

const List<Color> kRuleSetColors = [
  Color(0xFFBBDEFB), // blue
  Color(0xFFC8E6C9), // green
  Color(0xFFFFCCBC), // deep orange
  Color(0xFFE1BEE7), // purple
  Color(0xFFFFF9C4), // yellow
  Color(0xFFB2EBF2), // cyan
  Color(0xFFFFCDD2), // red
  Color(0xFFD7CCC8), // brown
];

Color ruleSetColor(int index) => kRuleSetColors[index % kRuleSetColors.length];

// ─────────────────────────────────────────
// 유틸 함수
// ─────────────────────────────────────────

/// slotMinutes 단위로 반올림
TimeOfDay roundToNearestSlot(TimeOfDay t, int slotMinutes) {
  final totalMinutes = t.hour * 60 + t.minute;
  final half = slotMinutes ~/ 2;
  final rounded = ((totalMinutes + half) ~/ slotMinutes) * slotMinutes;
  return TimeOfDay(hour: (rounded ~/ 60) % 24, minute: rounded % 60);
}

/// 하위 호환 (10분 고정)
TimeOfDay roundToNearest10(TimeOfDay t) => roundToNearestSlot(t, 10);

String formatSlotTime(int slot, int slotMinutes) {
  final totalMinutes = slot * slotMinutes;
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  return '$h시 ${m.toString().padLeft(2, '0')}분';
}