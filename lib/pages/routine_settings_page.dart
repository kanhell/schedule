import 'package:flutter/material.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets/mini_timeline.dart';

class ConditionalRuleSettingsPage extends StatefulWidget {
  final List<ConditionalRuleSet> ruleSets;
  final ValueChanged<List<ConditionalRuleSet>> onChanged;
  const ConditionalRuleSettingsPage(
      {super.key, required this.ruleSets, required this.onChanged});

  @override
  State<ConditionalRuleSettingsPage> createState() =>
      _ConditionalRuleSettingsPageState();
}

class _ConditionalRuleSettingsPageState
    extends State<ConditionalRuleSettingsPage> {
  late List<ConditionalRuleSet> _ruleSets;

  @override
  void initState() {
    super.initState();
    _ruleSets = widget.ruleSets
        .map((rs) => ConditionalRuleSet(
              name: rs.name,
              rules: rs.rules
                  .map((r) => ConditionalRule(
                        name: r.name,
                        time: r.time,
                        blocks: r.blocks
                            .map((b) => ScheduleBlock(
                                  title: b.title,
                                  durationMinutes: b.durationMinutes,
                                ))
                            .toList(),
                      ))
                  .toList(),
            ))
        .toList();
  }

  void _saveAndPop() {
    widget.onChanged(_ruleSets);
    Navigator.pop(context);
  }

  Color _colorForSet(int setIdx) {
    final customColor = _ruleSets[setIdx].color;
    return customColor ?? ruleSetColor(setIdx);
  }

  List<ScheduleItem> _previewItems(int setIdx, ConditionalRule rule) {
    final color = _colorForSet(setIdx);
    int startSlot = (rule.time.hour * 6) + (rule.time.minute ~/ 10);
    final items = <ScheduleItem>[];
    for (final block in rule.blocks) {
      final dSlots = (block.durationMinutes / 10).ceil();
      items.add(ScheduleItem(block.title, startSlot, dSlots, color));
      startSlot += dSlots;
    }
    return items;
  }

  void _editRuleSetName(int setIdx) async {
    final controller = TextEditingController(text: _ruleSets[setIdx].name);
    Color selectedColor = _colorForSet(setIdx);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('루틴 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(hintText: '루틴 이름'),
              ),
              const SizedBox(height: 16),
              const Text('색상', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                children: List.generate(kUserPaletteColors.length, (ci) {
                  final c = kUserPaletteColors[ci];
                  final isSelected = selectedColor == c;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = c),
                    child: Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black54, width: 2.5)
                            : Border.all(color: Colors.transparent, width: 2.5),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 14, color: Colors.black54)
                          : null,
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    final newName = controller.text.trim();
    if (newName.isNotEmpty) {
      setState(() {
        _ruleSets[setIdx] = ConditionalRuleSet(
          name: newName,
          rules: _ruleSets[setIdx].rules,
          color: selectedColor,
        );
      });
    }
  }

  void _addRuleSet() async {
    String name = '';
    Color selectedColor = kUserPaletteColors[0];
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('루틴 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                autofocus: true,
                decoration: const InputDecoration(hintText: '예: 저녁 루틴'),
                onChanged: (v) => name = v,
              ),
              const SizedBox(height: 16),
              const Text('색상', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                children: List.generate(kUserPaletteColors.length, (ci) {
                  final c = kUserPaletteColors[ci];
                  final isSelected = selectedColor == c;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = c),
                    child: Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black54, width: 2.5)
                            : Border.all(color: Colors.transparent, width: 2.5),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 14, color: Colors.black54)
                          : null,
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                if (name.isNotEmpty) Navigator.pop(ctx);
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
    if (name.isNotEmpty) {
      setState(() => _ruleSets.add(
            ConditionalRuleSet(name: name, rules: [], color: selectedColor),
          ));
    }
  }

  void _showRuleDialog(int setIdx, {int? editRuleIdx}) async {
    final isEdit = editRuleIdx != null;
    final existing = isEdit ? _ruleSets[setIdx].rules[editRuleIdx] : null;

    final nameController = TextEditingController(text: existing?.name ?? '');
    final blockTitleController = TextEditingController(
        text: existing?.blocks.isNotEmpty == true ? existing!.blocks.first.title : '');
    TimeOfDay selectedTime = existing?.time ?? const TimeOfDay(hour: 20, minute: 0);
    int blockDuration = existing?.blocks.isNotEmpty == true
        ? existing!.blocks.first.durationMinutes
        : 60;

    final previewColor = _colorForSet(setIdx);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final startSlot = (selectedTime.hour * 6) + (selectedTime.minute ~/ 10);
          final endSlot = startSlot + (blockDuration / 10).ceil();
          final endHour = endSlot ~/ 6;
          final endMin = (endSlot % 6) * 10;

          final previewItem = ScheduleItem(
            blockTitleController.text.isEmpty ? '(미리보기)' : blockTitleController.text,
            startSlot,
            (blockDuration / 10).ceil(),
            previewColor,
          );

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Text(isEdit ? '조건 수정' : '조건 추가'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('조건 이름', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(hintText: '예: 8시, 8시 반'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('시작 시간'),
                      TextButton(
                        onPressed: () async {
                          final t = await showTimePicker(
                              context: ctx, initialTime: selectedTime);
                          if (t != null) {
                            setDialogState(() => selectedTime = roundToNearest10(t));
                          }
                        },
                        child: Text(
                            '${selectedTime.hour}시 ${selectedTime.minute.toString().padLeft(2, '0')}분'),
                      ),
                    ],
                  ),
                  const Divider(),
                  const Text('스케줄 블록 제목',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  TextField(
                    controller: blockTitleController,
                    decoration: const InputDecoration(hintText: '예: 저녁 루틴 A'),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('소요 시간'),
                      Text('$endHour시 ${endMin.toString().padLeft(2, '0')}분 종료',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (blockDuration > 10)
                            setDialogState(() => blockDuration -= 10);
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      SizedBox(
                        width: 72,
                        child: Center(
                          child: Text('$blockDuration분',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue)),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setDialogState(() => blockDuration += 10),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [10, 30, 60].map((val) {
                      return OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          shape: const StadiumBorder(),
                          side: const BorderSide(color: Colors.blue),
                        ),
                        onPressed: () => setDialogState(() => blockDuration += val),
                        child: Text('+$val분', style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text('미리보기', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: MiniTimeline(items: [previewItem]),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.trim().isNotEmpty &&
                      blockTitleController.text.trim().isNotEmpty) {
                    Navigator.pop(ctx);
                  }
                },
                child: Text(isEdit ? '저장' : '추가'),
              ),
            ],
          );
        },
      ),
    );

    final ruleName = nameController.text.trim();
    final blockTitle = blockTitleController.text.trim();
    if (ruleName.isNotEmpty && blockTitle.isNotEmpty) {
      final newRule = ConditionalRule(
        name: ruleName,
        time: selectedTime,
        blocks: [ScheduleBlock(title: blockTitle, durationMinutes: blockDuration)],
      );
      setState(() {
        if (isEdit) {
          _ruleSets[setIdx].rules[editRuleIdx] = newRule;
        } else {
          _ruleSets[setIdx].rules.add(newRule);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _saveAndPop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('루틴 설정'),
          leading: BackButton(onPressed: _saveAndPop),
        ),
        body: _ruleSets.isEmpty
            ? const Center(
                child: Text('루틴이 없습니다.\n아래 버튼으로 추가하세요.',
                    textAlign: TextAlign.center))
            : ListView.builder(
                itemCount: _ruleSets.length,
                itemBuilder: (ctx, setIdx) {
                  final ruleSet = _ruleSets[setIdx];
                  final setColor = _colorForSet(setIdx);
                  return Card(
                    margin: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: setColor,
                            radius: 10,
                          ),
                          title: Text(ruleSet.name,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                tooltip: '루틴 이름 수정',
                                onPressed: () => _editRuleSetName(setIdx),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () =>
                                    setState(() => _ruleSets.removeAt(setIdx)),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        ...ruleSet.rules.asMap().entries.map((e) {
                          final ruleIdx = e.key;
                          final rule = e.value;
                          final previewItems = _previewItems(setIdx, rule);
                          return ExpansionTile(
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: setColor.withOpacity(0.5),
                              child: Text(
                                rule.name.length > 3
                                    ? rule.name.substring(0, 3)
                                    : rule.name,
                                style: const TextStyle(fontSize: 10, color: Colors.black87),
                              ),
                            ),
                            title: Text(rule.name),
                            subtitle: Text(
                              '${rule.time.hour}시 ${rule.time.minute.toString().padLeft(2, '0')}분 · '
                              '${rule.blocks.map((b) => b.title).join(', ')}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      size: 18, color: Colors.blue),
                                  tooltip: '조건 수정',
                                  onPressed: () =>
                                      _showRuleDialog(setIdx, editRuleIdx: ruleIdx),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () =>
                                      setState(() => ruleSet.rules.removeAt(ruleIdx)),
                                ),
                              ],
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('미리보기',
                                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade200),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      child: MiniTimeline(items: previewItems),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }),
                        TextButton.icon(
                          onPressed: () => _showRuleDialog(setIdx),
                          icon: const Icon(Icons.add),
                          label: const Text('조건 추가'),
                        ),
                      ],
                    ),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addRuleSet,
          icon: const Icon(Icons.add),
          label: const Text('루틴 추가'),
        ),
      ),
    );
  }
}