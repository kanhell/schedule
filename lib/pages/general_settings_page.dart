import 'package:flutter/material.dart';
import '../models.dart';

class GeneralSettingsPage extends StatefulWidget {
  final TimeSettings settings;
  final ValueChanged<TimeSettings> onChanged;

  const GeneralSettingsPage({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  @override
  State<GeneralSettingsPage> createState() => _GeneralSettingsPageState();
}

class _GeneralSettingsPageState extends State<GeneralSettingsPage> {
  late int _slotMinutes;
  late int _dayBoundaryHour;
  late int _defaultStartHour;

  final List<int> _slotOptions = [5, 10, 15, 30];

  @override
  void initState() {
    super.initState();
    _slotMinutes = widget.settings.slotMinutes;
    _dayBoundaryHour = widget.settings.dayBoundaryHour;
    _defaultStartHour = widget.settings.defaultStartHour;
  }

  void _saveAndPop() {
    widget.onChanged(TimeSettings(
      slotMinutes: _slotMinutes,
      dayBoundaryHour: _dayBoundaryHour,
      defaultStartHour: _defaultStartHour,
    ));
    Navigator.pop(context);
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
          title: const Text('기타 설정'),
          leading: BackButton(onPressed: _saveAndPop),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── 최소 시간 단위 ──
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('최소 시간 단위',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    const Text('타임라인 한 칸의 시간 간격',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: _slotOptions.map((min) {
                        final selected = _slotMinutes == min;
                        return ChoiceChip(
                          label: Text('$min분'),
                          selected: selected,
                          selectedColor: Colors.blue.shade100,
                          onSelected: (_) =>
                              setState(() => _slotMinutes = min),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '현재: $_slotMinutes분 단위  '
                      '(하루 ${((24 * 60) / _slotMinutes).toInt()}칸)',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 14, color: Colors.orange),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '최소 시간 단위를 변경해도 기존 일정의 시각은 유지됩니다.',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── 하루 시작 기준 시각 ──
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('하루 시작 기준 시각',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    const Text(
                      '이 시각 이전(새벽)의 일정은 전날의 연속으로 표시됩니다.',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _dayBoundaryHour > 0
                              ? () => setState(
                                  () => _dayBoundaryHour--)
                              : null,
                          icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 28),
                          color: Colors.blue,
                          disabledColor: Colors.grey.shade300,
                        ),
                        SizedBox(
                          width: 80,
                          child: Center(
                            child: Text(
                              '오전 $_dayBoundaryHour시',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _dayBoundaryHour < 12
                              ? () => setState(
                                  () => _dayBoundaryHour++)
                              : null,
                          icon: const Icon(
                              Icons.keyboard_arrow_up_rounded,
                              size: 28),
                          color: Colors.blue,
                          disabledColor: Colors.grey.shade300,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 15, color: Colors.blue),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '오전 $_dayBoundaryHour시를 기준으로 하루가 나뉩니다.\n'
                              '자정~오전 $_dayBoundaryHour시 미만은 전날 일정으로 타임라인에 이어 표시됩니다.',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── 일정 추가 기본 시작 시간 ──
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('일정 추가 기본 시작 시간',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    const Text(
                      '오늘 일정이 없을 때 새 일정 추가 다이얼로그의 기본 시작 시각입니다.\n'
                      '일정이 있으면 마지막 일정 종료 시각으로 자동 설정됩니다.',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _defaultStartHour > 0
                              ? () => setState(
                                  () => _defaultStartHour--)
                              : null,
                          icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 28),
                          color: Colors.blue,
                          disabledColor: Colors.grey.shade300,
                        ),
                        SizedBox(
                          width: 80,
                          child: Center(
                            child: Text(
                              '오전 $_defaultStartHour시',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _defaultStartHour < 23
                              ? () => setState(
                                  () => _defaultStartHour++)
                              : null,
                          icon: const Icon(
                              Icons.keyboard_arrow_up_rounded,
                              size: 28),
                          color: Colors.blue,
                          disabledColor: Colors.grey.shade300,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _saveAndPop,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('저장', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}