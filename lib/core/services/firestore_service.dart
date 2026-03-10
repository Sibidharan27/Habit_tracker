import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createUser(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<void> createDefaultHabits(String uid) async {

    final habits = [
      {"category": "self_improvement"},
      {"category": "workout"},
      {"category": "study"},
      {"category": "work"},
    ];

    for (var habit in habits) {

      await _firestore
          .collection("users")
          .doc(uid)
          .collection("habits")
          .add({
        "category": habit["category"],
        "streak": 0,
        "level": 0,
        "posX": 100,
        "posY": 100,
        "lastCompleted": DateTime.now(),
      });
    }
  }
}