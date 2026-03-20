import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/building_widget.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {

    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My City"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),

      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/terrain/grass.png"),
            fit: BoxFit.cover,
          ),
        ),

        child: StreamBuilder<QuerySnapshot>(
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

            return Stack(
              children: habits.map((doc) {

                final data = doc.data() as Map<String, dynamic>;

                return BuildingWidget(
                  category: data["category"],
                  docId: doc.id,
                  posX: data["posX"],
                  posY: data["posY"],
                  level: data["level"],
                );

              }).toList(),
            );
          },
        ),
      ),
    );
  }
}