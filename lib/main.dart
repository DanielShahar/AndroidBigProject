import 'package:flutter/material.dart';
import 'package:android_big_project/screens/dashboard_screen.dart';
import 'package:permission_handler/permission_handler.dart'; // Add this import

// Function to request storage permission
Future<void> requestStoragePermission() async {
  var status = await Permission.storage.status;
  if (!status.isGranted) {
    // If permission is not granted, request it
    await Permission.storage.request();
  }
}

void main() async { // Make main an async function
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter is initialized
  await requestStoragePermission(); // Request permission before running the app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const DashboardScreen(),
    );
  }
}