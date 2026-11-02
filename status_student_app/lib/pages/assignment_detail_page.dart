import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/helpers.dart';

class AssignmentDetailPage extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;

  const AssignmentDetailPage({
    super.key,
    required this.id,
    required this.data,
  });

  Widget _section(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Future<void> _openSubmitSheet(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic>? existing,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final linkController =
        TextEditingController(text: (existing?['link'] as String?) ?? '');
    final noteController =
        TextEditingController(text: (existing?['note'] as String?) ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ส่งงาน',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'วางลิงก์งานของคุณ เช่น Google Drive\n'
                'ต้องตั้งสิทธิ์เป็น "ทุกคนที่มีลิงก์ดูได้" ไม่งั้นครูเปิดไม่ได้',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: linkController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'ลิงก์งาน',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'ข้อความเพิ่มเติม (ถ้ามี)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    final link = linkController.text.trim();
                    if (!link.startsWith('http')) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content:
                              Text('กรุณาใส่ลิงก์ที่ขึ้นต้นด้วย http หรือ https'),
                        ),
                      );
                      return;
                    }
                    final user = FirebaseAuth.instance.currentUser;
                    try {
                      await ref.set({
                        'assignmentId': id,
                        'studentId': user?.uid,
                        'studentEmail': user?.email,
                        'link': link,
                        'note': noteController.text.trim(),
                        'submittedAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                      messenger.showSnackBar(
                        const SnackBar(content: Text('ส่งงานเรียบร้อย')),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('ส่งงานไม่สำเร็จ: $e')),
                      );
                    }
                  },
                  child: Text(
                    existing == null ? 'ส่งงาน' : 'อัปเดตงานที่ส่ง',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = data['type'] as String? ?? '';
    final color = colorFor(type);
    final due = (data['dueAt'] as Timestamp).toDate();
    final description = data['description'] as String? ?? 'ไม่มีคำอธิบาย';
    final maxScoreNum = data['maxScore'] as num?;
    final maxScore = maxScoreNum == null ? '-' : fmtNum(maxScoreNum);

    final user = FirebaseAuth.instance.currentUser;
    final subRef = FirebaseFirestore.instance
        .collection('submissions')
        .doc('${id}_${user?.uid ?? 'anonymous'}');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: subRef.snapshots(),
      builder: (context, snapshot) {
        final sub = snapshot.data?.data();
        final submittedAt = sub?['submittedAt'];
        final note = (sub?['note'] as String?) ?? '';
        final link = (sub?['link'] as String?) ?? '';
        final score = sub?['score'] as num?;
        final comment = (sub?['comment'] as String?) ?? '';
        final graded = score != null;

        String statusText;
        Color statusColor;
        if (sub == null) {
          statusText = 'ยังไม่ส่ง';
          statusColor = Colors.orange;
        } else if (graded) {
          statusText = 'ตรวจแล้ว';
          statusColor = Colors.blue;
        } else {
          statusText = 'ส่งแล้ว (รอครูตรวจ)';
          statusColor = Colors.green;
        }

        return Scaffold(
          appBar: AppBar(title: const Text('รายละเอียดงาน')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(iconFor(type), color: color, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        data['subject'] as String? ?? '',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  data['title'] as String? ?? '',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _section('คำอธิบาย', Text(description)),
                _section('กำหนดส่ง', Text(formatDateTime(due))),
                _section('คะแนนเต็ม', Text('$maxScore คะแนน')),
                _section(
                  'สถานะ',
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (graded)
                  _section(
                    'คะแนนที่ได้',
                    Text(
                      '${fmtNum(score)} / $maxScore',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                if (graded && comment.isNotEmpty)
                  _section('ความเห็นจากครู', Text(comment)),
                if (sub != null) ...[
                  _section(
                    'ลิงก์ที่ส่ง',
                    Row(
                      children: [
                        Expanded(child: SelectableText(link)),
                        IconButton(
                          icon: const Icon(Icons.open_in_new),
                          onPressed: () => openLink(context, link),
                        ),
                      ],
                    ),
                  ),
                  if (note.isNotEmpty) _section('ข้อความเพิ่มเติม', Text(note)),
                  if (submittedAt is Timestamp)
                    _section('ส่งเมื่อ', Text(formatDateTime(submittedAt.toDate()))),
                ],
              ],
            ),
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              child: FilledButton(
                // ตรวจแล้วจะแก้ไขไม่ได้ เพื่อไม่ให้คะแนนไม่ตรงกับงาน
                onPressed:
                    graded ? null : () => _openSubmitSheet(context, subRef, sub),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  graded
                      ? 'ตรวจแล้ว'
                      : (sub == null ? 'ส่งงาน' : 'แก้ไขงานที่ส่ง'),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}