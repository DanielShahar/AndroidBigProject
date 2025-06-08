import 'package:flutter/material.dart';

class SecondMenuScreen extends StatelessWidget {
  const SecondMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Additional Menu'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(
        child: Text(
          'This is the second menu screen.',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
