// books_list_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io'; // Needed for File operations
import 'dart:async'; // Added this import for Timer
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
  
  // Timer for periodic download status checks
  Timer? _downloadCheckTimer;

  @override
  void initState() {
    super.initState();
    // Listen to global download updates broadcast from main.dart
    downloadUpdateNotifier.addListener(_onDownloadUpdate);
    // Initialize download states when the page loads
    _initializeDownloadStates();
  }

  @override
  void dispose() {
    // Remove the listener to prevent memory leaks
    downloadUpdateNotifier.removeListener(_onDownloadUpdate);
    // Cancel the timer if it exists
    _downloadCheckTimer?.cancel();
    super.dispose();
  }

  // Initialize download states by checking existing files
  Future<void> _initializeDownloadStates() async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) return;

      // Get all books from Firestore to check their download status
      final snapshot = await FirebaseFirestore.instance
          .collection('ChildrenBooksLinks')
          .where('age_range', isEqualTo: widget.ageRange)
          .where('file_type', isEqualTo: widget.fileType)
          .get();

      final Map<String, DownloadState> newStates = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final bookTitle = (data['Title'] as String?) ?? 'Unknown Title';
        final fileName = '$bookTitle.${widget.fileType}';
        final filePath = path.join(directory.path, fileName);
        final file = File(filePath);

        if (await file.exists()) {
          newStates[bookTitle] = DownloadState.completed;
        } else {
          newStates[bookTitle] = DownloadState.initial;
        }
      }

      if (mounted) {
        setState(() {
          _downloadStates.addAll(newStates);
        });
      }
    } catch (e) {
      print('INIT_ERROR: Error initializing download states: $e');
    }
  }

  // Method to handle updates from the global download callback
  void _onDownloadUpdate() {
    final update = downloadUpdateNotifier.value;
    print('DOWNLOAD_UPDATE_RECEIVED: $update'); // Debug log
    
    // Check if the update is not empty (initial value) and contains necessary info
    if (update.isNotEmpty && update['id'] != null && update['status'] != null) {
      final String taskId = update['id']!;
      final int status = update['status']!; // status is an int here

      print('DOWNLOAD_UPDATE_PROCESSING: TaskId: $taskId, Status: $status');

      // Look up the bookTitle associated with the completed taskId
      final bookTitle = _taskIdToBookTitle[taskId];
      print('DOWNLOAD_UPDATE_BOOK: $bookTitle found for taskId: $taskId');
      
      if (bookTitle != null && mounted) {
        if (status == DownloadTaskStatus.complete.index) {
          print('DOWNLOAD_UPDATE_COMPLETE: Setting $bookTitle to completed state');
          // If download completed, update state to 'completed'
          setState(() {
            _downloadStates[bookTitle] = DownloadState.completed;
            // Remove task ID mappings as the download is finished
            _bookTitleToTaskId.remove(bookTitle);
            _taskIdToBookTitle.remove(taskId);
          });
          print('DOWNLOAD_SUCCESS: $bookTitle download completed and UI updated');
          
          // Clear the notifier value to prevent repeated triggers
          WidgetsBinding.instance.addPostFrameCallback((_) {
            downloadUpdateNotifier.value = {};
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
          print('DOWNLOAD_FAILED: $bookTitle download failed or canceled');
          
          // Show error message to user
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Download failed for: $bookTitle'),
                backgroundColor: Colors.red,
              ),
            );
          }
          
          // Clear the notifier value
          WidgetsBinding.instance.addPostFrameCallback((_) {
            downloadUpdateNotifier.value = {};
          });
        }
      } else {
        print('DOWNLOAD_UPDATE_ERROR: No bookTitle found for taskId: $taskId or widget not mounted');
        print('DOWNLOAD_UPDATE_MAPPINGS: $_taskIdToBookTitle');
      }
    }
  }

  Future<void> _startDownload(String bookTitle, String fileUrl) async {
    if (fileUrl.isEmpty) {
      print('DOWNLOAD_ERROR: Empty file URL for $bookTitle');
      return;
    }

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

      // Ensure the directory exists
      if (!await directory.exists()) {
        await directory.create(recursive: true);
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
        print('DOWNLOAD_MAPPING_STORED: $bookTitle -> $taskId');
        print('DOWNLOAD_CURRENT_MAPPINGS: $_taskIdToBookTitle');
        
        // Start a fallback timer to check download status periodically
        _startDownloadCheckTimer(bookTitle, taskId);
        
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

  // Fallback method to periodically check download status
  void _startDownloadCheckTimer(String bookTitle, String taskId) {
    _downloadCheckTimer?.cancel(); // Cancel any existing timer
    
    _downloadCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final tasks = await FlutterDownloader.loadTasks();
        final task = tasks?.firstWhere(
          (task) => task.taskId == taskId,
          orElse: () => throw StateError('Task not found'),
        );
        
        if (task != null) {
          print('TIMER_CHECK: Task $taskId status: ${task.status}, progress: ${task.progress}');
          
          if (task.status == DownloadTaskStatus.complete) {
            // Download completed
            timer.cancel();
            if (mounted) {
              setState(() {
                _downloadStates[bookTitle] = DownloadState.completed;
                _bookTitleToTaskId.remove(bookTitle);
                _taskIdToBookTitle.remove(taskId);
              });
            }
            print('TIMER_SUCCESS: $bookTitle download completed via timer check');
            
          } else if (task.status == DownloadTaskStatus.failed || 
                     task.status == DownloadTaskStatus.canceled) {
            // Download failed
            timer.cancel();
            if (mounted) {
              setState(() {
                _downloadStates[bookTitle] = DownloadState.initial;
                _bookTitleToTaskId.remove(bookTitle);
                _taskIdToBookTitle.remove(taskId);
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Download failed for: $bookTitle'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            print('TIMER_FAILED: $bookTitle download failed via timer check');
          }
        }
      } catch (e) {
        print('TIMER_ERROR: Error checking download status: $e');
        // If we can't find the task, assume it's completed and check if file exists
        timer.cancel();
        _checkFileExistence(bookTitle);
      }
    });
  }

  // Helper method to check if file exists and update state accordingly
  Future<void> _checkFileExistence(String bookTitle) async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) return;
      
      final fileName = '$bookTitle.${widget.fileType}';
      final filePath = path.join(directory.path, fileName);
      final file = File(filePath);
      
      if (mounted) {
        setState(() {
          if (file.existsSync()) {
            _downloadStates[bookTitle] = DownloadState.completed;
            print('FILE_CHECK: $bookTitle file exists, setting to completed');
          } else {
            _downloadStates[bookTitle] = DownloadState.initial;
            print('FILE_CHECK: $bookTitle file not found, setting to initial');
          }
        });
      }
    } catch (e) {
      print('FILE_CHECK_ERROR: Error checking file existence: $e');
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

      // Check if file exists before trying to open it
      final file = File(filePath);
      if (!await file.exists()) {
        print('OPEN_FILE_ERROR: File does not exist: $filePath');
        // Reset state to initial if file doesn't exist
        setState(() {
          _downloadStates[bookTitle] = DownloadState.initial;
        });
        return;
      }

      final result = await OpenFilex.open(filePath);
      print('OPEN_FILE_RESULT: ${result.message}, Type: ${result.type}');

      if (result.type != ResultType.done) {
        // Handle error opening file (e.g., no app to open PDF)
        print('OPEN_FILE_ERROR: Failed to open file: ${result.message}');
        // Show a snackbar to inform the user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot open file: ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('OPEN_FILE_ERROR: Error opening file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error opening file'),
            backgroundColor: Colors.red,
          ),
        );
      }
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