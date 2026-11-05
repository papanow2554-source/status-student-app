import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'my_scores_page.dart';

DocumentReference<Map<String, dynamic>>? _myDoc() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;
  return FirebaseFirestore.instance.collection('users').doc(uid);
}

/// ให้ builder รู้ห้องเรียนของผู้ใช้ปัจจุบัน (ว่างถ้ายังไม่ได้ตั้ง)
class ClassroomBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, String classroom) builder;
  const ClassroomBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _myDoc()?.snapshots(),
      builder: (context, snap) {
        final room = (snap.data?.data()?['classroom'] as String?) ?? '';
        return builder(context, room);
      },
    );
  }
}

/// ข้อความทักทายหน้าหลัก อ่านชื่อและห้องเรียนจากข้อมูลผู้ใช้
class UserGreeting extends StatelessWidget {
  const UserGreeting({super.key});

  @override
  Widget build(BuildContext context) {
    final ref = _myDoc();
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref?.snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data();
        final name = (d?['name'] as String?)?.trim();
        final classroom = (d?['classroom'] as String?)?.trim();
        final shown =
            (name != null && name.isNotEmpty) ? name : email.split('@').first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'สวัสดี, $shown 👋',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              (classroom != null && classroom.isNotEmpty)
                  ? 'นักเรียนชั้น $classroom'
                  : 'ยังไม่ได้ระบุห้องเรียน (ตั้งค่าที่แท็บโปรไฟล์)',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        );
      },
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _editInfo(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic>? current,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final nameC = TextEditingController(text: (current?['name'] as String?) ?? '');
    final roomC =
        TextEditingController(text: (current?['classroom'] as String?) ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ข้อมูลส่วนตัว'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              decoration: const InputDecoration(
                labelText: 'ชื่อ-นามสกุล',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: roomC,
              decoration: const InputDecoration(
                labelText: 'ห้องเรียน (เช่น ม.4/2)',
                border: OutlineInputBorder(),
              ),
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
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        // ใช้ set+merge เผื่อเอกสารยังไม่มีฟิลด์เหล่านี้
        await ref.set({
          'name': nameC.text.trim(),
          'classroom': roomC.text.trim(),
        }, SetOptions(merge: true));
        messenger.showSnackBar(const SnackBar(content: Text('บันทึกแล้ว')));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
      }
    }
    nameC.dispose();
    roomC.dispose();
  }

  Future<void> _changePassword(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final oldC = TextEditingController();
    final newC = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('เปลี่ยนรหัสผ่าน'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldC,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'รหัสผ่านปัจจุบัน',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newC,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'รหัสผ่านใหม่ (6 ตัวขึ้นไป)',
                border: OutlineInputBorder(),
              ),
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
            child: const Text('เปลี่ยน'),
          ),
        ],
      ),
    );

    if (ok == true && user != null && user.email != null) {
      try {
        // ต้องยืนยันตัวตนด้วยรหัสเดิมก่อน Firebase ถึงยอมให้เปลี่ยน
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: oldC.text,
        );
        await user.reauthenticateWithCredential(cred);
        await user.updatePassword(newC.text);
        messenger.showSnackBar(
          const SnackBar(content: Text('เปลี่ยนรหัสผ่านแล้ว')),
        );
      } on FirebaseAuthException catch (e) {
        String msg;
        switch (e.code) {
          case 'wrong-password':
          case 'invalid-credential':
            msg = 'รหัสผ่านปัจจุบันไม่ถูกต้อง';
            break;
          case 'weak-password':
            msg = 'รหัสผ่านใหม่สั้นเกินไป (ต้อง 6 ตัวขึ้นไป)';
            break;
          default:
            msg = e.message ?? e.code;
        }
        messenger.showSnackBar(SnackBar(content: Text(msg)));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('เปลี่ยนไม่สำเร็จ: $e')));
      }
    }
    oldC.dispose();
    newC.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final ref = _myDoc();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref?.snapshots(),
      builder: (context, snap) {
        final d = snap.data?.data();
        final name = (d?['name'] as String?)?.trim() ?? '';
        final classroom = (d?['classroom'] as String?)?.trim() ?? '';
        final email = user?.email ?? '';
        final initial = (name.isNotEmpty ? name : email).isEmpty
            ? '?'
            : (name.isNotEmpty ? name : email)[0].toUpperCase();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 16),
            Center(
              child: CircleAvatar(
                radius: 44,
                child: Text(initial, style: const TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                name.isNotEmpty ? name : 'ยังไม่ได้ตั้งชื่อ',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Center(
              child: Text(
                classroom.isNotEmpty ? 'นักเรียนชั้น $classroom' : email,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            if (classroom.isNotEmpty)
              Center(
                child: Text(email, style: const TextStyle(color: Colors.grey)),
              ),
            const SizedBox(height: 24),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('ข้อมูลส่วนตัว'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: ref == null ? null : () => _editInfo(context, ref, d),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.bar_chart),
                    title: const Text('คะแนนของฉัน'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const MyScoresPage(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('เปลี่ยนรหัสผ่าน'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _changePassword(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'ออกจากระบบ',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => FirebaseAuth.instance.signOut(),
              ),
            ),
          ],
        );
      },
    );
  }
}