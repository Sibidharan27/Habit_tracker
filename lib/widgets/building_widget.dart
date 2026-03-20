import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BuildingWidget extends StatefulWidget {

  final String category;
  final String docId;
  final double posX;
  final double posY;
  final int level;

  const BuildingWidget({
    super.key,
    required this.category,
    required this.docId,
    required this.posX,
    required this.posY,
    required this.level,
  });

  @override
  State<BuildingWidget> createState() => _BuildingWidgetState();
}

class _BuildingWidgetState extends State<BuildingWidget> {

  late double x;
  late double y;

  @override
  void initState() {
    super.initState();
    x = widget.posX;
    y = widget.posY;
  }

  String getBuildingImage() {

    int lvl = widget.level;

    // Prevent going above 2 (since we have 3 images: 0,1,2)
    if (lvl > 2) lvl = 2;

    switch (widget.category) {

      case "self_improvement":
        return "assets/buildings/self_improvement/lvl$lvl.png";

      case "workout":
        return "assets/buildings/workout/lvl$lvl.png";

      case "study":
        return "assets/buildings/study/lvl$lvl.png";

      case "work":
        return "assets/buildings/work/lvl$lvl.png";

      default:
        return "assets/buildings/self_improvement/lvl0.png";
    }
  }

  void updatePosition() {

    final uid = FirebaseAuth.instance.currentUser!.uid;

    FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("habits")
        .doc(widget.docId)
        .update({
      "posX": x,
      "posY": y,
    });
  }

  @override
  Widget build(BuildContext context) {

    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(

        onTap: () async {

          final uid = FirebaseAuth.instance.currentUser!.uid;

          final docRef = FirebaseFirestore.instance
              .collection("users")
              .doc(uid)
              .collection("habits")
              .doc(widget.docId);

          final doc = await docRef.get();
          final data = doc.data()!;

          DateTime lastCompleted = (data["lastCompleted"] as Timestamp).toDate();
          DateTime now = DateTime.now();

          // Check if already completed today
          if (lastCompleted.day == now.day &&
              lastCompleted.month == now.month &&
              lastCompleted.year == now.year) {

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Already completed today ✅")),
            );
            return;
          }

          int newStreak = data["streak"] + 1;

          // Calculate level
          int newLevel = newStreak ~/ 3;

          await docRef.update({
            "streak": newStreak,
            "level": newLevel,
            "lastCompleted": now,
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Habit completed! 🔥 Streak: $newStreak")),
          );
        },
        onPanUpdate: (details) {
          setState(() {
            x += details.delta.dx;
            y += details.delta.dy;
          });
        },

        onPanEnd: (_) {
          updatePosition();
        },

        child: Image.asset(
          getBuildingImage(),
          width: 80,
        ),
      ),
    );
  }
}