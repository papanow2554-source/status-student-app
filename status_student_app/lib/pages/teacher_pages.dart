import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/helpers.dart';
import '../utils/notify.dart';

// ───────────────────────── หน้าหลักของครู ─────────────────────────

class TeacherHomePage extends StatelessWidget {
  const TeacherHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('งานที่มอบหมาย (ครู)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const CreateAssignmentPage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('มอบหมายงาน'),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('assignments')
              .orderBy('dueAt', descending: true)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('โหลดข้อมูลไม่สำเร็จ: ${snap.error}'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return const Center(
                child: Text('ยังไม่มีงาน กดปุ่ม "มอบหมายงาน" เพื่อเพิ่ม'),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: docs.map((doc) {
                final d = doc.data();
                final due = (d['dueAt'] as Timestamp).toDate();
                final type = d['type'] as String? ?? '';
                return AssignmentCard(
                  icon: iconFor(type),
                  iconColor: colorFor(type),
                  subject: d['subject'] as String? ?? '',
                  title: d['title'] as String? ?? '',
                  dueText: '${due.day}/${due.month}/${due.year + 543}',
                  dueColor: Colors.grey,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            SubmissionsPage(assignmentId: doc.id, data: d),
                      ),
                    );
                  },
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}

// ───────────────────────── สร้างงานใหม่ ─────────────────────────

class CreateAssignmentPage extends StatefulWidget {
  const CreateAssignmentPage({super.key});

  @override
  State<CreateAssignmentPage> createState() => _CreateAssignmentPageState();
}

class _CreateAssignmentPageState extends State<CreateAssignmentPage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _maxScoreController = TextEditingController(text: '20');
  String _type = 'math';
  late DateTime _due = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
    23,
    59,
  ).add(const Duration(days: 7));
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _maxScoreController.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_due),
    );
    if (time == null) return;
    setState(() {
      _due = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final title = _titleController.text.trim();
    final maxScore = num.tryParse(_maxScoreController.text.trim());
    if (title.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('กรุณาใส่ชื่องาน')));
      return;
    }
    if (maxScore == null || maxScore <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('คะแนนเต็มต้องเป็นตัวเลขมากกว่า 0')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final newRef =
          await FirebaseFirestore.instance.collection('assignments').add({
        'subject': subjectNames[_type] ?? '',
        'type': _type,
        'title': title,
        'description': _descController.text.trim(),
        'maxScore': maxScore,
        'dueAt': Timestamp.fromDate(_due),
        'teacherId': FirebaseAuth.instance.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      try {
        await notifyAllStudents(
          title: 'มีงานใหม่: ${subjectNames[_type] ?? ''}',
          body: title,
          assignmentId: newRef.id,
        );
      } catch (_) {
        // แจ้งเตือนส่งไม่ได้ ไม่ต้องให้การมอบหมายงานล้มเหลวไปด้วย
      }
      if (mounted) Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('มอบหมายงานแล้ว')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('มอบหมายงานใหม่')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(
                labelText: 'รายวิชา',
                border: OutlineInputBorder(),
              ),
              items: subjectNames.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'ชื่องาน',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'คำอธิบาย',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _maxScoreController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'คะแนนเต็ม',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickDue,
              icon: const Icon(Icons.event),
              label: Text('กำหนดส่ง: ${formatDateTime(_due)}'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('มอบหมายงาน'),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── รายชื่อนักเรียนต่องาน (ตรวจงาน) ─────────────────────────

class _Row {
  final String email;
  final DocumentReference<Map<String, dynamic>>? ref;
  final Map<String, dynamic>? sub;
  _Row(this.email, this.ref, this.sub);
}

class SubmissionsPage extends StatelessWidget {
  final String assignmentId;
  final Map<String, dynamic> data;

  const SubmissionsPage({
    super.key,
    required this.assignmentId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final maxScore = (data['maxScore'] as num?) ?? 0;
    final title = data['title'] as String? ?? '';

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'ทั้งหมด'),
              Tab(text: 'ส่งแล้ว'),
              Tab(text: 'ยังไม่ส่ง'),
            ],
          ),
        ),
        body: SafeArea(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'student')
                .snapshots(),
            builder: (context, uSnap) {
              if (uSnap.hasError) {
                return Center(
                  child: Text('โหลดรายชื่อนักเรียนไม่สำเร็จ: ${uSnap.error}'),
                );
              }
              if (!uSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('submissions')
                    .where('assignmentId', isEqualTo: assignmentId)
                    .snapshots(),
                builder: (context, sSnap) {
                  if (sSnap.hasError) {
                    return Center(
                      child: Text('โหลดงานที่ส่งไม่สำเร็จ: ${sSnap.error}'),
                    );
                  }
                  if (!sSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final submitted = <String, _Row>{};
                  for (final d in sSnap.data!.docs) {
                    final s = d.data();
                    final sid = (s['studentId'] as String?) ?? d.id;
                    submitted[sid] = _Row(
                      (s['studentEmail'] as String?) ?? sid,
                      d.reference,
                      s,
                    );
                  }
                  final missing = <_Row>[];
                  for (final u in uSnap.data!.docs) {
                    if (!submitted.containsKey(u.id)) {
                      missing.add(
                        _Row((u.data()['email'] as String?) ?? u.id, null, null),
                      );
                    }
                  }
                  final sent = submitted.values.toList();
                  final all = [...sent, ...missing];

                  return TabBarView(
                    children: [
                      _list(context, all, maxScore, title),
                      _list(context, sent, maxScore, title),
                      _list(context, missing, maxScore, title),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, List<_Row> rows, num maxScore, String title) {
    if (rows.isEmpty) {
      return const Center(child: Text('ไม่มีรายการ'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final r = rows[i];
        final score = r.sub?['score'] as num?;
        String status;
        Color color;
        if (r.sub == null) {
          status = 'ยังไม่ส่งงาน';
          color = Colors.red;
        } else if (score != null) {
          status = 'ตรวจแล้ว';
          color = Colors.blue;
        } else {
          status = 'รอตรวจ';
          color = Colors.orange;
        }
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(r.email.isEmpty ? '?' : r.email[0].toUpperCase()),
            ),
            title: Text(r.email),
            subtitle: Text(status, style: TextStyle(color: color)),
            trailing: score != null
                ? Text(
                    '${fmtNum(score)}/${fmtNum(maxScore)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : (r.sub != null ? const Icon(Icons.chevron_right) : null),
            onTap: r.sub == null
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => GradePage(
                          ref: r.ref!,
                          email: r.email,
                          sub: r.sub!,
                          maxScore: maxScore,
                          assignmentTitle: title,
                        ),
                      ),
                    );
                  },
          ),
        );
      },
    );
  }
}

// ───────────────────────── ให้คะแนน ─────────────────────────

class GradePage extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> ref;
  final String email;
  final Map<String, dynamic> sub;
  final num maxScore;
  final String assignmentTitle;

  const GradePage({
    super.key,
    required this.ref,
    required this.email,
    required this.sub,
    required this.maxScore,
    required this.assignmentTitle,
  });

  @override
  State<GradePage> createState() => _GradePageState();
}

class _GradePageState extends State<GradePage> {
  late final TextEditingController _scoreController = TextEditingController(
    text: widget.sub['score'] == null ? '' : fmtNum(widget.sub['score'] as num),
  );
  late final TextEditingController _commentController =
      TextEditingController(text: (widget.sub['comment'] as String?) ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _scoreController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final score = num.tryParse(_scoreController.text.trim());
    if (score == null || score < 0 || score > widget.maxScore) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('คะแนนต้องอยู่ระหว่าง 0 ถึง ${fmtNum(widget.maxScore)}'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.ref.update({
        'score': score,
        'comment': _commentController.text.trim(),
        'gradedAt': FieldValue.serverTimestamp(),
        'gradedBy': FirebaseAuth.instance.currentUser?.uid,
      });
      final studentId = widget.sub['studentId'] as String?;
      if (studentId != null) {
        try {
          await notifyUser(
            userId: studentId,
            title: 'ครูตรวจงานแล้ว',
            body:
                '${widget.assignmentTitle}: ${fmtNum(score)}/${fmtNum(widget.maxScore)}',
            assignmentId: widget.sub['assignmentId'] as String?,
          );
        } catch (_) {}
      }
      if (mounted) Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('บันทึกคะแนนแล้ว')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = (widget.sub['link'] as String?) ?? '';
    final note = (widget.sub['note'] as String?) ?? '';
    final submittedAt = widget.sub['submittedAt'];

    return Scaffold(
      appBar: AppBar(title: const Text('ตรวจงาน')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.assignmentTitle,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(widget.email, style: const TextStyle(color: Colors.grey)),
            if (submittedAt is Timestamp) ...[
              const SizedBox(height: 4),
              Text(
                'ส่งเมื่อ ${formatDateTime(submittedAt.toDate())}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
            const SizedBox(height: 20),
            const Text('ลิงก์งาน', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: SelectableText(link)),
                FilledButton.tonalIcon(
                  onPressed: () => openLink(context, link),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('เปิด'),
                ),
              ],
            ),
            if (note.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('ข้อความจากนักเรียน',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 6),
              Text(note),
            ],
            const SizedBox(height: 24),
            TextField(
              controller: _scoreController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'คะแนน (เต็ม ${fmtNum(widget.maxScore)})',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'ความเห็นถึงนักเรียน (ถ้ามี)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('บันทึกคะแนน'),
            ),
          ],
        ),
      ),
    );
  }
}