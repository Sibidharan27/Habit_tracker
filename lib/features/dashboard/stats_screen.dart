import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {

    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("Your Progress 📊")),

      body: StreamBuilder<QuerySnapshot>(
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

          int totalHabits = habits.length;
          int totalStreak = 0;

          Map<String, int> categoryCount = {};

          for (var doc in habits) {
            final data = doc.data() as Map<String, dynamic>;

            totalStreak += data["streak"] as int;

            String category = data["category"];

            categoryCount[category] = (categoryCount[category] ?? 0) + 1;
          }

          double avgStreak =
          totalHabits == 0 ? 0 : totalStreak / totalHabits;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text("Total Habits: $totalHabits",
                    style: const TextStyle(fontSize: 18)),

                const SizedBox(height: 10),

                Text("Average Streak: ${avgStreak.toStringAsFixed(1)}",
                    style: const TextStyle(fontSize: 18)),

                const SizedBox(height: 20),

                const Text("Category Breakdown:",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),

                const SizedBox(height: 10),

                ...categoryCount.entries.map((entry) {
                  return Text(
                    "${entry.key}: ${entry.value}",
                    style: const TextStyle(fontSize: 16),
                  );
                }),

              ],
            ),
          );
        },
      ),
    );
  }
}