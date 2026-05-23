import 'package:flutter/material.dart';
import '../models.dart';
import 'utils.dart';
import '../persistence.dart';

// ─────────────────────────────────────────
// 다이얼로그 / 바텀시트 모음
// ─────────────────────────────────────────

/// 오늘 일정의 마지막 종료 시각(분)을 반환.
/// 일정이 없으면 null.
int? _lastEndMinute(List<ScheduleItem> schedules) {
  if (schedules.isEmpty) return null;
  return schedules
      .map((s) => s.endMinute())
      .reduce((a, b) => a > b ? a : b);
}

/// [schedules]의 마지막 종료 시각을 기본 시작 시각으로 사용.
/// 일정이 없으면 [defaultStartHour]시 0분.
TimeOfDay _defaultStartTime(
    List<ScheduleItem> schedules, int defaultStartHour, int slotMinutes) {
  final lastEnd = _lastEndMinute(schedules);
  if (lastEnd == null) {
    return TimeOfDay(hour: defaultStartHour, minute: 0);
  }
  final clamped = lastEnd.clamp(0, 23 * 60 + 59);
  final rounded = roundToNearestSlotMinutes(clamped, slotMinutes);
  return TimeOfDay(hour: (rounded ~/ 60) % 24, minute: rounded % 60);
}

