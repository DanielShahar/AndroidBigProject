// firebase_options.dart
// Firebase configuration file generated by FlutterFire CLI
// Contains platform-specific configuration for Firebase services
// 
// SECURITY NOTE: This file contains API keys that are safe to expose in client-side code
// as they are designed to be public identifiers, not secret credentials.

// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default Firebase configuration options for the application
/// 
/// This class provides platform-specific Firebase configuration
/// that enables the app to connect to Firebase services like
/// Firestore, Authentication, Storage, etc.
/// 
/// Usage example:
/// ```dart
/// import 'firebase_options.dart';
/// 
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  /// Returns the appropriate Firebase configuration for the current platform
  /// 
  /// Automatically detects the running platform and returns the corresponding
  /// Firebase configuration. Throws UnsupportedError for unsupported platforms.
  static FirebaseOptions get currentPlatform {
    // Web platform detection
    if (kIsWeb) {
      return web;
    }
    
    // Mobile and desktop platform detection
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Linux. '
          'Run the FlutterFire CLI to configure Firebase for Linux platform.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform. '
          'Please check platform compatibility or configure additional platforms.',
        );
    }
  }

  /// Firebase configuration for Web platform
  /// Used when the app runs in a web browser
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDX9bOMMsvwqhJ7AIrR9XgKvrQa0pXL7W8',
    appId: '1:344734180564:web:f430ef52a08e6b31d38741',
    messagingSenderId: '344734180564',
    projectId: 'androidfinalproject-c2d03',
    authDomain: 'androidfinalproject-c2d03.firebaseapp.com',
    storageBucket: 'androidfinalproject-c2d03.firebasestorage.app',
  );

  /// Firebase configuration for Android platform
  /// Used when the app runs on Android devices
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBp_Wku8XbJiuAsw9sf8r4wYYnKIP8DNrA',
    appId: '1:344734180564:android:c41c8acfce634d53d38741',
    messagingSenderId: '344734180564',
    projectId: 'androidfinalproject-c2d03',
    storageBucket: 'androidfinalproject-c2d03.firebasestorage.app',
  );

  /// Firebase configuration for iOS platform
  /// Used when the app runs on iOS devices (iPhone/iPad)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDDOviMNDX8vqI4iYi5A67pvtQ17VFa_7U',
    appId: '1:344734180564:ios:054faf9b462855cad38741',
    messagingSenderId: '344734180564',
    projectId: 'androidfinalproject-c2d03',
    storageBucket: 'androidfinalproject-c2d03.firebasestorage.app',
    iosBundleId: 'com.example.androidBigProject',
  );

  /// Firebase configuration for macOS platform
  /// Used when the app runs on macOS desktop
  /// Note: Shares the same configuration as iOS due to similar Apple ecosystem
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDDOviMNDX8vqI4iYi5A67pvtQ17VFa_7U',
    appId: '1:344734180564:ios:054faf9b462855cad38741',
    messagingSenderId: '344734180564',
    projectId: 'androidfinalproject-c2d03',
    storageBucket: 'androidfinalproject-c2d03.firebasestorage.app',
    iosBundleId: 'com.example.androidBigProject',
  );

  /// Firebase configuration for Windows platform
  /// Used when the app runs on Windows desktop
  /// Note: Uses web-like configuration for Windows desktop apps
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDX9bOMMsvwqhJ7AIrR9XgKvrQa0pXL7W8',
    appId: '1:344734180564:web:4c9e6f78aecc9653d38741',
    messagingSenderId: '344734180564',
    projectId: 'androidfinalproject-c2d03',
    authDomain: 'androidfinalproject-c2d03.firebaseapp.com',
    storageBucket: 'androidfinalproject-c2d03.firebasestorage.app',
  );
}