import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/helpers.dart';

class MyScoresPage extends StatelessWidget {
  const MyScoresPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('คะแนนของฉัน')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream:
              FirebaseFirestore.instance.collection('assignments').snapshots(),
          builder: (context, aSnap) {
            if (aSnap.hasError) {
              return Center(child: Text('โหลดข้อมูลไม่สำเร็จ: ${aSnap.error}'));
            }
            if (!aSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final assignments = {
              for (final d in aSnap.data!.docs) d.id: d.data(),
            };

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('submissions')
                  .where('studentId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, sSnap) {
                if (sSnap.hasError) {
                  return Center(
                    child: Text('โหลดข้อมูลไม่สำเร็จ: ${sSnap.error}'),
                  );
                }
                if (!sSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                double got = 0;
                double full = 0;
                final rows = <Widget>[];

                for (final doc in sSnap.data!.docs) {
                  final s = doc.data();
                  if (s['score'] == null) continue;
                  final a = assignments[s['assignmentId']];
                  if (a == null) continue;
                  final score = (s['score'] as num).toDouble();
                  final max = (a['maxScore'] as num?)?.toDouble() ?? 0;
                  got += score;
                  full += max;
                  final type = a['type'] as String? ?? '';
                  rows.add(
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              colorFor(type).withValues(alpha: 0.15),
                          child: Icon(iconFor(type), color: colorFor(type)),
                        ),
                        title: Text(
                          a['title'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(a['subject'] as String? ?? ''),
                        trailing: Text(
                          '${fmtNum(score)}/${fmtNum(max)}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final percent = full > 0 ? got / full * 100 : 0.0;
                final grade = full > 0 ? gradeFor(percent) : '-';

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'คะแนนรวม',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${percent.toStringAsFixed(2)}%',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'เกรด',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  grade,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'งานล่าสุด',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (rows.isEmpty)
                      const Text('ยังไม่มีงานที่ตรวจให้คะแนนแล้ว')
                    else
                      ...rows,
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}