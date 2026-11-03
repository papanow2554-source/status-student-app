import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// หน้าให้ครูสร้างบัญชีนักเรียนหลายคนพร้อมกัน
/// ใช้ Firebase app ตัวที่สองสร้างบัญชี เพื่อไม่ให้ครูหลุดออกจากระบบ
class AddStudentsPage extends StatefulWidget {
  const AddStudentsPage({super.key});

  @override
  State<AddStudentsPage> createState() => _AddStudentsPageState();
}

class _Result {
  final String line;
  final bool ok;
  final String message;
  _Result(this.line, this.ok, this.message);
}

class _AddStudentsPageState extends State<AddStudentsPage> {
  final _controller = TextEditingController();
  final List<_Result> _results = [];
  bool _running = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<FirebaseApp> _secondaryApp() async {
    try {
      return Firebase.app('studentCreator');
    } catch (_) {
      return Firebase.initializeApp(
        name: 'studentCreator',
        options: Firebase.app().options,
      );
    }
  }

  String _errorText(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'อีเมลนี้มีบัญชีอยู่แล้ว';
        case 'invalid-email':
          return 'รูปแบบอีเมลไม่ถูกต้อง';
        case 'weak-password':
          return 'รหัสผ่านสั้นเกินไป (ต้อง 6 ตัวขึ้นไป)';
        case 'too-many-requests':
          return 'สร้างถี่เกินไป รอสักครู่แล้วลองใหม่';
        default:
          return e.message ?? e.code;
      }
    }
    return e.toString();
  }

  Future<void> _create() async {
    final lines = _controller.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return;

    setState(() {
      _running = true;
      _results.clear();
    });

    final app = await _secondaryApp();
    final auth = FirebaseAuth.instanceFor(app: app);
    final db = FirebaseFirestore.instanceFor(app: app);

    for (final line in lines) {
      final idx = line.indexOf(',');
      if (idx < 0) {
        _results.add(_Result(line, false, 'รูปแบบต้องเป็น อีเมล,รหัสผ่าน'));
        if (mounted) setState(() {});
        continue;
      }
      final email = line.substring(0, idx).trim();
      final password = line.substring(idx + 1).trim();
      try {
        final cred = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        await db.collection('users').doc(cred.user!.uid).set({
          'email': email,
          'role': 'student',
          'createdAt': FieldValue.serverTimestamp(),
        });
        await auth.signOut();
        _results.add(_Result(email, true, 'สร้างแล้ว'));
      } catch (e) {
        try {
          await auth.signOut();
        } catch (_) {}
        _results.add(_Result(email.isEmpty ? line : email, false, _errorText(e)));
      }
      if (mounted) setState(() {});
    }

    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final okCount = _results.where((r) => r.ok).length;

    return Scaffold(
      appBar: AppBar(title: const Text('เพิ่มบัญชีนักเรียน')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'พิมพ์หรือวางรายชื่อ บรรทัดละ 1 คน ในรูปแบบ\nอีเมล,รหัสผ่าน',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            const Text(
              'เช่น\nstu001@school.com,123456\nstu002@school.com,123456',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 8,
              enabled: !_running,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'อีเมล,รหัสผ่าน',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _running ? null : _create,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: _running
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add),
              label: Text(_running ? 'กำลังสร้าง...' : 'สร้างบัญชี'),
            ),
            if (_results.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'สำเร็จ $okCount จาก ${_results.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._results.map(
                (r) => Card(
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      r.ok ? Icons.check_circle : Icons.error,
                      color: r.ok ? Colors.green : Colors.red,
                    ),
                    title: Text(r.line),
                    subtitle: Text(r.message),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}