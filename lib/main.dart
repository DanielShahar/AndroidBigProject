// main.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:android_big_project/screens/dashboard_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:android_big_project/firebase_options.dart';

// Define a global ValueNotifier to hold download updates
// Key: taskId, Value: DownloadTaskStatus (simplified)
final ValueNotifier<Map<String, DownloadTaskStatus>> downloadUpdates =
    ValueNotifier({});

// This must be a top-level function or a static method.
// The @pragma('vm:entry-point') annotation is necessary for AOT compilation.
@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  final downloadStatus = DownloadTaskStatus.values[status];
  print('GLOBAL_DOWNLOAD_CALLBACK: Task ($id) status: $downloadStatus, progress: $progress');

  // Update the global notifier directly with taskId and status.
  // The filename mapping will be handled in the UI (BooksListPage1).
  downloadUpdates.value = {
    ...downloadUpdates.value, // Keep existing states
    id: downloadStatus, // Update this task's status using its ID
  };
  // No need to query FlutterDownloader.loadTasksWithRawQuery here,
  // as it causes MissingPluginException in background isolates.
}

// Function to request storage permission
Future<void> requestStoragePermission() async {
  var status = await Permission.storage.status;
  if (!status.isGranted) {
    await Permission.storage.request();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FlutterDownloader.initialize(
    debug: true,
    ignoreSsl: true,
  );
  FlutterDownloader.registerCallback(downloadCallback);

  await requestStoragePermission();
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