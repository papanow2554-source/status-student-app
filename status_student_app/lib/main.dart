import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/teacher_pages.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Status Student',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// ดูสถานะล็อกอิน: ยังไม่ล็อกอิน -> LoginPage, ล็อกอินแล้ว -> เลือกหน้าตาม role
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        if (user == null) return const LoginPage();
        return RoleRouter(key: ValueKey(user.uid), user: user);
      },
    );
  }
}

class RoleRouter extends StatefulWidget {
  final User user;
  const RoleRouter({super.key, required this.user});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  late final Future<String> _role = _loadRole();

  Future<String> _loadRole() async {
    final ref =
        FirebaseFirestore.instance.collection('users').doc(widget.user.uid);
    final snap = await ref.get();
    if (snap.exists) {
      return (snap.data()?['role'] as String?) ?? 'student';
    }
    // ผู้ใช้ใหม่: สร้างเอกสารเป็นนักเรียนโดยอัตโนมัติ
    await ref.set({
      'email': widget.user.email,
      'role': 'student',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return 'student';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _role,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'โหลดข้อมูลผู้ใช้ไม่สำเร็จ: ${snap.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      child: const Text('ออกจากระบบ'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snap.data == 'teacher'
            ? const TeacherHomePage()
            : const HomePage();
      },
    );
  }
}