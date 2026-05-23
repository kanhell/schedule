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
  late int _dayStartHour;
  late int _dayEndHour;

  final List<int> _slotOptions = [5, 10, 15, 30];

  @override
  void initState() {
    super.initState();
    _slotMinutes = widget.settings.slotMinutes;
    _dayStartHour = widget.settings.dayStartHour;
    _dayEndHour = widget.settings.dayEndHour;
  }

  void _saveAndPop() {
    if (_dayEndHour <= _dayStartHour) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('끝 시간은 시작 시간보다 커야 합니다.')),
      );
      return;
    }
    widget.onChanged(TimeSettings(
      slotMinutes: _slotMinutes,
      dayStartHour: _dayStartHour,
      dayEndHour: _dayEndHour,
    ));
    Navigator.pop(context);
  }

  Widget _buildHourStepper({
    required String label,
    required int value,
    required int min,
    required int max,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: value > min ? onDecrement : null,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
                color: Colors.blue,
                disabledColor: Colors.grey.shade300,
              ),
              SizedBox(
                width: 64,
                child: Center(
                  child: Text(
                    '$value시',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: value < max ? onIncrement : null,
                icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 28),
                color: Colors.blue,
                disabledColor: Colors.grey.shade300,
              ),
            ],
          ),
        ),
      ],
    );
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
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── 하루 시작/끝 시간 ──
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('표시 시간 범위',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    const Text('타임라인에 표시할 시작 ~ 끝 시간',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 16),

                    // 시작 시간
                    _buildHourStepper(
                      label: '시작 시간',
                      value: _dayStartHour,
                      min: 0,
                      max: _dayEndHour - 1,
                      onDecrement: () => setState(() => _dayStartHour--),
                      onIncrement: () => setState(() {
                        _dayStartHour++;
                        if (_dayEndHour <= _dayStartHour) _dayEndHour = _dayStartHour + 1;
                      }),
                    ),

                    const Divider(height: 24),

                    // 끝 시간
                    _buildHourStepper(
                      label: '끝 시간',
                      value: _dayEndHour,
                      min: _dayStartHour + 1,
                      max: 24,
                      onDecrement: () => setState(() {
                        _dayEndHour--;
                        if (_dayEndHour <= _dayStartHour) _dayStartHour = _dayEndHour - 1;
                      }),
                      onIncrement: () => setState(() => _dayEndHour++),
                    ),

                    const Divider(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.access_time,
                              size: 16, color: Colors.blue),
                          const SizedBox(width: 6),
                          Text(
                            '$_dayStartHour:00 ~ $_dayEndHour:00  '
                            '(${_dayEndHour - _dayStartHour}시간)',
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.blue,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 안내 문구
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '설정을 변경하면 오늘 추가된 일정이 초기화됩니다.',
                      style:
                          TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
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