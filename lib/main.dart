import 'package:flutter/material.dart';
import 'package:android_big_project/screens/dashboard_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:android_big_project/firebase_options.dart';

/// Global ValueNotifier to broadcast download status updates across the app.
/// This allows any screen to listen to download completion events.
/// The map contains: {'id': taskId, 'status': downloadStatus, 'progress': downloadProgress}
final ValueNotifier<Map<String, dynamic>> downloadUpdateNotifier =
    ValueNotifier<Map<String, dynamic>>({});

/// Top-level callback function for FlutterDownloader.
/// This function is called whenever a download task status changes.
/// 
/// @pragma('vm:entry-point') ensures the function is not tree-shaken during AOT compilation.
/// This is required for the download callback to work properly in release builds.
/// 
/// Parameters:
/// - [id]: Unique task identifier for the download
/// - [status]: Current status of the download (as integer)
/// - [progress]: Download progress percentage (0-100)
@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  // Log download status for debugging purposes
  print('DOWNLOAD_CALLBACK: Task $id - Status: $status, Progress: $progress%');
  
  // Only notify listeners when download reaches a final state
  // Compare with .index because status is received as integer
  if (status == DownloadTaskStatus.complete.index ||
      status == DownloadTaskStatus.failed.index ||
      status == DownloadTaskStatus.canceled.index) {
    
    // Update the global notifier with download completion info
    downloadUpdateNotifier.value = {
      'id': id, 
      'status': status, 
      'progress': progress,
      'timestamp': DateTime.now().millisecondsSinceEpoch, // Add timestamp for uniqueness
    };
    
    print('DOWNLOAD_CALLBACK: Broadcasting update for task $id');
  }
}

/// Requests storage permission from the user.
/// This is essential for downloading and saving files on Android devices.
/// 
/// Returns: Future<bool> indicating whether permission was granted
Future<bool> requestStoragePermission() async {
  try {
    // Check current permission status
    var status = await Permission.storage.status;
    
    if (status.isGranted) {
      print('PERMISSION: Storage permission already granted');
      return true;
    }
    
    // Request permission if not already granted
    print('PERMISSION: Requesting storage permission...');
    final result = await Permission.storage.request();
    
    final isGranted = result.isGranted;
    print('PERMISSION: Storage permission ${isGranted ? 'granted' : 'denied'}');
    
    return isGranted;
  } catch (e) {
    print('PERMISSION_ERROR: Failed to request storage permission: $e');
    return false;
  }
}

/// Main application entry point.
/// Initializes all required services before starting the app.
void main() async {
  // Ensure Flutter framework is properly initialized before running async operations
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase with platform-specific configuration
    print('INIT: Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('INIT: Firebase initialized successfully');

    // Initialize Flutter Downloader plugin
    print('INIT: Initializing Flutter Downloader...');
    await FlutterDownloader.initialize(
      debug: true, // Enable debug logging
      ignoreSsl: false, // Handle SSL properly for security (set to true only for testing)
    );

    // Register the global download callback function
    FlutterDownloader.registerCallback(downloadCallback);
    print('INIT: Flutter Downloader initialized and callback registered');

    // Request necessary permissions before starting the app
    print('INIT: Requesting storage permission...');
    final hasPermission = await requestStoragePermission();
    
    if (!hasPermission) {
      print('WARNING: Storage permission not granted - downloads may fail');
    }

    print('INIT: All services initialized successfully');
    
  } catch (e) {
    print('INIT_ERROR: Failed to initialize services: $e');
    // Continue running the app even if some services fail to initialize
    // The app should handle missing services gracefully
  }

  // Start the Flutter application
  runApp(const MyApp());
}

/// Root widget of the application.
/// Configures the overall app theme and navigation.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Children Books Library',
      debugShowCheckedModeBanner: false, // Hide debug banner in development
      
      // Configure app theme
      theme: ThemeData(
        // Use a warm color scheme suitable for children's app
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 227, 101, 101),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        
        // Configure app bar theme
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
          backgroundColor: Colors.white,
          foregroundColor: Color.fromARGB(255, 227, 101, 101),
        ),
        
        // Configure elevated button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      
      // Set the home screen
      home: const DashboardScreen(),
    );
  }
}