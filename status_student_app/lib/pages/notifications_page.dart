import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'assignment_detail_page.dart';

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'เมื่อสักครู่';
  if (d.inMinutes < 60) return '${d.inMinutes} นาทีที่แล้ว';
  if (d.inHours < 24) return '${d.inHours} ชม.ที่แล้ว';
  return '${d.inDays} วันที่แล้ว';
}

class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  Future<void> _open(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final n = doc.data();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (n['read'] != true) {
      try {
        await doc.reference.update({'read': true});
      } catch (_) {}
    }

    final aid = n['assignmentId'] as String?;
    if (aid == null) return;
    try {
      final a =
          await FirebaseFirestore.instance.collection('assignments').doc(aid).get();
      if (!a.exists) {
        messenger.showSnackBar(
          const SnackBar(content: Text('ไม่พบงานนี้แล้ว')),
        );
        return;
      }
      navigator.push(
        MaterialPageRoute(
          builder: (context) => AssignmentDetailPage(id: a.id, data: a.data()!),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('เปิดงานไม่สำเร็จ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('โหลดแจ้งเตือนไม่สำเร็จ: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // เรียงใหม่สุดก่อน (เรียงในแอปเพื่อไม่ต้องสร้าง index)
        final docs = [...snap.data!.docs];
        DateTime timeOf(QueryDocumentSnapshot<Map<String, dynamic>> d) {
          final t = d.data()['createdAt'];
          return t is Timestamp ? t.toDate() : DateTime.now();
        }

        docs.sort((a, b) => timeOf(b).compareTo(timeOf(a)));
        final unread = docs.where((d) => d.data()['read'] != true).toList();

        Widget list(List<QueryDocumentSnapshot<Map<String, dynamic>>> items) {
          if (items.isEmpty) {
            return const Center(child: Text('ยังไม่มีการแจ้งเตือน'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final d = items[i];
              final n = d.data();
              final isUnread = n['read'] != true;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () => _open(context, d),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withValues(alpha: 0.12),
                    child: const Icon(Icons.notifications, color: Colors.blue),
                  ),
                  title: Text(
                    n['title'] as String? ?? '',
                    style: TextStyle(
                      fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(n['body'] as String? ?? ''),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _ago(timeOf(d)),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      if (isUnread) ...[
                        const SizedBox(height: 6),
                        const CircleAvatar(radius: 4, backgroundColor: Colors.blue),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        }

        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                tabs: [
                  const Tab(text: 'ทั้งหมด'),
                  Tab(text: 'ยังไม่อ่าน (${unread.length})'),
                ],
              ),
              Expanded(
                child: TabBarView(children: [list(docs), list(unread)]),
              ),
            ],
          ),
        );
      },
    );
  }
}