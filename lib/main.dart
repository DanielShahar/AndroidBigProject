import 'package:flutter/material.dart';
import 'package:android_big_project/screens/dashboard_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:android_big_project/firebase_options.dart';

// This must be a top-level function or a static method.
// The @pragma('vm:entry-point') annotation is necessary for AOT compilation.
@pragma('vm:entry-point')
void downloadCallback(String id, DownloadTaskStatus status, int progress) {
  print('GLOBAL_DOWNLOAD_CALLBACK: Task ($id) status: $status, progress: $progress');

}


// Function to request storage permission
Future<void> requestStoragePermission() async {
  var status = await Permission.storage.status;
  if (!status.isGranted) {
    // If permission is not granted, request it
    await Permission.storage.request();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter is initialized

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Flutter Downloader and register the callback
  await FlutterDownloader.initialize(
    debug: true, // Set to false in production for release builds
    ignoreSsl: true, // Set to false and handle SSL properly in production if needed
  );
  FlutterDownloader.registerCallback(downloadCallback); // Register the callback here

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
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}