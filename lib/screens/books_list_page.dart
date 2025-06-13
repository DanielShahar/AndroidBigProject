// books_list_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io'; // Needed for File operations
import 'package:path/path.dart' as path; // Needed for path.join
import 'package:android_big_project/main.dart'; // Import main.dart to access downloadUpdateNotifier

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
  // Map to store bookTitle -> taskId, allowing lookup of taskId from bookTitle
  final Map<String, String> _bookTitleToTaskId = {};
  // Map to store taskId -> bookTitle, allowing lookup of bookTitle from taskId
  final Map<String, String> _taskIdToBookTitle = {};

  @override
  void initState() {
    super.initState();
    // Listen to global download updates broadcast from main.dart
    downloadUpdateNotifier.addListener(_onDownloadUpdate);
  }

  @override
  void dispose() {
    // Remove the listener to prevent memory leaks
    downloadUpdateNotifier.removeListener(_onDownloadUpdate);
    super.dispose();
  }

  // Method to handle updates from the global download callback
  void _onDownloadUpdate() {
    final update = downloadUpdateNotifier.value;
    // Check if the update is not empty (initial value) and contains necessary info
    if (update.isNotEmpty && update['id'] != null && update['status'] != null) {
      final String taskId = update['id']!;
      final int status = update['status']!; // status is an int here

      // Look up the bookTitle associated with the completed taskId
      final bookTitle = _taskIdToBookTitle[taskId];
      if (bookTitle != null) {
        if (status == DownloadTaskStatus.complete.index) {
          // If download completed, update state to 'completed'
          setState(() {
            _downloadStates[bookTitle] = DownloadState.completed;
            // Remove task ID mappings as the download is finished
            _bookTitleToTaskId.remove(bookTitle);
            _taskIdToBookTitle.remove(taskId);
          });
        } else if (status == DownloadTaskStatus.failed.index ||
            status == DownloadTaskStatus.canceled.index) {
          // If download failed or canceled, revert state to 'initial'
          setState(() {
            _downloadStates[bookTitle] = DownloadState.initial;
            // Remove task ID mappings on failure/cancellation
            _bookTitleToTaskId.remove(bookTitle);
            _taskIdToBookTitle.remove(taskId);
          });
        }
        // You could also add logic here for DownloadTaskStatus.running to update progress bars
        // if you were displaying them within the list items.
      }
    }
  }

  Future<void> _startDownload(String bookTitle, String fileUrl) async {
    // Set the state to 'downloading' immediately to show the spinner
    setState(() {
      _downloadStates[bookTitle] = DownloadState.downloading;
    });

    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        print('DOWNLOAD_ERROR: Could not get external storage directory.');
        // Revert state if directory is not accessible
        setState(() {
          _downloadStates[bookTitle] = DownloadState.initial;
        });
        return;
      }

      final fileName = '$bookTitle.${widget.fileType}';
      final savedPath = path.join(directory.path, fileName);
      final file = File(savedPath);

      // Check if the file already exists and delete it to prevent 416 error on retry/re-download
      if (await file.exists()) {
        print('DOWNLOAD_INFO: Found existing file, deleting: $savedPath');
        await file.delete();
      }

      print('DOWNLOAD_INFO: Attempting to save "$bookTitle" to: $savedPath');
      print('DOWNLOAD_INFO: Downloading from URL: $fileUrl');

      // Enqueue the download task
      final taskId = await FlutterDownloader.enqueue(
        url: fileUrl,
        savedDir: directory.path,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: true,
        saveInPublicStorage: false, // Recommended for Android 10+ scoped storage
      );

      if (taskId != null) {
        print('DOWNLOAD_INFO: Download enqueued for $bookTitle with taskId: $taskId');
        // Store the taskId associated with the bookTitle for future lookups
        _bookTitleToTaskId[bookTitle] = taskId;
        _taskIdToBookTitle[taskId] = bookTitle;
      } else {
        print('DOWNLOAD_ERROR: Failed to enqueue download for $bookTitle');
        // Revert state if enqueue failed
        setState(() {
          _downloadStates[bookTitle] = DownloadState.initial;
        });
      }
    } catch (e) {
      print('DOWNLOAD_ERROR: Error starting download for $bookTitle: $e');
      // Revert state on any error during download initiation
      setState(() {
        _downloadStates[bookTitle] = DownloadState.initial;
      });
    }
  }

  Future<void> _openFile(String bookTitle) async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        print('OPEN_FILE_ERROR: Could not get external storage directory.');
        return;
      }

      final fileName = '$bookTitle.${widget.fileType}';
      final filePath = path.join(directory.path, fileName);
      print('OPEN_FILE_INFO: Attempting to open file: $filePath');

      final result = await OpenFilex.open(filePath);
      print('OPEN_FILE_RESULT: ${result.message}, Type: ${result.type}');

      if (result.type != ResultType.done) {
        // Handle error opening file (e.g., no app to open PDF)
        print('OPEN_FILE_ERROR: Failed to open file: ${result.message}');
        // You might want to show a SnackBar or AlertDialog to the user here
      }
    } catch (e) {
      print('OPEN_FILE_ERROR: Error opening file: $e');
      // Handle general errors during file opening
    }
  }

  // Stream to fetch book data from Firestore
  Stream<List<Map<String, dynamic>>> _getBooksStream() {
    return FirebaseFirestore.instance
        .collection('ChildrenBooksLinks')
        .where('age_range', isEqualTo: widget.ageRange)
        .where('file_type', isEqualTo: widget.fileType)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.ageRange} ${widget.fileType.toUpperCase()} Books'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getBooksStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No books found for this category.'));
          }

          final books = snapshot.data!;

          // Use addPostFrameCallback to update download states after the widget tree is built
          // This ensures UI state is correct upon initial load or when data changes
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final directory = await getExternalStorageDirectory();
            if (directory == null) return;

            final List<DownloadTask>? allTasks = await FlutterDownloader.loadTasks();
            bool stateChanged = false; // Flag to check if setState is needed

            // Create temporary maps to store potential state updates
            final Map<String, DownloadState> newDownloadStates = {};
            final Map<String, String> newBookTitleToTaskId = {};
            final Map<String, String> newTaskIdToBookTitle = {};

            for (var book in books) {
              final bookTitle = (book['Title'] as String?) ?? 'Unknown Title';
              final fileName = '$bookTitle.${widget.fileType}';
              final savedPath = path.join(directory.path, fileName);
              final file = File(savedPath);

              // Only update state if it's not already being managed by an active download or completed status.
              // This prioritizes the real-time updates from _onDownloadUpdate.
              if (_downloadStates.containsKey(bookTitle) &&
                  (_downloadStates[bookTitle] == DownloadState.downloading ||
                   _downloadStates[bookTitle] == DownloadState.completed)) {
                continue; // Skip if already downloading or completed, as _onDownloadUpdate handles these.
              }

              if (await file.exists()) {
                if (_downloadStates[bookTitle] != DownloadState.completed) {
                  newDownloadStates[bookTitle] = DownloadState.completed;
                  stateChanged = true;
                }
              } else {
                final activeTask = allTasks?.firstWhere(
                  (task) => task.filename == fileName &&
                              (task.status == DownloadTaskStatus.running ||
                               task.status == DownloadTaskStatus.enqueued ||
                               task.status == DownloadTaskStatus.paused),
                  orElse: () => DownloadTask(
                    taskId: '',
                    url: '',
                    status: DownloadTaskStatus.undefined,
                    progress: 0,
                    filename: '',
                    savedDir: '',
                    timeCreated: 0,
                    allowCellular: true,
                  ),
                );

                if (activeTask != null && activeTask.status != DownloadTaskStatus.undefined) {
                  if (_downloadStates[bookTitle] != DownloadState.downloading) {
                    newDownloadStates[bookTitle] = DownloadState.downloading;
                    newBookTitleToTaskId[bookTitle] = activeTask.taskId;
                    newTaskIdToBookTitle[activeTask.taskId] = bookTitle;
                    stateChanged = true;
                  }
                } else {
                  if (_downloadStates[bookTitle] != DownloadState.initial) {
                    newDownloadStates[bookTitle] = DownloadState.initial;
                    stateChanged = true;
                  }
                }
              }
            }

            // Only call setState once if there are changes to apply
            if (stateChanged) {
              setState(() {
                _downloadStates.addAll(newDownloadStates);
                _bookTitleToTaskId.addAll(newBookTitleToTaskId);
                _taskIdToBookTitle.addAll(newTaskIdToBookTitle);
              });
            }
          });

          return ListView.builder(
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              final bookTitle = (book['Title'] as String?) ?? 'Untitled Book';
              final fileUrl = (book['linkURL'] as String?) ?? '';

              // Get the current download state for this book, defaulting to initial
              final downloadState = _downloadStates[bookTitle] ?? DownloadState.initial;

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          bookTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DownloadButton(
                        downloadState: downloadState,
                        onPressed: () {
                          if (downloadState == DownloadState.initial) {
                            _startDownload(bookTitle, fileUrl);
                          } else if (downloadState == DownloadState.completed) {
                            _openFile(bookTitle);
                          }
                          // If downloadState is downloading, do nothing on press
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
      },
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      key: ValueKey(text), // Key is important for AnimatedSwitcher to work correctly
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE0E0E0),
        foregroundColor: Colors.pink,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(60, 30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        elevation: 0,
      ),
      child: Text(text),
    );
  }
}