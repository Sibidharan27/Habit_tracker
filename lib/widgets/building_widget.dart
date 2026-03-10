import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BuildingWidget extends StatefulWidget {

  final String category;
  final String docId;
  final double posX;
  final double posY;

  const BuildingWidget({
    super.key,
    required this.category,
    required this.docId,
    required this.posX,
    required this.posY,
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

    switch (widget.category) {

      case "self_improvement":
        return "assets/buildings/house.png";

      case "workout":
        return "assets/buildings/gym.png";

      case "study":
        return "assets/buildings/library.png";

      case "work":
        return "assets/buildings/office.png";

      default:
        return "assets/buildings/house.png";
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