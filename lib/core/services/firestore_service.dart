import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createUser(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<bool> userExists(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists;
  }

  /// Returns the next available grid position scanning left→right, top→bottom.
  /// Skips cells listed in [occupied] (set of "col,row" strings).
  static (int, int) nextEmptyCell(Set<String> occupied, {int cols = 5, int rows = 12}) {
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        if (!occupied.contains('$col,$row')) return (col, row);
      }
    }
    return (0, 0); // fallback
  }

  Future<void> createDefaultHabits(String uid) async {
    final habits = [
      {'category': 'self_improvement', 'habitName': 'Self Improvement'},
      {'category': 'workout',          'habitName': 'Workout'},
      {'category': 'study',            'habitName': 'Study'},
      {'category': 'work',             'habitName': 'Work'},
    ];

    for (int i = 0; i < habits.length; i++) {
      final col = i % 5;
      final row = i ~/ 5;
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('habits')
          .add({
        'habitName': habits[i]['habitName'],
        'category':  habits[i]['category'],
        'streak':    0,
        'level':     1,
        'gridX':     col,
        'gridY':     row,
        'intervalHours': 24,
        'lastCompleted': DateTime.now(),
      });
    }
  }
}