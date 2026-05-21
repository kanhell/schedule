import 'package:flutter/material.dart';
import '../models.dart';
 
class MiniTimeline extends StatelessWidget {
  final List<ScheduleItem> items;
  final double slotHeight;
 
  const MiniTimeline({
    super.key,
    required this.items,
    this.slotHeight = 18.0,
  });
 
  @override
  Widget build(BuildContext context) {
    const int totalSlots = 144;
 
    if (items.isEmpty) {
      return const SizedBox(
        height: 60,
        child: Center(child: Text('일정이 없습니다.', style: TextStyle(color: Colors.grey))),
      );
    }
 
    final minSlot = (items.map((e) => e.startSlot).reduce((a, b) => a < b ? a : b) - 3)
        .clamp(0, totalSlots - 1);
    final maxSlot =
        (items.map((e) => e.startSlot + e.durationSlots).reduce((a, b) => a > b ? a : b) + 3)
            .clamp(0, totalSlots);
    final visibleSlots = maxSlot - minSlot;
 
    return SizedBox(
      height: visibleSlots * slotHeight,
      child: Stack(
        children: [
          // 배경 슬롯
          Column(
            children: List.generate(visibleSlots, (i) {
              final slot = minSlot + i;
              final isOnHour = slot % 6 == 0;
              final h = slot ~/ 6;
              return Container(
                height: slotHeight,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 0.5)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: isOnHour
                          ? Text('$h시', style: const TextStyle(fontSize: 9, color: Colors.grey))
                          : null,
                    ),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              );
            }),
          ),
          // 일정 블록 오버레이
          ...items.map((item) {
            final top = (item.startSlot - minSlot) * slotHeight;
            final height = item.durationSlots * slotHeight;
            return Positioned(
              top: top,
              left: 36,
              right: 0,
              height: height,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: item.color.withOpacity(0.8), width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  item.title,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
 