/// 직접 일정 추가 다이얼로그.
Future<void> showManualAddDialog({
  required BuildContext context,
  required int slotMinutes,
  required int dayStartHour,
  required int defaultStartHour,
  required List<ScheduleItem> schedules,
  required ValueChanged<List<ScheduleItem>> onSave,
}) async {
  TimeOfDay selectedTime =
      _defaultStartTime(schedules, defaultStartHour, slotMinutes);
  int duration = 30;
  final titleController = TextEditingController();
  Color selectedColor = kUserPaletteColors[0];
  bool showTitleError = false;
  String? overlapError;
  List<String> suggestions = [];

  List<ScheduleItem> overlapping(int startMin, int durMin) {
    final newEnd = startMin + durMin;
    return schedules.where((s) {
      final sEnd = s.endMinute();
      return startMin < sEnd && newEnd > s.startMinute;
    }).toList();
  }

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        final startAbsMin =
            selectedTime.hour * 60 + selectedTime.minute;
        final endAbsMin = startAbsMin + duration;
        final endHour = (endAbsMin ~/ 60) % 24;
        final endMin = endAbsMin % 60;

        void changeColor(Color c) {
          setDialogState(() {
            selectedColor = c;
            suggestions = [];
          });
          AppPersistence.loadTitleHistory(c).then((list) {
            setDialogState(() => suggestions = list);
          });
        }

        if (suggestions.isEmpty) {
          AppPersistence.loadTitleHistory(selectedColor).then((list) {
            if (list.isNotEmpty) {
              setDialogState(() => suggestions = list);
            }
          });
        }

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('일정 추가',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 제목 입력 ──
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '일정 내용',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color:
                              showTitleError ? Colors.red : Colors.grey),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: showTitleError
                              ? Colors.red
                              : Colors.grey.shade300),
                    ),
                  ),
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  onChanged: (_) {
                    if (showTitleError) {
                      setDialogState(() => showTitleError = false);
                    }
                  },
                ),
                if (showTitleError)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text('제목을 입력해 주세요.',
                        style: TextStyle(
                            fontSize: 11, color: Colors.red.shade400)),
                  ),

                // ── 색상별 이름 추천 칩 ──
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: suggestions.take(5).map((s) {
                      return GestureDetector(
                        onTap: () {
                          titleController.text = s;
                          titleController.selection =
                              TextSelection.fromPosition(
                            TextPosition(offset: s.length),
                          );
                          setDialogState(() => showTitleError = false);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: selectedColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color:
                                    selectedColor.withValues(alpha: 0.5),
                                width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.history,
                                  size: 12, color: Colors.black45),
                              const SizedBox(width: 4),
                              Text(s,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 14),

                // ── 색상 선택 ──
                const Text('색상',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                Row(
                  children:
                      List.generate(kUserPaletteColors.length, (ci) {
                    final c = kUserPaletteColors[ci];
                    final isSelected = selectedColor == c;
                    return GestureDetector(
                      onTap: () => changeColor(c),
                      child: Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: Colors.black54, width: 2.5)
                              : Border.all(
                                  color: Colors.transparent, width: 2.5),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.black54)
                            : null,
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 14),

                // ── 시작 시간 ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('시작 시간'),
                    TextButton(
                      onPressed: () async {
                        final time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime);
                        if (time != null) {
                          setDialogState(() {
                            selectedTime = roundToNearestSlot(
                                time, slotMinutes);
                            overlapError = null;
                          });
                        }
                      },
                      child: Text(
                        '${selectedTime.hour}시 ${selectedTime.minute.toString().padLeft(2, '0')}분',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),

                // ── 겹침 오류 배너 ──
                if (overlapError != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 16, color: Colors.red.shade400),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            overlapError!,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),

                const Divider(),

                // ── 소요 시간 ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('소요 시간'),
                    Text(
                      '$endHour시 ${endMin.toString().padLeft(2, '0')}분 종료',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () {
                        if (duration > slotMinutes) {
                          setDialogState(() {
                            duration -= slotMinutes;
                            overlapError = null;
                          });
                        }
                      },
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    SizedBox(
                      width: 72,
                      child: Center(
                        child: Text('$duration분',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue)),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setDialogState(() {
                        duration += slotMinutes;
                        overlapError = null;
                      }),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _quickAddValues(slotMinutes).map((val) {
                    return OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        shape: const StadiumBorder(),
                        side: const BorderSide(color: Colors.blue),
                      ),
                      onPressed: () => setDialogState(() {
                        duration += val;
                        overlapError = null;
                      }),
                      child: Text('+$val분',
                          style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  setDialogState(() => showTitleError = true);
                  return;
                }
                if (duration <= 0) return;

                final startMin =
                    selectedTime.hour * 60 + selectedTime.minute;

                final conflicts = overlapping(startMin, duration);
                if (conflicts.isNotEmpty) {
                  final latestEnd = conflicts
                      .map((s) => s.endMinute())
                      .reduce((a, b) => a > b ? a : b);
                  final eh = (latestEnd ~/ 60) % 24;
                  final em = latestEnd % 60;
                  final names =
                      conflicts.map((s) => '「${s.title}」').join(', ');
                  setDialogState(() {
                    overlapError =
                        '$names 와 겹칩니다.\n시작 시간을 $eh시 ${em.toString().padLeft(2, '0')}분 이후로 설정해 주세요.';
                  });
                  return;
                }

                AppPersistence.recordTitle(selectedColor, title);
                final updated = List<ScheduleItem>.from(schedules)
                  ..add(ScheduleItem(title, startMin, duration,
                      selectedColor));
                onSave(updated);
                Navigator.pop(context);
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    ),
  );
}

// ─────────────────────────────────────────
// 루틴 적용 다이얼로그
// ─────────────────────────────────────────

Future<void> showRuleSetApplyDialog({
  required BuildContext context,
  required ConditionalRuleSet ruleSet,
  required Color ruleSetColor,
  required int slotMinutes,
  required int dayStartHour,
  required int defaultStartHour,
  required List<ScheduleItem> schedules,
  required ValueChanged<List<ScheduleItem>> onSave,
}) async {
  // 기본 시작 시간: 마지막 종료 시각 (또는 설정값)
  TimeOfDay selectedTime =
      _defaultStartTime(schedules, defaultStartHour, slotMinutes);
  RoutineOption? selectedOption =
      ruleSet.options.isNotEmpty ? ruleSet.options.first : null;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        String endTimeStr = '';
        if (selectedOption != null) {
          final totalMin = selectedOption!.blocks
              .fold(0, (sum, b) => sum + b.durationMinutes);
          final startMin =
              selectedTime.hour * 60 + selectedTime.minute;
          final endMin = startMin + totalMin;
          final eh = (endMin ~/ 60) % 24;
          final em = endMin % 60;
          endTimeStr = '→ $eh시 ${em.toString().padLeft(2, '0')}분 종료';
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              CircleAvatar(backgroundColor: ruleSetColor, radius: 8),
              const SizedBox(width: 8),
              Text(ruleSet.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('시작 시간',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    final t = await showTimePicker(
                        context: ctx, initialTime: selectedTime);
                    if (t != null) {
                      setDialogState(() => selectedTime =
                          roundToNearestSlot(t, slotMinutes));
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${selectedTime.hour}시 ${selectedTime.minute.toString().padLeft(2, '0')}분',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue),
                        ),
                        const Icon(Icons.edit,
                            size: 16, color: Colors.blue),
                      ],
                    ),
                  ),
                ),
                if (endTimeStr.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(endTimeStr,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ),
                const SizedBox(height: 20),
                const Text('옵션',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                if (ruleSet.options.isEmpty)
                  const Text('등록된 옵션이 없습니다.',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey))
                else
                  ...ruleSet.options.map((opt) {
                    final totalMin = opt.blocks
                        .fold(0, (sum, b) => sum + b.durationMinutes);
                    final isSelected = selectedOption == opt;
                    return GestureDetector(
                      onTap: () =>
                          setDialogState(() => selectedOption = opt),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? ruleSetColor.withValues(alpha: 0.3)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? ruleSetColor
                                : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: isSelected
                                        ? Colors.blue
                                        : Colors.grey.shade400,
                                    width: 2),
                                color: isSelected
                                    ? Colors.blue
                                    : Colors.transparent,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      size: 10, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(opt.name,
                                      style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal)),
                                  Text('$totalMin분',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소')),
            ElevatedButton(
              onPressed: selectedOption == null
                  ? null
                  : () {
                      final startMin = selectedTime.hour * 60 +
                          selectedTime.minute;

                      // singleUsePerDay: true → 같은 루틴 기존 항목 교체
                      // false → 그냥 추가 (중복 허용)
                      final updated =
                          List<ScheduleItem>.from(schedules);
                      if (ruleSet.singleUsePerDay) {
                        updated.removeWhere(
                            (s) => s.ruleSetName == ruleSet.name);
                      }

                      int curMin = startMin;
                      for (final block in selectedOption!.blocks) {
                        updated.add(ScheduleItem(
                          block.title,
                          curMin,
                          block.durationMinutes,
                          ruleSetColor,
                          ruleSetName: ruleSet.name,
                        ));
                        curMin += block.durationMinutes;
                      }
                      onSave(updated);
                      Navigator.pop(ctx);
                    },
              child: const Text('적용'),
            ),
          ],
        );
      },
    ),
  );
}

// ─────────────────────────────────────────
// 일정 아이템 메뉴 (삭제)
// ─────────────────────────────────────────

void showItemMenu({
  required BuildContext context,
  required ScheduleItem item,
  required List<ScheduleItem> schedules,
  required ValueChanged<List<ScheduleItem>> onSave,
}) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                      color: item.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ListTile(
            leading:
                const Icon(Icons.delete_outline, color: Colors.red),
            title:
                const Text('삭제', style: TextStyle(color: Colors.red)),
            onTap: () {
              final updated =
                  List<ScheduleItem>.from(schedules)..remove(item);
              onSave(updated);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('닫기'),
            onTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    ),
  );
}

/// slotMinutes에 따른 빠른 추가 버튼 값 목록
List<int> _quickAddValues(int slotMinutes) {
  if (slotMinutes <= 10) return [10, 30, 60];
  if (slotMinutes == 15) return [15, 30, 60];
  return [30, 60, 120];
}