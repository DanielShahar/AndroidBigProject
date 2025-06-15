// dashboard_screen.dart
import 'package:flutter/material.dart';
import 'second_menu_screen.dart';
import 'books_list_page.dart';
import 'package:flutter_downloader/flutter_downloader.dart'; // Import FlutterDownloader
import 'package:path_provider/path_provider.dart'; // Import path_provider
import 'dart:io'; // Needed for File operations
import 'package:path/path.dart' as path; // Needed for path.join

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final services = [
    {'label': 'Ages 0-4: Word', 'icon': Icons.child_friendly, 'age': '0-4', 'type': 'word'},
    {'label': 'Ages 0-4: PDF', 'icon': Icons.child_friendly, 'age': '0-4', 'type': 'pdf'},
    {'label': 'Ages 4-8: Word', 'icon': Icons.emoji_nature, 'age': '4-8', 'type': 'word'},
    {'label': 'Ages 4-8: PDF', 'icon': Icons.emoji_nature, 'age': '4-8', 'type': 'pdf'},
    {'label': 'Ages 8-12: Word', 'icon': Icons.auto_stories, 'age': '8-12', 'type': 'word'},
    {'label': 'Ages 8-12: PDF', 'icon': Icons.auto_stories, 'age': '8-12', 'type': 'pdf'},
  ];

  /// Clears all downloaded files and cancels active tasks.
  Future<void> _clearAllDownloads() async {
    try {
      // First, cancel all active downloads
      await FlutterDownloader.cancelAll();
      print('CLEAR_DOWNLOADS_INFO: All active downloads cancelled');

      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        print('CLEAR_DOWNLOADS_ERROR: Could not get external storage directory.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot access storage directory'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Check if directory exists
      if (!await directory.exists()) {
        print('CLEAR_DOWNLOADS_INFO: Directory does not exist, nothing to clear');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No downloads found to clear'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // List all files in the app's external storage directory
      final entities = await directory.list().toList();
      
      // Define common document file extensions to clear
      const List<String> documentExtensions = ['.pdf', '.doc', '.docx', '.word'];
      
      int deletedCount = 0;
      int failedCount = 0;

      for (var entity in entities) {
        if (entity is File) {
          final fileName = path.basename(entity.path).toLowerCase();
          
          // Only delete files that match the common document extensions
          if (documentExtensions.any((ext) => fileName.endsWith(ext))) {
            try {
              await entity.delete();
              deletedCount++;
              print('CLEARED_DOWNLOAD: Deleted ${entity.path}');
            } catch (e) {
              failedCount++;
              print('CLEAR_DOWNLOAD_ERROR: Failed to delete ${entity.path}: $e');
            }
          }
        }
      }

      print('CLEAR_DOWNLOADS_INFO: Deleted $deletedCount files, failed to delete $failedCount files');

      // Show result to user
      if (mounted) {
        if (deletedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully deleted $deletedCount downloaded files'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No downloaded files found to delete'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        
        if (failedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete $failedCount files'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

    } catch (e) {
      print('CLEAR_DOWNLOADS_ERROR: General error during clearing downloads: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing downloads: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose your childs age:', style: TextStyle(
          fontSize: 30, //Font size
          fontWeight: FontWeight.bold, //Bold title
          color: Color.fromARGB(255, 227, 101, 101), //Text color
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever), // Icon for clearing downloads
            tooltip: 'Clear All Downloads',
            onPressed: () async {
              // Show a confirmation dialog before deleting all files
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear All Downloads'),
                  content: const Text('Are you sure you want to delete all downloaded books (PDF/Word files)?\n\nThis action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Delete All'),
                    ),
                  ],
                ),
              );
              
              if (confirm == true) {
                // Show loading indicator while clearing
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const AlertDialog(
                    content: Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 20),
                        Text('Clearing downloads...'),
                      ],
                    ),
                  ),
                );
                
                await _clearAllDownloads();
                
                // Close loading dialog
                if (mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0), //Space around the grid
        child: GridView.builder(
          itemCount: services.length, //Total number of service tiles
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, //Two columns
            mainAxisSpacing: 12, //Vertical spacing
            crossAxisSpacing: 12, //Horizontal spacing
            childAspectRatio: 1.2, //Width to height ratio
          ),
          itemBuilder: (context, index) {
            final service = services[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BooksListPage1(
                      ageRange: service['age'] as String,
                      fileType: service['type'] as String,
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 225, 129, 140),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, //Center content
                  children: [
                    Icon(service['icon'] as IconData, size: 48, color: const Color.fromARGB(255, 66, 29, 29)), //Service icon
                    const SizedBox(height: 8), //Space between icon and text
                    Text(
                      service['label'] as String,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ), //Service label
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SecondMenuScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(), //Circular button
                padding: const EdgeInsets.all(16),
                backgroundColor: const Color.fromARGB(255, 242, 92, 110), //Button color
              ),
              child: const Icon(Icons.arrow_forward, color: Colors.white), //Arrow icon
            ),
          ),
        ],
      ),
    );
  }
}