import 'package:flutter/material.dart';
import 'models.dart';
import 'widgets/utils.dart';

// ─────────────────────────────────────────
// 앱 전역 설정 (루틴셋 등 공유 상태)
// ─────────────────────────────────────────

class AppSettings {
  static Color colorForRuleSet(
      List<ConditionalRuleSet> ruleSets, String ruleSetName) {
    final idx = ruleSets.indexWhere((r) => r.name == ruleSetName);
    return ruleSetColor(idx < 0 ? 0 : idx);
  }
}