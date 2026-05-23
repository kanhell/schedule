import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models.dart';
import '../utils.dart';

class AnalysisPage extends StatefulWidget {
  final List<ScheduleItem> schedules;
  final TimeSettings timeSettings;
  final List<ColorLabel> colorLabels;
  final ValueChanged<List<ColorLabel>> onColorLabelsChanged;

  const AnalysisPage({
    super.key,
    required this.schedules,
    required this.timeSettings,
    required this.colorLabels,
    required this.onColorLabelsChanged,
  });

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  // 색상별 총 시간(분) 계산
  Map<Color, int> _calcMinutesByColor() {
    final map = <Color, int>{};
    for (final item in widget.schedules) {
      final minutes = item.durationSlots * widget.timeSettings.slotMinutes;
      map[item.color] = (map[item.color] ?? 0) + minutes;
    }
    return map;
  }

  // Color → ColorLabel 이름 찾기
  String _labelName(Color c) {
    try {
      return widget.colorLabels.firstWhere((l) => l.color == c).name;
    } catch (_) {
      return '기타';
    }
  }

  // 색상 이름 편집 다이얼로그
  void _editColorLabels() async {
    final controllers = widget.colorLabels
        .map((l) => TextEditingController(text: l.name))
        .toList();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('색상 이름 설정',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(widget.colorLabels.length, (i) {
              final label = widget.colorLabels[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: label.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.black12, width: 1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: controllers[i],
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              final updated = List.generate(
                widget.colorLabels.length,
                (i) => widget.colorLabels[i].copyWith(
                  name: controllers[i].text.trim().isEmpty
                      ? widget.colorLabels[i].name
                      : controllers[i].text.trim(),
                ),
              );
              widget.onColorLabelsChanged(updated);
              Navigator.pop(ctx);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes == 0) return '0분';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '$h시간 $m분';
    if (h > 0) return '$h시간';
    return '$m분';
  }

  @override
  Widget build(BuildContext context) {
    final minutesByColor = _calcMinutesByColor();
    final totalMinutes =
        minutesByColor.values.fold(0, (a, b) => a + b);

    // 팔레트 순서대로 정렬된 집계 (0분짜리도 포함)
    final entries = widget.colorLabels.map((label) {
      final minutes = minutesByColor[label.color] ?? 0;
      return _ColorStat(
        label: label,
        minutes: minutes,
        ratio: totalMinutes > 0 ? minutes / totalMinutes : 0,
      );
    }).toList();

    // 실제 기록된 색상만 (기타 포함)
    final usedEntries = entries.where((e) => e.minutes > 0).toList()
      ..sort((a, b) => b.minutes.compareTo(a.minutes));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('분석',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '색상 이름 설정',
            onPressed: _editColorLabels,
          ),
        ],
      ),
      body: widget.schedules.isEmpty
          ? _buildEmpty()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── 원형 차트 카드 ──────────────────────────
                _buildDonutCard(usedEntries, totalMinutes),
                const SizedBox(height: 16),
                // ── 색상별 상세 리스트 ──────────────────────
                _buildDetailCard(usedEntries, totalMinutes),
                const SizedBox(height: 16),
                // ── 색상 이름 범례 ──────────────────────────
                _buildLegendCard(),
              ],
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_outlined,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('오늘 일정이 없습니다.',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500)),
          const SizedBox(height: 6),
          Text('홈에서 일정을 추가하면\n색상별 시간이 여기에 표시됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildDonutCard(
      List<_ColorStat> usedEntries, int totalMinutes) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('오늘 시간 분포',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(200, 200),
                    painter: _DonutPainter(usedEntries),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatMinutes(totalMinutes),
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                      const Text('총 시간',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 범례 칩
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: usedEntries.map((e) {
                final pct = (e.ratio * 100).round();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: e.label.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text('${e.label.name} $pct%',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black87)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(
      List<_ColorStat> usedEntries, int totalMinutes) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('색상별 시간',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 16),
            ...usedEntries.map((e) => _buildStatRow(e, totalMinutes)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(_ColorStat e, int totalMinutes) {
    final pct = totalMinutes > 0
        ? (e.minutes / totalMinutes * 100).round()
        : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                    color: e.label.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(e.label.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              Text(_formatMinutes(e.minutes),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              Text('$pct%',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: e.ratio,
              minHeight: 8,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(e.label.color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('색상 이름',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                TextButton.icon(
                  onPressed: _editColorLabels,
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('편집', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: widget.colorLabels.map((label) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: label.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black12),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(label.name,
                        style: const TextStyle(fontSize: 13)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 데이터 클래스 ────────────────────────────────────────────
class _ColorStat {
  final ColorLabel label;
  final int minutes;
  final double ratio;
  const _ColorStat(
      {required this.label,
      required this.minutes,
      required this.ratio});
}

// ─── 도넛 차트 ────────────────────────────────────────────────
class _DonutPainter extends CustomPainter {
  final List<_ColorStat> entries;
  _DonutPainter(this.entries);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outerR = size.width / 2;
    final innerR = outerR * 0.58;
    const gapAngle = 0.03; // 조각 사이 간격 (라디안)

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: outerR);
    double startAngle = -math.pi / 2;

    if (entries.isEmpty) {
      final paint = Paint()
        ..color = Colors.grey.shade200
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerR - innerR;
      canvas.drawCircle(Offset(cx, cy), (outerR + innerR) / 2, paint);
      return;
    }

    for (final e in entries) {
      final sweepAngle = e.ratio * 2 * math.pi - gapAngle;
      if (sweepAngle <= 0) {
        startAngle += e.ratio * 2 * math.pi;
        continue;
      }
      final paint = Paint()
        ..color = e.label.color
        ..style = PaintingStyle.fill;

      final path = Path()
        ..moveTo(
          cx + innerR * math.cos(startAngle + gapAngle / 2),
          cy + innerR * math.sin(startAngle + gapAngle / 2),
        )
        ..arcTo(rect, startAngle + gapAngle / 2, sweepAngle, false)
        ..lineTo(
          cx + innerR * math.cos(startAngle + gapAngle / 2 + sweepAngle),
          cy + innerR * math.sin(startAngle + gapAngle / 2 + sweepAngle),
        )
        ..arcTo(
          Rect.fromCircle(center: Offset(cx, cy), radius: innerR),
          startAngle + gapAngle / 2 + sweepAngle,
          -sweepAngle,
          false,
        )
        ..close();

      canvas.drawPath(path, paint);
      startAngle += e.ratio * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.entries != entries;
}