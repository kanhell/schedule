import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models.dart';

// ─── 데이터 클래스 ────────────────────────────────────────────
class ColorStat {
  final ColorLabel label;
  final int minutes;
  final double ratio;
  const ColorStat(
      {required this.label, required this.minutes, required this.ratio});
}

// ─── 도넛 차트 Painter ────────────────────────────────────────
class DonutPainter extends CustomPainter {
  final List<ColorStat> entries;
  DonutPainter(this.entries);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outerR = size.width / 2;
    final innerR = outerR * 0.58;
    const gapAngle = 0.03;

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
  bool shouldRepaint(DonutPainter old) => old.entries != entries;
}

// ─── 목표 유형 선택 칩 ────────────────────────────────────────
class GoalTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const GoalTypeChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: selected ? color : Colors.grey),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  color: selected ? color : Colors.grey,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }
}
