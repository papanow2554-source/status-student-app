import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/helpers.dart';
import 'assignment_detail_page.dart';
import 'profile_page.dart';

// ───────────────────────── แท็บรายวิชา (นักเรียน) ─────────────────────────

class SubjectsTab extends StatelessWidget {
  const SubjectsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('subjects').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('โหลดรายวิชาไม่สำเร็จ: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = [...snap.data!.docs]..sort(
            (a, b) => ((a.data()['name'] as String?) ?? '')
                .compareTo((b.data()['name'] as String?) ?? ''),
          );
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'ยังไม่มีรายวิชา\nครูเพิ่มได้ที่หน้าจัดการรายวิชา',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final s = docs[i].data();
            final name = (s['name'] as String?) ?? '';
            final type = (s['type'] as String?) ?? '';
            final teacher = (s['teacher'] as String?) ?? '';
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorFor(type).withValues(alpha: 0.15),
                  child: Icon(iconFor(type), color: colorFor(type)),
                ),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: teacher.isEmpty ? null : Text(teacher),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          SubjectAssignmentsPage(name: name, type: type),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ───────────────────────── งานในรายวิชา ─────────────────────────

class SubjectAssignmentsPage extends StatelessWidget {
  final String name;
  final String type;

  const SubjectAssignmentsPage({
    super.key,
    required this.name,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: SafeArea(
        child: ClassroomBuilder(
          builder: (context, room) =>
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('assignments')
              .where('subject', isEqualTo: name)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('โหลดงานไม่สำเร็จ: ${snap.error}'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            DateTime due(QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                (d.data()['dueAt'] as Timestamp).toDate();
            final docs = snap.data!.docs
                .where((d) =>
                    matchesClassroom(d.data()['classroom'] as String?, room))
                .toList()
              ..sort((a, b) => due(a).compareTo(due(b)));
            if (docs.isEmpty) {
              return const Center(child: Text('วิชานี้ยังไม่มีงาน'));
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: docs.map((doc) {
                final d = doc.data();
                final diff = due(doc).difference(DateTime.now());
                return AssignmentCard(
                  icon: iconFor(type),
                  iconColor: colorFor(type),
                  subject: name,
                  title: d['title'] as String? ?? '',
                  dueText: dueText(diff),
                  dueColor: diff.isNegative
                      ? Colors.grey
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
              }).toList(),
            );
          },
        ),
        ),
      ),
    );
  }
}

// ───────────────────────── จัดการรายวิชา (ครู) ─────────────────────────

class ManageSubjectsPage extends StatelessWidget {
  const ManageSubjectsPage({super.key});

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('subjects');

  Future<void> _seedDefaults(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final e in subjectNames.entries) {
        batch.set(_col.doc(), {
          'name': e.value,
          'type': e.key,
          'teacher': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      messenger.showSnackBar(
        const SnackBar(content: Text('เพิ่มวิชาเริ่มต้นแล้ว')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('เพิ่มไม่สำเร็จ: $e')));
    }
  }

  Future<void> _addSubject(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final nameC = TextEditingController();
    final teacherC = TextEditingController();
    var type = 'math';

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('เพิ่มรายวิชา'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameC,
                decoration: const InputDecoration(
                  labelText: 'ชื่อวิชา',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: teacherC,
                decoration: const InputDecoration(
                  labelText: 'ชื่อครูผู้สอน',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('ไอคอน/สี: '),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: type,
                      items: subjectNames.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Row(
                                children: [
                                  Icon(iconFor(e.key),
                                      color: colorFor(e.key), size: 20),
                                  const SizedBox(width: 8),
                                  Text(e.value),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setLocal(() => type = v ?? type),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('เพิ่ม'),
            ),
          ],
        ),
      ),
    );

    final name = nameC.text.trim();
    final teacher = teacherC.text.trim();
    nameC.dispose();
    teacherC.dispose();

    if (ok == true) {
      if (name.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('กรุณาใส่ชื่อวิชา')),
        );
        return;
      }
      try {
        await _col.add({
          'name': name,
          'type': type,
          'teacher': teacher,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('เพิ่มไม่สำเร็จ: $e')));
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ลบรายวิชา'),
        content: Text(
          'ลบ "${doc.data()['name'] ?? ''}" ?\n(งานที่มอบหมายไปแล้วจะไม่ถูกลบ)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await doc.reference.delete();
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('ลบไม่สำเร็จ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('จัดการรายวิชา')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addSubject(context),
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มวิชา'),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _col.snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('โหลดรายวิชาไม่สำเร็จ: ${snap.error}'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = [...snap.data!.docs]..sort(
                (a, b) => ((a.data()['name'] as String?) ?? '')
                    .compareTo((b.data()['name'] as String?) ?? ''),
              );
            if (docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'ยังไม่มีรายวิชา',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => _seedDefaults(context),
                        child: const Text('เพิ่มวิชาเริ่มต้น 6 วิชา'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final s = docs[i].data();
                final type = (s['type'] as String?) ?? '';
                final teacher = (s['teacher'] as String?) ?? '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorFor(type).withValues(alpha: 0.15),
                      child: Icon(iconFor(type), color: colorFor(type)),
                    ),
                    title: Text((s['name'] as String?) ?? ''),
                    subtitle: teacher.isEmpty ? null : Text(teacher),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _delete(context, docs[i]),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}