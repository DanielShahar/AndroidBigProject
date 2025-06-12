// Inside books_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart'; // Ensure this is open_filex

// Define DownloadState enum outside the class if not already defined globally
enum DownloadState { initial, downloading, completed }

class BooksListPage1 extends StatefulWidget {
  final String ageRange;
  final String fileType;

  const BooksListPage1({
    super.key,
    required this.ageRange,
    required this.fileType,
  });

  @override
  State<BooksListPage1> createState() => _BooksListPageState();
}

class _BooksListPageState extends State<BooksListPage1> {
  final Map<String, DownloadState> _downloadStates = {};
  // Add a subscription to listen for download progress
  // You might need to adjust this depending on how FlutterDownloader provides its updates.
  // The official way is via the top-level callback which you then need to communicate to your UI.
  // For simplicity, we'll assume a mechanism to receive updates here, or you might need to use a package like provider/bloc for global state.

  // Let's rely on the global callback to update the UI.
  // The correct way to update the UI based on the global callback is more involved
  // and usually requires a global state management solution or a mechanism to broadcast updates.
  // For now, let's keep it simple by directly integrating the callback, but be aware
  // this is a simplified approach for demonstration.

  @override
  void initState() {
    super.initState();
    // This is a simplified way to update the UI from a global callback.
    // In a real app, you might use a Provider, Riverpod, BLoC, etc.
    // However, FlutterDownloader's callback doesn't directly return a stream you can listen to here.
    // The most robust way to get updates back to specific widgets is via a global manager or listener pattern.

    // For now, we'll add print statements and remove the misleading Future.delayed.
    // The visual state changes to 'downloading' when started, and will stay there until the app is restarted
    // or a more sophisticated state management is implemented to receive the 'completed' status from the global callback.
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _startDownload(String bookTitle, String fileUrl) async {
    // Check if the download is already in progress or completed
    if (_downloadStates[bookTitle] == DownloadState.downloading ||
        _downloadStates[bookTitle] == DownloadState.completed) {
      print('DOWNLOAD_INFO: Download for $bookTitle already in progress or completed. Skipping.');
      return;
    }

    setState(() {
      _downloadStates[bookTitle] = DownloadState.downloading;
    });

    try {
      final directory = await getExternalStorageDirectory(); // This is for Android
      if (directory == null) {
        print('DOWNLOAD_ERROR: Could not get external storage directory. Directory is null.');
        setState(() {
          _downloadStates[bookTitle] = DownloadState.initial;
        });
        return;
      }

      // Ensure directory path is valid and accessible
      final savedDir = directory.path;
      print('DOWNLOAD_INFO: Attempting to save to: $savedDir');

      final taskId = await FlutterDownloader.enqueue(
        url: fileUrl,
        savedDir: savedDir,
        fileName: '$bookTitle.${widget.fileType}', // Use a consistent file extension
        showNotification: true,
        openFileFromNotification: true,
      );

      if (taskId == null) {
        print('DOWNLOAD_ERROR: Failed to enqueue download task for $bookTitle. taskId is null.');
        setState(() {
          _downloadStates[bookTitle] = DownloadState.initial;
        });
        return;
      }

      print('DOWNLOAD_INFO: Download enqueued for $bookTitle with taskId: $taskId');

      // The state update to 'completed' should come from the global downloadCallback.
      // This `Future.delayed` is REMOVED because it's not accurate.
      // We will rely on the global `downloadCallback` to eventually update the UI.
      // For now, once enqueued, the button will show "downloading" until the app is reopened
      // or a more advanced state management system is in place.

    } catch (e) {
      print('DOWNLOAD_ERROR: Failed to start download for $bookTitle: $e');
      setState(() {
        _downloadStates[bookTitle] = DownloadState.initial;
      });
    }
  }

  Future<void> _openDownloadedFile(String bookTitle, String fileUrl) async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        print('OPEN_FILE_ERROR: Could not get external storage directory.');
        return;
      }

      final filePath = '${directory.path}/$bookTitle.${widget.fileType}';
      print('OPEN_FILE_INFO: Attempting to open file: $filePath');

      final result = await OpenFilex.open(filePath);
      print('OPEN_FILE_RESULT: ${result.message}');

      if (result.type != ResultType.done) {
        print('OPEN_FILE_ERROR: Failed to open file: ${result.message}');
      }
    } catch (e) {
      print('OPEN_FILE_ERROR: An error occurred while opening file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ages ${widget.ageRange} - ${widget.fileType.toUpperCase()} Books'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Image.network(
              widget.fileType == 'word'
                  ? 'https://img.icons8.com/color/48/000000/microsoft-word-2019--v1.png'
                  : 'https://img.icons8.com/color/48/000000/pdf--v1.png',
              height: 40,
              width: 40,
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('books') // <--- CONFIRM THIS IS YOUR ROLLED-BACK COLLECTION NAME
            .where('age_range', isEqualTo: widget.ageRange)
            .where('file_type', isEqualTo: widget.fileType)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('FIRESTORE_ERROR: ${snapshot.error}');
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No books found in this category.'));
          }

          final books = snapshot.data!.docs;

          return ListView.builder(
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              final bookTitle = book['title'] as String;
              final fileUrl = book['file_url'] as String;

              // Ensure the download state is initialized for this book
              if (!_downloadStates.containsKey(bookTitle)) {
                _downloadStates[bookTitle] = DownloadState.initial;
              }

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          bookTitle,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      DownloadButton(
                        downloadState: _downloadStates[bookTitle]!,
                        onPressed: () {
                          if (_downloadStates[bookTitle] == DownloadState.initial) {
                            _startDownload(bookTitle, fileUrl);
                          } else if (_downloadStates[bookTitle] == DownloadState.completed) {
                            _openDownloadedFile(bookTitle, fileUrl);
                          }
                          // Do nothing if already downloading
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Ensure the DownloadButton and DownloadState enum are defined within this file
// or imported from another file if they are in 'download_items_pdf.dart' as per your original structure.
// If DownloadButton is in 'download_items_pdf.dart', ensure it's imported.
// If DownloadState enum is in 'download_items_pdf.dart', make sure it's available globally or imported correctly.