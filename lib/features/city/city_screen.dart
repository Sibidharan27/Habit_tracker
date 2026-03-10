import 'package:flutter/material.dart';

class CityScreen extends StatelessWidget {
  const CityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/terrain/grass.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: const Center(
          child: Text(
            "Your City Will Appear Here",
            style: TextStyle(fontSize: 24, color: Colors.white),
          ),
        ),
      ),
    );
  }
}