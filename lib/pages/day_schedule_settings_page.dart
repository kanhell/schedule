import 'package:flutter/material.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets/mini_timeline.dart';
 
class DayScheduleSettingsPage extends StatefulWidget {
  final List<String> dayNames;
  final List<List<ScheduleItem>> daySchedules;
  final ValueChanged<List<List<ScheduleItem>>> onChanged;
  const DayScheduleSettingsPage(
      {super.key,
      required this.dayNames,
      required this.daySchedules,
      required this.onChanged});
 
  @override
  State<DayScheduleSettingsPage> createState() =>
      _DayScheduleSettingsPageState();
}
 
class _DayScheduleSettingsPageState extends State<DayScheduleSettingsPage> {
  late List<List<ScheduleItem>> _schedules;
  int _selectedDay = 0;
 
  @override
  void initState() {
    super.initState();
    _schedules =
        widget.daySchedules.map((list) => List<ScheduleItem>.from(list)).toList();
  }
 
  void _saveAndPop() {
    widget.onChanged(_schedules);
    Navigator.pop(context);
  }
 
  void _addItem() async {
    TimeOfDay selectedTime = roundToNearest10(TimeOfDay.now());
    int duration = 30;
    final titleController = TextEditingController();
    Color selectedColor = kUserPaletteColors[0];
    bool showTitleError = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final startSlot = (selectedTime.hour * 6) + (selectedTime.minute ~/ 10);
          final endSlot = startSlot + (duration / 10).ceil();
          final endHour = endSlot ~/ 6;
          final endMin = (endSlot % 6) * 10;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Text('${widget.dayNames[_selectedDay]}요일 일정 추가'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText: '일정 내용',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: showTitleError ? Colors.red : Colors.grey,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: showTitleError ? Colors.red : Colors.grey.shade300,
                        ),
                      ),
                    ),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) {
                      if (showTitleError) setDialogState(() => showTitleError = false);
                    },
                  ),
                  if (showTitleError)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        '제목을 입력해 주세요.',
                        style: TextStyle(fontSize: 11, color: Colors.red.shade400),
                      ),
                    ),
                  const SizedBox(height: 14),
                  const Text('색상', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(kUserPaletteColors.length, (ci) {
                      final c = kUserPaletteColors[ci];
                      final isSelected = selectedColor == c;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = c),
                        child: Container(
                          width: 28,
                          height: 28,
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
                  const SizedBox(height: 14),
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
                          if (duration > 10) setDialogState(() => duration -= 10);
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      SizedBox(
                        width: 72,
                        child: Center(
                          child: Text('$duration분',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue)),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setDialogState(() => duration += 10),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [10, 30, 60].map((val) {
                      return OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          shape: const StadiumBorder(),
                          side: const BorderSide(color: Colors.blue),
                        ),
                        onPressed: () => setDialogState(() => duration += val),
                        child: Text('+$val분', style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty) {
                    setDialogState(() => showTitleError = true);
                    return;
                  }
                  if (duration > 0) Navigator.pop(ctx);
                },
                child: const Text('저장'),
              ),
            ],
          );
        },
      ),
    );

    final title = titleController.text.trim();
    if (title.isNotEmpty && duration > 0) {
      setState(() {
        final startSlot = (selectedTime.hour * 6) + (selectedTime.minute ~/ 10);
        final durationSlots = (duration / 10).ceil();
        _schedules[_selectedDay]
            .add(ScheduleItem(title, startSlot, durationSlots, selectedColor));
      });
    }
  }
 
  @override
  Widget build(BuildContext context) {
    final items = _schedules[_selectedDay];
 
    return WillPopScope(
      onWillPop: () async {
        _saveAndPop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('요일별 일정 설정'),
          leading: BackButton(onPressed: _saveAndPop),
        ),
        body: Column(
          children: [
            // 요일 탭
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 7,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                itemBuilder: (ctx, i) => GestureDetector(
                  onTap: () => setState(() => _selectedDay = i),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: _selectedDay == i ? Colors.blue : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${widget.dayNames[i]}요일',
                      style: TextStyle(
                        color: _selectedDay == i ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        '${widget.dayNames[_selectedDay]}요일 일정이 없습니다.',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: MiniTimeline(items: items),
                            ),
                          ),
                          const Divider(height: 24),
                          ...items.asMap().entries.map((e) {
                            final i = e.key;
                            final item = e.value;
                            final startHour = item.startSlot ~/ 6;
                            final startMin = (item.startSlot % 6) * 10;
                            final endSlot = item.startSlot + item.durationSlots;
                            final endHour = endSlot ~/ 6;
                            final endMin = (endSlot % 6) * 10;
                            return ListTile(
                              leading: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: item.color,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.teal),
                                ),
                              ),
                              title: Text(item.title),
                              subtitle: Text(
                                '$startHour시 ${startMin.toString().padLeft(2, '0')}분 ~ '
                                '$endHour시 ${endMin.toString().padLeft(2, '0')}분',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red, size: 20),
                                onPressed: () => setState(
                                    () => _schedules[_selectedDay].removeAt(i)),
                              ),
                            );
                          }),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addItem,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}