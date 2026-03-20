import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/building_widget.dart';
import 'stats_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});


  Future<void> applyDecay(String uid, List<QueryDocumentSnapshot> habits) async {

    final now = DateTime.now();

    for (var doc in habits) {

      final data = doc.data() as Map<String, dynamic>;

      DateTime lastCompleted =
      (data["lastCompleted"] as Timestamp).toDate();

      int streak = data["streak"];

      int daysMissed = now.difference(lastCompleted).inDays;

      // If missed more than 1 day → decay
      if (daysMissed > 1) {

        int newStreak = streak - daysMissed;

        if (newStreak < 0) newStreak = 0;

        int newLevel = newStreak ~/ 3;

        await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("habits")
            .doc(doc.id)
            .update({
          "streak": newStreak,
          "level": newLevel,
        });
        debugPrint("Decay applied to ${data["category"]}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "My City",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 4,
        backgroundColor: Colors.green.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StatsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green.shade700,
        elevation: 6,
        onPressed: () {
          _showAddHabitDialog(context);
        },
        child: const Icon(Icons.add, size: 28),
      ),

      body: Stack(
        children: [

          // 🌱 Grass background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: _getTimeOverlayColor(),
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.2),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // 🏙️ Buildings (your existing StreamBuilder)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("users")
                .doc(uid)
                .collection("habits")
                .snapshots(),
            builder: (context, snapshot) {

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final habits = snapshot.data!.docs;

              applyDecay(uid, habits);

              return Stack(
                children: habits.map((doc) {

                  final data = doc.data() as Map<String, dynamic>;

                  return BuildingWidget(
                    category: data["category"],
                    docId: doc.id,
                    posX: (data["posX"] as num).toDouble(),
                    posY: (data["posY"] as num).toDouble(),
                    level: data["level"],
                  );

                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

void _showAddHabitDialog(BuildContext context) {

  String selectedCategory = "self_improvement";

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          "Add New Habit",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: DropdownButtonFormField<String>(
          initialValue: selectedCategory,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: "Select Category",
          ),
          items: const [
            DropdownMenuItem(value: "self_improvement", child: Text("Self Improvement 🏠")),
            DropdownMenuItem(value: "workout", child: Text("Workout 🏋️")),
            DropdownMenuItem(value: "study", child: Text("Study 📚")),
            DropdownMenuItem(value: "work", child: Text("Work 🏢")),
          ],
          onChanged: (value) {
            selectedCategory = value!;
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
            ),
            onPressed: () async {
              final uid = FirebaseAuth.instance.currentUser!.uid;

              await FirebaseFirestore.instance
                  .collection("users")
                  .doc(uid)
                  .collection("habits")
                  .add({
                "category": selectedCategory,
                "streak": 0,
                "level": 0,
                "posX": 100.0,
                "posY": 100.0,
                "lastCompleted": DateTime.now(),
              });

              if (!context.mounted) return;

              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      );
    },
  );
}

Color _getTimeOverlayColor() {

  final hour = DateTime.now().hour;

  if (hour >= 6 && hour < 12) {
    return Colors.transparent; // morning
  }
  else if (hour >= 12 && hour < 18) {
    return Colors.orange.withValues(alpha: 0.1); // evening glow
  }
  else {
    return Colors.black.withValues(alpha: 0.4); // night
  }
}