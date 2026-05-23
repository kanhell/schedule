import 'package:flutter/material.dart';
import '../models.dart';
import '../utils.dart';

/// 색상별 이름을 설정하는 페이지
class ColorLabelSettingsPage extends StatefulWidget {
  final List<ColorLabel> colorLabels;
  final ValueChanged<List<ColorLabel>> onChanged;

  const ColorLabelSettingsPage({
    super.key,
    required this.colorLabels,
    required this.onChanged,
  });

  @override
  State<ColorLabelSettingsPage> createState() => _ColorLabelSettingsPageState();
}

class _ColorLabelSettingsPageState extends State<ColorLabelSettingsPage> {
  late List<ColorLabel> _labels;
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _labels = List.from(widget.colorLabels);
    _controllers = _labels
        .map((l) => TextEditingController(text: l.name))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _saveAndPop() {
    // 빈 이름은 기본값(팔레트 라벨)으로 복원
    final updated = List.generate(_labels.length, (i) {
      final text = _controllers[i].text.trim();
      return _labels[i].copyWith(
        name: text.isEmpty ? kUserPaletteLabels[i] : text,
      );
    });
    widget.onChanged(updated);
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
          title: const Text('색상 이름 설정'),
          leading: BackButton(onPressed: _saveAndPop),
          actions: [
            TextButton(
              onPressed: _saveAndPop,
              child: const Text('저장', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '각 색상에 이름을 붙여두면 분석 페이지에서 해당 이름으로 표시됩니다.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ...List.generate(_labels.length, (i) {
              final label = _labels[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    // 색상 원
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: label.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.black12,
                          width: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // 이름 입력
                    Expanded(
                      child: TextField(
                        controller: _controllers[i],
                        decoration: InputDecoration(
                          hintText: kUserPaletteLabels[i],
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: label.color, width: 2),
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _controllers[i].clear();
                            },
                          ),
                        ),
                        textInputAction: i < _labels.length - 1
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onSubmitted: i < _labels.length - 1
                            ? (_) => FocusScope.of(context).nextFocus()
                            : (_) => _saveAndPop(),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                // 기본값으로 초기화
                for (int i = 0; i < _controllers.length; i++) {
                  _controllers[i].text = kUserPaletteLabels[i];
                }
                setState(() {});
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('기본 이름으로 초기화'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}