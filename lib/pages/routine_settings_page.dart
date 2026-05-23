import 'package:flutter/material.dart';
import '../models.dart';
import '../widgets/utils.dart';
import '../widgets/mini_timeline.dart';

class ConditionalRuleSettingsPage extends StatefulWidget {
  final List<ConditionalRuleSet> ruleSets;
  final ValueChanged<List<ConditionalRuleSet>> onChanged;
  final int slotMinutes;
  const ConditionalRuleSettingsPage(
      {super.key, required this.ruleSets, required this.onChanged, this.slotMinutes = 10});

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
              color: rs.color,
              options: rs.options
                  .map((o) => RoutineOption(
                        name: o.name,
                        blocks: o.blocks
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
    return _ruleSets[setIdx].color ?? ruleSetColor(setIdx);
  }

  // 미리보기: 시작시간 없으므로 0시 기준으로 상대 슬롯
  List<ScheduleItem> _previewItems(int setIdx, RoutineOption option) {
    final sm = widget.slotMinutes;
    final color = _colorForSet(setIdx);
    int startSlot = 0;
    final items = <ScheduleItem>[];
    for (final block in option.blocks) {
      final dSlots = (block.durationMinutes / sm).ceil();
      items.add(ScheduleItem(block.title, startSlot, dSlots, color));
      startSlot += dSlots;
    }
    return items;
  }

  // 총 소요 시간 표시
  String _totalDuration(RoutineOption option) {
    final total = option.blocks.fold(0, (sum, b) => sum + b.durationMinutes);
    final h = total ~/ 60;
    final m = total % 60;
    if (h > 0 && m > 0) return '$h시간 $m분';
    if (h > 0) return '$h시간';
    return '$m분';
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
          options: _ruleSets[setIdx].options,
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
            ConditionalRuleSet(name: name, options: [], color: selectedColor),
          ));
    }
  }

  // 옵션 추가/수정: 이름 + 소요시간만 (시작시간 없음)
  void _showOptionDialog(int setIdx, {int? editOptionIdx}) async {
    final isEdit = editOptionIdx != null;
    final existing = isEdit ? _ruleSets[setIdx].options[editOptionIdx] : null;

    final nameController = TextEditingController(text: existing?.name ?? '');
    final blockTitleController = TextEditingController(
        text: existing?.blocks.isNotEmpty == true
            ? existing!.blocks.first.title
            : '');
    final sm = widget.slotMinutes;
    int blockDuration = existing?.blocks.isNotEmpty == true
        ? existing!.blocks.first.durationMinutes
        : 60;

    final previewColor = _colorForSet(setIdx);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final dSlots = (blockDuration / sm).ceil();
          final previewItem = ScheduleItem(
            blockTitleController.text.isEmpty ? '(미리보기)' : blockTitleController.text,
            0,
            dSlots,
            previewColor,
          );

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Text(isEdit ? '옵션 수정' : '옵션 추가'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('옵션 이름', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(hintText: '예: 기본, 짧게, 길게'),
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('소요 시간',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      Text('$blockDuration분',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (blockDuration > sm)
                            setDialogState(() => blockDuration -= sm);
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Expanded(
                        child: Slider(
                          value: blockDuration.toDouble().clamp(10, 180),
                          min: 10,
                          max: 180,
                          divisions: 17,
                          label: '$blockDuration분',
                          onChanged: (v) =>
                              setDialogState(() => blockDuration = (v ~/ sm) * sm),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setDialogState(() => blockDuration += sm),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _quickAddValues(sm).map((val) {
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

    final optionName = nameController.text.trim();
    final blockTitle = blockTitleController.text.trim();
    if (optionName.isNotEmpty && blockTitle.isNotEmpty) {
      final newOption = RoutineOption(
        name: optionName,
        blocks: [ScheduleBlock(title: blockTitle, durationMinutes: blockDuration)],
      );
      setState(() {
        if (isEdit) {
          _ruleSets[setIdx].options[editOptionIdx] = newOption;
        } else {
          _ruleSets[setIdx].options.add(newOption);
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
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: _ruleSets.length,
                itemBuilder: (ctx, setIdx) {
                  final ruleSet = _ruleSets[setIdx];
                  final setColor = _colorForSet(setIdx);
                  return Card(
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 루틴 헤더
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: setColor,
                            radius: 12,
                          ),
                          title: Text(ruleSet.name,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('옵션 ${ruleSet.options.length}개',
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                tooltip: '루틴 수정',
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
                        // 옵션 목록
                        ...ruleSet.options.asMap().entries.map((e) {
                          final optIdx = e.key;
                          final option = e.value;
                          final previewItems = _previewItems(setIdx, option);
                          return ExpansionTile(
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: setColor.withValues(alpha: 0.6),
                              child: Text(
                                (optIdx + 1).toString(),
                                style: const TextStyle(fontSize: 11, color: Colors.black87,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(option.name),
                            subtitle: Text(
                              '총 ${_totalDuration(option)} · '
                              '${option.blocks.map((b) => b.title).join(', ')}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      size: 18, color: Colors.blue),
                                  tooltip: '옵션 수정',
                                  onPressed: () =>
                                      _showOptionDialog(setIdx, editOptionIdx: optIdx),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () =>
                                      setState(() => ruleSet.options.removeAt(optIdx)),
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
                          onPressed: () => _showOptionDialog(setIdx),
                          icon: const Icon(Icons.add),
                          label: const Text('옵션 추가'),
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
/// slotMinutes에 따른 빠른 추가 버튼 값 목록
List<int> _quickAddValues(int slotMinutes) {
  if (slotMinutes <= 10) return [10, 30, 60];
  if (slotMinutes == 15) return [15, 30, 60];
  return [30, 60, 120]; // 30분 단위
}