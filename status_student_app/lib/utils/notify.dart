import 'package:cloud_firestore/cloud_firestore.dart';

/// ส่งแจ้งเตือนให้ผู้ใช้คนเดียว
Future<void> notifyUser({
  required String userId,
  required String title,
  required String body,
  String? assignmentId,
}) async {
  await FirebaseFirestore.instance.collection('notifications').add({
    'userId': userId,
    'title': title,
    'body': body,
    'assignmentId': assignmentId,
    'read': false,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

/// ส่งแจ้งเตือนให้นักเรียนทุกคน (ใช้ batch สูงสุด 500 คนต่อครั้ง)
Future<void> notifyAllStudents({
  required String title,
  required String body,
  String? assignmentId,
}) async {
  final db = FirebaseFirestore.instance;
  final students =
      await db.collection('users').where('role', isEqualTo: 'student').get();
  final batch = db.batch();
  for (final s in students.docs) {
    batch.set(db.collection('notifications').doc(), {
      'userId': s.id,
      'title': title,
      'body': body,
      'assignmentId': assignmentId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
}