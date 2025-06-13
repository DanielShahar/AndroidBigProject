// books_list_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:android_big_project/main.dart'; // Import main.dart to access downloadUpdates
import 'dart:io'; // Import for File operations

enum DownloadState { initial, downloading, completed, failed } // Added failed state

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
  // Store task IDs mapped by book title
  final Map<String, String> _downloadTaskIds = {}; // bookTitle -> taskId

  @override
  void initState() {
    super.initState();
    downloadUpdates.addListener(_onDownloadUpdate);
    _loadExistingDownloads();
  }

  @override
  void dispose() {
    downloadUpdates.removeListener(_onDownloadUpdate);
    super.dispose();
  }

  void _onDownloadUpdate() {
    if (!mounted) return;

    // Get the updated map from the ValueNotifier (now taskId -> status)
    final Map<String, DownloadTaskStatus> currentDownloadStatuses = downloadUpdates.value;

    setState(() {
      currentDownloadStatuses.forEach((taskId, status) {
        // Find the bookTitle corresponding to this taskId
        // We iterate through _downloadTaskIds to find the bookTitle that matches the taskId
        final bookTitle = _downloadTaskIds.entries
            .firstWhere((entry) => entry.value == taskId, orElse: () => const MapEntry('', ''))
            .key;

        if (bookTitle.isNotEmpty) {
          DownloadState newUiState;
          if (status == DownloadTaskStatus.complete) {
            newUiState = DownloadState.completed;
          } else if (status == DownloadTaskStatus.failed || status == DownloadTaskStatus.canceled) {
            newUiState = DownloadState.failed;
          } else if (status == DownloadTaskStatus.running || status == DownloadTaskStatus.enqueued) {
            newUiState = DownloadState.downloading;
          } else {
            newUiState = DownloadState.initial;
          }

          if (_downloadStates[bookTitle] != newUiState) {
            _downloadStates[bookTitle] = newUiState;
            print('UI_UPDATE: ${bookTitle} state updated to $newUiState (from taskId: $taskId)');
          }
        }
      });
    });
  }

  Future<void> _loadExistingDownloads() async {
    final tasks = await FlutterDownloader.loadTasks();
    if (tasks != null) {
      setState(() {
        for (var task in tasks) {
          if (task.filename != null) {
            final bookTitleFromFilename = task.filename!.split('.').first;

            if (task.status == DownloadTaskStatus.complete) {
              _downloadStates[bookTitleFromFilename] = DownloadState.completed;
            } else if (task.status == DownloadTaskStatus.running || task.status == DownloadTaskStatus.enqueued) {
              _downloadStates[bookTitleFromFilename] = DownloadState.downloading;
            } else if (task.status == DownloadTaskStatus.failed || task.status == DownloadTaskStatus.canceled) {
              _downloadStates[bookTitleFromFilename] = DownloadState.failed;
            }
            // Store the taskId here to map it back from global updates
            _downloadTaskIds[bookTitleFromFilename] = task.taskId;
          }
        }
      });
    }
  }

  Future<void> _startDownload(String bookTitle, String fileUrl) async {
    if (_downloadStates[bookTitle] == DownloadState.downloading ||
        _downloadStates[bookTitle] == DownloadState.completed) {
      print('DOWNLOAD_INFO: Download for $bookTitle already in progress or completed. Skipping.');
      if (_downloadStates[bookTitle] == DownloadState.failed) {
        print('DOWNLOAD_INFO: Retrying download for $bookTitle.');
      } else {
        return;
      }
    }

    setState(() {
      _downloadStates[bookTitle] = DownloadState.downloading;
    });

    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        print('DOWNLOAD_ERROR: Could not get external storage directory. Directory is null.');
        setState(() {
          _downloadStates[bookTitle] = DownloadState.failed;
        });
        return;
      }

      final savedDir = directory.path;
      final fileNameWithExt = '$bookTitle.${widget.fileType}';
      final filePath = '$savedDir/$fileNameWithExt';

      // --- NEW: Delete existing file before re-downloading ---
      final file = File(filePath);
      if (await file.exists()) {
        print('DOWNLOAD_INFO: Found existing file, deleting: $filePath');
        await file.delete();
      }
      // --- END NEW ---

      print('DOWNLOAD_INFO: Attempting to save "$fileNameWithExt" to: $savedDir');
      print('DOWNLOAD_INFO: Downloading from URL: $fileUrl');

      final taskId = await FlutterDownloader.enqueue(
        url: fileUrl,
        savedDir: savedDir,
        fileName: fileNameWithExt,
        showNotification: true,
        openFileFromNotification: true,
      );

      if (taskId == null) {
        print('DOWNLOAD_ERROR: Failed to enqueue download task for $bookTitle. taskId is null.');
        setState(() {
          _downloadStates[bookTitle] = DownloadState.failed;
        });
        return;
      }

      // Store the taskId immediately when enqueuing the download
      _downloadTaskIds[bookTitle] = taskId;
      print('DOWNLOAD_INFO: Download enqueued for $bookTitle with taskId: $taskId');

    } catch (e) {
      print('DOWNLOAD_ERROR: Failed to start download for $bookTitle: $e');
      setState(() {
        _downloadStates[bookTitle] = DownloadState.failed;
      });
    }
  }

  Future<void> _openDownloadedFile(String bookTitle) async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        print('OPEN_FILE_ERROR: Could not get external storage directory.');
        return;
      }

      final filePath = '${directory.path}/$bookTitle.${widget.fileType}';
      print('OPEN_FILE_INFO: Attempting to open file: $filePath');

      final result = await OpenFilex.open(filePath);
      print('OPEN_FILE_RESULT: ${result.message}, Type: ${result.type}');

      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open file: ${result.message}. You might need a compatible app.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('OPEN_FILE_ERROR: An error occurred while opening file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred while opening file: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
            .collection('ChildrenBooksLinks')
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
              final bookTitle = book['Title'] as String;
              final fileUrl = book['linkURL'] as String;

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
                          if (_downloadStates[bookTitle] == DownloadState.initial ||
                              _downloadStates[bookTitle] == DownloadState.failed) {
                            _startDownload(bookTitle, fileUrl);
                          } else if (_downloadStates[bookTitle] == DownloadState.completed) {
                            _openDownloadedFile(bookTitle);
                          }
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

class DownloadButton extends StatelessWidget {
  final DownloadState downloadState;
  final VoidCallback onPressed;

  const DownloadButton({
    super.key,
    required this.downloadState,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (downloadState) {
        DownloadState.initial => _buildButton('GET', onPressed),
        DownloadState.downloading => const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        DownloadState.completed => _buildButton('OPEN', onPressed),
        DownloadState.failed => _buildButton('RETRY', onPressed),
      },
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      key: ValueKey(text),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: text == 'OPEN' ? Colors.green : const Color(0xFFE0E0E0),
        foregroundColor: text == 'OPEN' ? Colors.white : Colors.pink,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(60, 30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
      child: Text(text),
    );
  }
}