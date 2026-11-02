import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/helpers.dart';
import 'assignment_detail_page.dart';
import 'my_scores_page.dart';
import 'notifications_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    _HomeTab(),
    _SubjectsTab(),
    NotificationsTab(),
    _ProfileTab(),
  ];

  static const List<String> _titles = [
    'หน้าหลัก',
    'รายวิชา',
    'แจ้งเตือน',
    'โปรไฟล์',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: SafeArea(child: _pages[_selectedIndex]),
      bottomNavigationBar: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
            .where('read', isEqualTo: false)
            .snapshots(),
        builder: (context, snap) {
          final unread = snap.data?.docs.length ?? 0;
          return NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'หน้าหลัก',
              ),
              const NavigationDestination(
                icon: Icon(Icons.book_outlined),
                selectedIcon: Icon(Icons.book),
                label: 'รายวิชา',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.notifications_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.notifications),
                ),
                label: 'แจ้งเตือน',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'โปรไฟล์',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.email?.split('@').first ?? 'นักเรียน';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'สวัสดี, $displayName 👋',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text('นักเรียนชั้น ม.4/2', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),
        const Text(
          'งานที่ต้องส่ง',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('assignments')
              .orderBy('dueAt')
              .snapshots(),
          builder: (context, aSnap) {
            if (aSnap.hasError) {
              return Text(
                'โหลดข้อมูลไม่สำเร็จ: ${aSnap.error}',
                style: const TextStyle(color: Colors.red),
              );
            }
            if (!aSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = aSnap.data!.docs;
            if (docs.isEmpty) {
              return const Text('ยังไม่มีงานที่ต้องส่ง');
            }

            // อ่านงานที่นักเรียนคนนี้ส่งแล้ว เพื่อติดป้ายสถานะ
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('submissions')
                  .where('studentId', isEqualTo: user?.uid)
                  .snapshots(),
              builder: (context, sSnap) {
                final subs = <String, Map<String, dynamic>>{};
                for (final s in sSnap.data?.docs ?? []) {
                  final data = s.data();
                  subs[(data['assignmentId'] as String?) ?? ''] = data;
                }

                return Column(
                  children: docs.map((doc) {
                    final d = doc.data();
                    final due = (d['dueAt'] as Timestamp).toDate();
                    final type = d['type'] as String? ?? '';
                    final diff = due.difference(DateTime.now());
                    final sub = subs[doc.id];

                    String text;
                    Color color;
                    if (sub != null) {
                      final graded = sub['score'] != null;
                      text = graded ? 'ตรวจแล้ว' : 'ส่งแล้ว';
                      color = Colors.green;
                    } else {
                      text = dueText(diff);
                      color = diff.inHours < 24 ? Colors.red : Colors.orange;
                    }

                    return AssignmentCard(
                      icon: iconFor(type),
                      iconColor: colorFor(type),
                      subject: d['subject'] as String? ?? '',
                      title: d['title'] as String? ?? '',
                      dueText: text,
                      dueColor: color,
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
            );
          },
        ),
      ],
    );
  }
}

class _SubjectsTab extends StatelessWidget {
  const _SubjectsTab();

  @override
  Widget build(BuildContext context) {
    final subjects = [
      {'name': 'คณิตศาสตร์', 'teacher': 'ครูภัฏวุฒิ อินทรกำแก', 'type': 'math'},
      {'name': 'ภาษาไทย', 'teacher': 'ครูวิฎุดา ใจดี', 'type': 'thai'},
      {'name': 'วิทยาการคำนวณ', 'teacher': 'ครูเอกพงษ์ ชำนาญ', 'type': 'cs'},
      {'name': 'วิทยาศาสตร์', 'teacher': 'ครูจิราณา มีคง', 'type': 'science'},
      {'name': 'สังคมศึกษา', 'teacher': 'ครูนิษฐาน รักการดี', 'type': 'social'},
      {'name': 'ภาษาอังกฤษ', 'teacher': 'ครู Sarah Johnson', 'type': 'english'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: subjects.length,
      itemBuilder: (context, index) {
        final s = subjects[index];
        final type = s['type']!;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colorFor(type).withValues(alpha: 0.15),
              child: Icon(iconFor(type), color: colorFor(type)),
            ),
            title: Text(
              s['name']!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(s['teacher']!),
          ),
        );
      },
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 16),
        const Center(
          child: CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(user?.email ?? '', style: const TextStyle(fontSize: 16)),
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('คะแนนของฉัน'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const MyScoresPage()),
              );
            },
          ),
        ),
      ],
    );
  }
}