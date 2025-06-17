// dashboard_screen.dart
// Main dashboard screen that displays age-based book categories
// Users can select books by age range (0-4, 4-8, 8-12) and file type (Word/PDF)

import 'package:flutter/material.dart';
import 'second_menu_screen.dart';
import 'books_list_page.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

/// Main dashboard screen widget that provides book category selection
/// and download management functionality
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Configuration for service tiles - defines available book categories
  // Each service has a label, icon, age range, and file type
  static const List<Map<String, dynamic>> _services = [
    {
      'label': 'Ages 0-4: Word',
      'icon': Icons.child_friendly,
      'age': '0-4',
      'type': 'word',
      'color': Color(0xFFE18194), // Soft pink for youngest age group
    },
    {
      'label': 'Ages 0-4: PDF',
      'icon': Icons.child_friendly,
      'age': '0-4',
      'type': 'pdf',
      'color': Color(0xFFE18194),
    },
    {
      'label': 'Ages 4-8: Word',
      'icon': Icons.emoji_nature,
      'age': '4-8',
      'type': 'word',
      'color': Color(0xFFB8E6B8), // Light green for middle age group
    },
    {
      'label': 'Ages 4-8: PDF',
      'icon': Icons.emoji_nature,
      'age': '4-8',
      'type': 'pdf',
      'color': Color(0xFFB8E6B8),
    },
    {
      'label': 'Ages 8-12: Word',
      'icon': Icons.auto_stories,
      'age': '8-12',
      'type': 'word',
      'color': Color(0xFF9ECBF0), // Light blue for oldest age group
    },
    {
      'label': 'Ages 8-12: PDF',
      'icon': Icons.auto_stories,
      'age': '8-12',
      'type': 'pdf',
      'color': Color(0xFF9ECBF0),
    },
  ];

  // Supported file extensions for download cleanup
  static const List<String> _documentExtensions = [
    '.pdf',
    '.doc',
    '.docx',
    '.word'
  ];

  // Loading state for clear downloads operation
  bool _isClearingDownloads = false;

  /// Clears all downloaded files and cancels active download tasks
  /// Shows progress dialog and confirmation before deletion
  Future<void> _clearAllDownloads() async {
    if (_isClearingDownloads) return; // Prevent multiple simultaneous operations

    setState(() {
      _isClearingDownloads = true;
    });

    try {
      // Step 1: Cancel all active downloads to prevent conflicts
      await FlutterDownloader.cancelAll();
      debugPrint('CLEAR_DOWNLOADS: All active downloads cancelled');

      // Step 2: Get the app's external storage directory
      final Directory? directory = await getExternalStorageDirectory();
      if (directory == null) {
        _showErrorSnackBar('Cannot access storage directory');
        return;
      }

      // Step 3: Check if directory exists
      if (!await directory.exists()) {
        _showInfoSnackBar('No downloads found to clear');
        return;
      }

      // Step 4: Process files in the directory
      final List<FileSystemEntity> entities = await directory.list().toList();
      final DeleteResult result = await _deleteDocumentFiles(entities);

      // Step 5: Show results to user
      _showDeleteResults(result);

    } catch (error, stackTrace) {
      debugPrint('CLEAR_DOWNLOADS_ERROR: $error');
      debugPrint('Stack trace: $stackTrace');
      _showErrorSnackBar('Error clearing downloads: ${error.toString()}');
    } finally {
      setState(() {
        _isClearingDownloads = false;
      });
    }
  }

  /// Deletes document files from the given list of entities
  /// Returns a DeleteResult with success and failure counts
  Future<DeleteResult> _deleteDocumentFiles(List<FileSystemEntity> entities) async {
    int deletedCount = 0;
    int failedCount = 0;

    for (final FileSystemEntity entity in entities) {
      if (entity is File && _isDocumentFile(entity)) {
        try {
          await entity.delete();
          deletedCount++;
          debugPrint('CLEARED_DOWNLOAD: Deleted ${entity.path}');
        } catch (error) {
          failedCount++;
          debugPrint('CLEAR_DOWNLOAD_ERROR: Failed to delete ${entity.path}: $error');
        }
      }
    }

    return DeleteResult(deletedCount: deletedCount, failedCount: failedCount);
  }

  /// Checks if a file is a document file based on its extension
  bool _isDocumentFile(File file) {
    final String fileName = path.basename(file.path).toLowerCase();
    return _documentExtensions.any((extension) => fileName.endsWith(extension));
  }

  /// Shows success/info snack bar message
  void _showInfoSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Shows error snack bar message
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Shows delete operation results to the user
  void _showDeleteResults(DeleteResult result) {
    if (!mounted) return;

    if (result.deletedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully deleted ${result.deletedCount} downloaded files'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      _showInfoSnackBar('No downloaded files found to delete');
    }

    if (result.failedCount > 0) {
      _showErrorSnackBar('Failed to delete ${result.failedCount} files');
    }
  }

  /// Shows confirmation dialog for clearing downloads
  /// Returns true if user confirms, false otherwise
  Future<bool> _showClearConfirmationDialog() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Force user to make a choice
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Clear All Downloads'),
        content: const Text(
          'Are you sure you want to delete all downloaded books (PDF/Word files)?\n\n'
          'This action cannot be undone.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  /// Shows loading dialog during clear downloads operation
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Flexible(child: Text('Clearing downloads...')),
          ],
        ),
      ),
    );
  }

  /// Handles the clear downloads button press
  /// Shows confirmation dialog and manages the clearing process
  Future<void> _handleClearDownloads() async {
    // Step 1: Get user confirmation
    final bool confirmed = await _showClearConfirmationDialog();
    if (!confirmed) return;

    // Step 2: Show loading dialog
    _showLoadingDialog();

    // Step 3: Perform the clearing operation
    await _clearAllDownloads();

    // Step 4: Close loading dialog
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Navigates to the books list page for the selected service
  void _navigateToBooksList(Map<String, dynamic> service) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => BooksListPage1(
          ageRange: service['age'] as String,
          fileType: service['type'] as String,
        ),
      ),
    );
  }

  /// Navigates to the secondary menu screen
  void _navigateToSecondMenu() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) => const SecondMenuScreen(),
      ),
    );
  }

  /// Builds a service tile widget for the grid
  Widget _buildServiceTile(Map<String, dynamic> service) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _navigateToBooksList(service),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: service['color'] as Color? ?? const Color(0xFFE18194),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Service icon
              Icon(
                service['icon'] as IconData,
                size: 48,
                color: const Color(0xFF421D1D),
              ),
              const SizedBox(height: 12),
              // Service label with padding for better text wrapping
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  service['label'] as String,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // App bar with title and clear downloads action
      appBar: AppBar(
        title: const Text(
          'Choose your child\'s age:',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFFE36565),
          ),
        ),
        centerTitle: false,
        elevation: 2,
        actions: [
          // Clear downloads button
          IconButton(
            icon: _isClearingDownloads
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_forever),
            tooltip: 'Clear All Downloads',
            onPressed: _isClearingDownloads ? null : _handleClearDownloads,
          ),
        ],
      ),

      // Main content - Grid of service tiles
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          itemCount: _services.length,
          physics: const BouncingScrollPhysics(), // Better scroll behavior
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1, // Slightly adjusted for better proportions
          ),
          itemBuilder: (BuildContext context, int index) {
            return _buildServiceTile(_services[index]);
          },
        ),
      ),

      // Bottom navigation with secondary menu button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Secondary menu navigation button
            FloatingActionButton(
              onPressed: _navigateToSecondMenu,
              backgroundColor: const Color(0xFFF25C6E),
              child: const Icon(
                Icons.arrow_forward,
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Data class to hold delete operation results
class DeleteResult {
  final int deletedCount;
  final int failedCount;

  const DeleteResult({
    required this.deletedCount,
    required this.failedCount,
  });
}