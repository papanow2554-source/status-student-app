import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/helpers.dart';
import 'assignment_detail_page.dart';

const List<String> _thaiMonths = [
  'มกราคม',
  'กุมภาพันธ์',
  'มีนาคม',
  'เมษายน',
  'พฤษภาคม',
  'มิถุนายน',
  'กรกฎาคม',
  'สิงหาคม',
  'กันยายน',
  'ตุลาคม',
  'พฤศจิกายน',
  'ธันวาคม',
];

const List<String> _thaiWeekdays = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// ปฏิทินงาน: จุดสีใต้วันที่แปลว่ามีงานส่งในวันนั้น
/// แดง = เลยกำหนดและยังไม่ส่ง, ส้ม = ยังไม่ส่ง, เขียว = ส่งแล้ว
class AssignmentCalendar extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final Set<String> submittedIds;

  const AssignmentCalendar({
    super.key,
    required this.docs,
    required this.submittedIds,
  });

  @override
  State<AssignmentCalendar> createState() => _AssignmentCalendarState();
}

class _AssignmentCalendarState extends State<AssignmentCalendar> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime _selected = _dateOnly(DateTime.now());

  Map<DateTime, List<QueryDocumentSnapshot<Map<String, dynamic>>>> _byDay() {
    final map =
        <DateTime, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final d in widget.docs) {
      final ts = d.data()['dueAt'];
      if (ts is! Timestamp) continue;
      map.putIfAbsent(_dateOnly(ts.toDate()), () => []).add(d);
    }
    return map;
  }

  Color _dotColor(List<QueryDocumentSnapshot<Map<String, dynamic>>> items) {
    final now = DateTime.now();
    var overdue = false;
    var pending = false;
    for (final d in items) {
      if (widget.submittedIds.contains(d.id)) continue;
      final due = (d.data()['dueAt'] as Timestamp).toDate();
      if (due.isBefore(now)) {
        overdue = true;
      } else {
        pending = true;
      }
    }
    if (overdue) return Colors.red;
    if (pending) return Colors.orange;
    return Colors.green;
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  Widget _legend(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 4, backgroundColor: c),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final byDay = _byDay();
    final today = _dateOnly(DateTime.now());

    final first = DateTime(_month.year, _month.month, 1);
    final lead = first.weekday % 7; // อาทิตย์ = 0
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final rows = ((lead + daysInMonth) / 7).ceil();

    Widget cell(int day) {
      final date = DateTime(_month.year, _month.month, day);
      final isToday = date == today;
      final isSelected = date == _selected;
      final items = byDay[date];

      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _selected = date),
        child: SizedBox(
          height: 46,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday ? primary : null,
                  border: (isSelected && !isToday)
                      ? Border.all(color: primary, width: 1.5)
                      : null,
                ),
                child: Text(
                  '$day',
                  style: TextStyle(
                    color: isToday ? Colors.white : null,
                    fontWeight: (isToday || isSelected)
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              if (items != null)
                Positioned(
                  bottom: 2,
                  child: CircleAvatar(
                    radius: 3,
                    backgroundColor: _dotColor(items),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final selectedItems = byDay[_selected] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ปฏิทินงาน',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _shiftMonth(-1),
                    ),
                    Text(
                      '${_thaiMonths[_month.month - 1]} ${_month.year + 543}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _shiftMonth(1),
                    ),
                  ],
                ),
                Row(
                  children: _thaiWeekdays
                      .map(
                        (w) => Expanded(
                          child: Center(
                            child: Text(
                              w,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 4),
                for (var r = 0; r < rows; r++)
                  Row(
                    children: List.generate(7, (c) {
                      final day = r * 7 + c - lead + 1;
                      if (day < 1 || day > daysInMonth) {
                        return const Expanded(child: SizedBox(height: 46));
                      }
                      return Expanded(child: cell(day));
                    }),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  children: [
                    _legend(Colors.orange, 'ยังไม่ส่ง'),
                    _legend(Colors.green, 'ส่งแล้ว'),
                    _legend(Colors.red, 'เลยกำหนด'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'งานวันที่ ${_selected.day} ${_thaiMonths[_selected.month - 1]}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (selectedItems.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'ไม่มีงานที่ต้องส่งในวันนี้',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          ...selectedItems.map((doc) {
            final d = doc.data();
            final type = d['type'] as String? ?? '';
            final done = widget.submittedIds.contains(doc.id);
            final diff =
                (d['dueAt'] as Timestamp).toDate().difference(DateTime.now());
            return AssignmentCard(
              icon: iconFor(type),
              iconColor: colorFor(type),
              subject: d['subject'] as String? ?? '',
              title: d['title'] as String? ?? '',
              dueText: done ? 'ส่งแล้ว' : dueText(diff),
              dueColor: done
                  ? Colors.green
                  : (diff.inHours < 24 ? Colors.red : Colors.orange),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        AssignmentDetailPage(id: doc.id, data: d),
                  ),
                );
              },
            );
          }),
        const SizedBox(height: 24),
      ],
    );
  }
}