import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const Map<String, String> subjectNames = {
  'math': 'คณิตศาสตร์',
  'thai': 'ภาษาไทย',
  'cs': 'วิทยาการคำนวณ',
  'science': 'วิทยาศาสตร์',
  'social': 'สังคมศึกษา',
  'english': 'ภาษาอังกฤษ',
};

String dueText(Duration diff) {
  if (diff.isNegative) return 'เลยกำหนดแล้ว';
  if (diff.inHours < 24) return 'ส่งภายใน ${diff.inHours} ชม.';
  return 'เหลือเวลา ${diff.inDays} วัน';
}

IconData iconFor(String type) {
  switch (type) {
    case 'math':
      return Icons.calculate;
    case 'thai':
      return Icons.menu_book;
    case 'cs':
      return Icons.computer;
    case 'science':
      return Icons.science;
    case 'social':
      return Icons.public;
    case 'english':
      return Icons.language;
    default:
      return Icons.assignment;
  }
}

Color colorFor(String type) {
  switch (type) {
    case 'math':
      return Colors.blue;
    case 'thai':
      return Colors.green;
    case 'cs':
      return Colors.teal;
    case 'science':
      return Colors.purple;
    case 'social':
      return Colors.orange;
    case 'english':
      return Colors.pink;
    default:
      return Colors.grey;
  }
}

String fmtNum(num n) =>
    n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1);

String gradeFor(double percent) {
  if (percent >= 80) return 'A';
  if (percent >= 75) return 'B+';
  if (percent >= 70) return 'B';
  if (percent >= 65) return 'C+';
  if (percent >= 60) return 'C';
  if (percent >= 55) return 'D+';
  if (percent >= 50) return 'D';
  return 'F';
}

/// ทำให้ชื่อห้องเปรียบเทียบกันได้ (ตัดช่องว่าง, ไม่สนตัวพิมพ์เล็กใหญ่)
String normalizeClassroom(String? s) =>
    (s ?? '').replaceAll(RegExp(r'\s+'), '').toLowerCase();

/// งานที่ไม่ระบุห้อง = ทุกห้อง, ถ้าระบุห้อง นักเรียนต้องอยู่ห้องเดียวกัน
bool matchesClassroom(String? assignmentRoom, String? studentRoom) {
  final a = normalizeClassroom(assignmentRoom);
  if (a.isEmpty) return true;
  return a == normalizeClassroom(studentRoom);
}

String formatDateTime(DateTime d) {
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day}/${d.month}/${d.year + 543} เวลา $hh:$mm น.';
}

/// เปิดลิงก์ (เช่น Google Drive) ในเบราว์เซอร์
Future<void> openLink(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  var ok = false;
  try {
    final uri = Uri.tryParse(url.trim());
    if (uri != null && uri.hasScheme) {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {
    ok = false;
  }
  if (!ok) {
    messenger.showSnackBar(
      const SnackBar(content: Text('เปิดลิงก์ไม่สำเร็จ')),
    );
  }
}

class AssignmentCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String subject;
  final String title;
  final String dueText;
  final Color dueColor;
  final VoidCallback? onTap;

  const AssignmentCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.subject,
    required this.title,
    required this.dueText,
    required this.dueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.15),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subject),
        trailing:
            Text(dueText, style: TextStyle(color: dueColor, fontSize: 12)),
      ),
    );
  }
}