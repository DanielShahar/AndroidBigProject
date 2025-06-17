// books_list_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:android_big_project/main.dart';

// Debug logging maintained for download tracking and error diagnosis

/// Enum representing the different states of a download
enum DownloadState { 
  initial,      // Ready to download
  downloading,  // Currently downloading
  completed     // Download finished and file available
}

/// Main page widget that displays a list of books for a specific age range and file type
/// Handles downloading, opening, and managing book files
class BooksListPage1 extends StatefulWidget {
  final String ageRange;  // Age range filter (e.g., "0-4", "4-8", "8-12")
  final String fileType;  // File type filter (e.g., "pdf", "word")

  const BooksListPage1({
    super.key,
    required this.ageRange,
    required this.fileType,
  });

  @override
  State<BooksListPage1> createState() => _BooksListPageState();
}

class _BooksListPageState extends State<BooksListPage1> {
  // === STATE MANAGEMENT ===
  
  /// Maps book titles to their current download states
  final Map<String, DownloadState> _downloadStates = {};
  
  /// Bidirectional mapping between book titles and download task IDs
  /// This allows us to track which download belongs to which book
  final Map<String, String> _bookTitleToTaskId = {};
  final Map<String, String> _taskIdToBookTitle = {};
  
  /// Timer for periodic download status checks (fallback mechanism)
  Timer? _downloadCheckTimer;
  
  /// Cache for the external storage directory to avoid repeated async calls
  Directory? _cachedStorageDirectory;

  // === LIFECYCLE METHODS ===

  @override
  void initState() {
    super.initState();
    _setupDownloadListener();
    _initializeAppState();
  }

  @override
  void dispose() {
    _cleanupResources();
    super.dispose();
  }

  // === INITIALIZATION METHODS ===

  /// Sets up the global download update listener
  void _setupDownloadListener() {
    downloadUpdateNotifier.addListener(_onDownloadUpdate);
  }

  /// Initializes the app state by checking existing downloads and cached directory
  Future<void> _initializeAppState() async {
    await _cacheStorageDirectory();
    await _initializeDownloadStates();
  }

  /// Caches the external storage directory to improve performance
  Future<void> _cacheStorageDirectory() async {
    try {
      _cachedStorageDirectory = await getExternalStorageDirectory();
      if (_cachedStorageDirectory != null && !await _cachedStorageDirectory!.exists()) {
        await _cachedStorageDirectory!.create(recursive: true);
      }
    } catch (e) {
      debugPrint('CACHE_ERROR: Failed to cache storage directory: $e');
    }
  }

  /// Scans existing files and initializes download states accordingly
  /// This ensures UI consistency when reopening the app
  Future<void> _initializeDownloadStates() async {
    if (_cachedStorageDirectory == null) return;

    try {
      // Fetch all books for this category from Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('ChildrenBooksLinks')
          .where('age_range', isEqualTo: widget.ageRange)
          .where('file_type', isEqualTo: widget.fileType)
          .get();

      // Check each book's download status
      final Map<String, DownloadState> newStates = {};
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final bookTitle = _extractBookTitle(data);
        
        if (await _isBookDownloaded(bookTitle)) {
          newStates[bookTitle] = DownloadState.completed;
        } else {
          newStates[bookTitle] = DownloadState.initial;
        }
      }

      // Update UI with new states
      if (mounted) {
        setState(() {
          _downloadStates.addAll(newStates);
        });
      }
    } catch (e) {
      debugPrint('INIT_ERROR: Failed to initialize download states: $e');
    }
  }

  // === DOWNLOAD UPDATE HANDLING ===

  /// Handles updates from the global download callback
  /// This method is called whenever a download status changes
  void _onDownloadUpdate() {
    final update = downloadUpdateNotifier.value;
    
    // Validate update data
    if (!_isValidUpdate(update)) return;
    
    final String taskId = update['id']!;
    final int status = update['status']!;
    
    // Find the book associated with this task
    final bookTitle = _taskIdToBookTitle[taskId];
    if (bookTitle == null || !mounted) {
      debugPrint('DOWNLOAD_UPDATE_ERROR: No book found for taskId: $taskId');
      return;
    }
    
    _processDownloadStatusUpdate(bookTitle, taskId, status);
  }

  /// Validates that the download update contains required fields
  bool _isValidUpdate(Map<String, dynamic> update) {
    return update.isNotEmpty && 
           update['id'] != null && 
           update['status'] != null;
  }

  /// Processes the download status update and updates UI accordingly
  void _processDownloadStatusUpdate(String bookTitle, String taskId, int status) {
    if (status == DownloadTaskStatus.complete.index) {
      _handleDownloadComplete(bookTitle, taskId);
    } else if (status == DownloadTaskStatus.failed.index || 
               status == DownloadTaskStatus.canceled.index) {
      _handleDownloadFailed(bookTitle, taskId);
    }
  }

  /// Handles successful download completion
  void _handleDownloadComplete(String bookTitle, String taskId) {
    debugPrint('DOWNLOAD_COMPLETE: $bookTitle finished downloading');
    
    setState(() {
      _downloadStates[bookTitle] = DownloadState.completed;
      _cleanupTaskMappings(bookTitle, taskId);
    });
    
    _clearNotifierValue();
    _showSuccessMessage(bookTitle);
  }

  /// Handles download failure or cancellation
  void _handleDownloadFailed(String bookTitle, String taskId) {
    debugPrint('DOWNLOAD_FAILED: $bookTitle download failed or canceled');
    
    setState(() {
      _downloadStates[bookTitle] = DownloadState.initial;
      _cleanupTaskMappings(bookTitle, taskId);
    });
    
    _clearNotifierValue();
    _showErrorMessage('Download failed for: $bookTitle');
  }

  /// Removes task ID mappings when download is complete or failed
  void _cleanupTaskMappings(String bookTitle, String taskId) {
    _bookTitleToTaskId.remove(bookTitle);
    _taskIdToBookTitle.remove(taskId);
  }

  /// Clears the notifier value to prevent repeated triggers
  void _clearNotifierValue() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      downloadUpdateNotifier.value = {};
    });
  }

  // === DOWNLOAD MANAGEMENT ===

  /// Initiates download for a specific book
  /// Handles error cases and provides user feedback
  Future<void> _startDownload(String bookTitle, String fileUrl) async {
    // Validate inputs
    if (fileUrl.isEmpty) {
      debugPrint('DOWNLOAD_ERROR: Empty file URL for $bookTitle');
      _showErrorMessage('Invalid download link for: $bookTitle');
      return;
    }

    if (_cachedStorageDirectory == null) {
      debugPrint('DOWNLOAD_ERROR: Storage directory not available');
      _showErrorMessage('Storage not accessible');
      return;
    }

    // Update UI to show download in progress
    _setDownloadState(bookTitle, DownloadState.downloading);

    try {
      final fileName = _generateFileName(bookTitle);
      await _prepareDownloadFile(fileName);
      
      final taskId = await _enqueueDownload(fileUrl, fileName);
      
      if (taskId != null) {
        _registerDownloadTask(bookTitle, taskId);
        _startDownloadMonitoring(bookTitle, taskId);
      } else {
        throw Exception('Failed to enqueue download');
      }
    } catch (e) {
      debugPrint('DOWNLOAD_ERROR: Failed to start download for $bookTitle: $e');
      _setDownloadState(bookTitle, DownloadState.initial);
      _showErrorMessage('Failed to start download: $bookTitle');
    }
  }

  /// Updates the download state for a specific book
  void _setDownloadState(String bookTitle, DownloadState state) {
    if (mounted) {
      setState(() {
        _downloadStates[bookTitle] = state;
      });
    }
  }

  /// Generates a filename for the downloaded book
  String _generateFileName(String bookTitle) {
    return '$bookTitle.${widget.fileType}';
  }

  /// Prepares the download file by removing existing files to prevent conflicts
  Future<void> _prepareDownloadFile(String fileName) async {
    final filePath = path.join(_cachedStorageDirectory!.path, fileName);
    final file = File(filePath);
    
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Enqueues the download task with flutter_downloader
  Future<String?> _enqueueDownload(String fileUrl, String fileName) async {
    debugPrint('DOWNLOAD_INFO: Starting download from: $fileUrl');
    
    return await FlutterDownloader.enqueue(
      url: fileUrl,
      savedDir: _cachedStorageDirectory!.path,
      fileName: fileName,
      showNotification: true,
      openFileFromNotification: true,
      saveInPublicStorage: false,
    );
  }

  /// Registers the download task for tracking
  void _registerDownloadTask(String bookTitle, String taskId) {
    _bookTitleToTaskId[bookTitle] = taskId;
    _taskIdToBookTitle[taskId] = bookTitle;
    debugPrint('DOWNLOAD_REGISTERED: $bookTitle -> $taskId');
  }

  /// Starts monitoring the download progress with a fallback timer
  void _startDownloadMonitoring(String bookTitle, String taskId) {
    _startDownloadCheckTimer(bookTitle, taskId);
  }

  // === FALLBACK DOWNLOAD MONITORING ===

  /// Starts a periodic timer to check download status as a fallback mechanism
  /// This ensures downloads are tracked even if the callback fails
  void _startDownloadCheckTimer(String bookTitle, String taskId) {
    _downloadCheckTimer?.cancel(); // Cancel any existing timer
    
    _downloadCheckTimer = Timer.periodic(
      const Duration(seconds: 3), // Check every 3 seconds
      (timer) => _checkDownloadProgress(timer, bookTitle, taskId),
    );
  }

  /// Checks download progress and updates UI accordingly
  Future<void> _checkDownloadProgress(Timer timer, String bookTitle, String taskId) async {
    try {
      final task = await _findDownloadTask(taskId);
      
      if (task == null) {
        // Task not found, check if file exists
        timer.cancel();
        await _checkFileExistence(bookTitle);
        return;
      }

      
      if (task.status == DownloadTaskStatus.complete) {
        timer.cancel();
        _handleTimerDownloadComplete(bookTitle, taskId);
      } else if (task.status == DownloadTaskStatus.failed || 
                 task.status == DownloadTaskStatus.canceled) {
        timer.cancel();
        _handleTimerDownloadFailed(bookTitle, taskId);
      }
    } catch (e) {
      debugPrint('TIMER_ERROR: Error checking download status: $e');
      timer.cancel();
      await _checkFileExistence(bookTitle);
    }
  }

  /// Finds a download task by its ID
  Future<DownloadTask?> _findDownloadTask(String taskId) async {
    final tasks = await FlutterDownloader.loadTasks();
    return tasks?.cast<DownloadTask?>().firstWhere(
      (task) => task?.taskId == taskId,
      orElse: () => null,
    );
  }

  /// Handles download completion detected by timer
  void _handleTimerDownloadComplete(String bookTitle, String taskId) {
    if (mounted) {
      setState(() {
        _downloadStates[bookTitle] = DownloadState.completed;
        _cleanupTaskMappings(bookTitle, taskId);
      });
    }
    debugPrint('TIMER_SUCCESS: $bookTitle download completed via timer check');
  }

  /// Handles download failure detected by timer
  void _handleTimerDownloadFailed(String bookTitle, String taskId) {
    if (mounted) {
      setState(() {
        _downloadStates[bookTitle] = DownloadState.initial;
        _cleanupTaskMappings(bookTitle, taskId);
      });
      _showErrorMessage('Download failed for: $bookTitle');
    }
    debugPrint('TIMER_FAILED: $bookTitle download failed via timer check');
  }

  // === FILE OPERATIONS ===

  /// Checks if a file exists in storage and updates state accordingly
  Future<void> _checkFileExistence(String bookTitle) async {
    if (_cachedStorageDirectory == null || !mounted) return;

    try {
      final isDownloaded = await _isBookDownloaded(bookTitle);
      
      setState(() {
        _downloadStates[bookTitle] = isDownloaded 
            ? DownloadState.completed 
            : DownloadState.initial;
      });
      
      debugPrint('FILE_CHECK: $bookTitle ${isDownloaded ? 'exists' : 'not found'}');
    } catch (e) {
      debugPrint('FILE_CHECK_ERROR: Error checking file existence: $e');
    }
  }

  /// Checks if a book file exists in storage
  Future<bool> _isBookDownloaded(String bookTitle) async {
    if (_cachedStorageDirectory == null) return false;
    
    final fileName = _generateFileName(bookTitle);
    final filePath = path.join(_cachedStorageDirectory!.path, fileName);
    return File(filePath).exists();
  }

  /// Opens a downloaded book file using the default system app
  Future<void> _openFile(String bookTitle) async {
    if (_cachedStorageDirectory == null) {
      _showErrorMessage('Storage not accessible');
      return;
    }

    try {
      final fileName = _generateFileName(bookTitle);
      final filePath = path.join(_cachedStorageDirectory!.path, fileName);

      // Verify file exists before attempting to open
      if (!await File(filePath).exists()) {
        debugPrint('OPEN_FILE_ERROR: File does not exist: $filePath');
        _setDownloadState(bookTitle, DownloadState.initial);
        _showErrorMessage('File not found. Please download again.');
        return;
      }

      final result = await OpenFilex.open(filePath);
      debugPrint('OPEN_FILE_RESULT: ${result.message}, Type: ${result.type}');

      if (result.type != ResultType.done) {
        _showErrorMessage('Cannot open file: ${result.message}');
      }
    } catch (e) {
      debugPrint('OPEN_FILE_ERROR: Error opening file: $e');
      _showErrorMessage('Error opening file');
    }
  }

  // === UI HELPER METHODS ===

  /// Shows a success message to the user
  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded: $message'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Shows an error message to the user
  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Shows a dialog informing the user that upload is disabled
  void _showUploadDisabledDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Upload Disabled'),
          content: const Text('The option to upload books is currently disabled.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // === DATA HELPERS ===

  /// Extracts book title from Firestore document data
  String _extractBookTitle(Map<String, dynamic> data) {
    return (data['Title'] as String?) ?? 'Unknown Title';
  }

  /// Extracts file URL from Firestore document data
  String _extractFileUrl(Map<String, dynamic> data) {
    return (data['linkURL'] as String?) ?? '';
  }

  /// Creates a stream to fetch book data from Firestore
  Stream<List<Map<String, dynamic>>> _getBooksStream() {
    return FirebaseFirestore.instance
        .collection('ChildrenBooksLinks')
        .where('age_range', isEqualTo: widget.ageRange)
        .where('file_type', isEqualTo: widget.fileType)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // === CLEANUP ===

  /// Cleans up resources when the widget is disposed
  void _cleanupResources() {
    downloadUpdateNotifier.removeListener(_onDownloadUpdate);
    _downloadCheckTimer?.cancel();
  }

  // === BUILD METHOD ===

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.ageRange} ${widget.fileType.toUpperCase()} Books'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(child: _buildBooksList()),
          _buildUploadButton(),
        ],
      ),
    );
  }

  /// Builds the main books list widget
  Widget _buildBooksList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getBooksStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}), // Trigger rebuild
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.book_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No books found for this category.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return _buildBooksListView(snapshot.data!);
      },
    );
  }

  /// Builds the ListView containing all books
  Widget _buildBooksListView(List<Map<String, dynamic>> books) {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: books.length,
      itemBuilder: (context, index) => _buildBookCard(books[index]),
    );
  }

  /// Builds a card widget for a single book
  Widget _buildBookCard(Map<String, dynamic> book) {
    final bookTitle = _extractBookTitle(book);
    final fileUrl = _extractFileUrl(book);
    final downloadState = _downloadStates[bookTitle] ?? DownloadState.initial;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      elevation: 2,
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
            const SizedBox(width: 16),
            DownloadButton(
              downloadState: downloadState,
              onPressed: () => _handleBookAction(downloadState, bookTitle, fileUrl),
            ),
          ],
        ),
      ),
    );
  }

  /// Handles button press for book actions (download/open)
  void _handleBookAction(DownloadState state, String bookTitle, String fileUrl) {
    switch (state) {
      case DownloadState.initial:
        _startDownload(bookTitle, fileUrl);
        break;
      case DownloadState.completed:
        _openFile(bookTitle);
        break;
      case DownloadState.downloading:
        // Do nothing while downloading
        break;
    }
  }

  /// Builds the upload button at the bottom of the screen
  Widget _buildUploadButton() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _showUploadDisabledDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 242, 92, 110),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 2,
          ),
          child: const Text(
            'Upload Book',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom widget for the download/open button with animated state changes
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
      child: _buildButtonForState(),
    );
  }

  /// Builds the appropriate button widget based on download state
  Widget _buildButtonForState() {
    switch (downloadState) {
      case DownloadState.initial:
        return _buildActionButton('GET', const Color.fromARGB(255, 9, 131, 230), onPressed);
      case DownloadState.downloading:
        return _buildLoadingIndicator();
      case DownloadState.completed:
        return _buildActionButton('OPEN', const Color.fromARGB(255, 11, 135, 15), onPressed);
    }
  }

  /// Builds a loading indicator for the downloading state
  Widget _buildLoadingIndicator() {
    return const SizedBox(
      width: 32,
      height: 32,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 9, 131, 230)),
      ),
    );
  }

  /// Builds an action button (GET/OPEN) with the specified color and callback
  Widget _buildActionButton(String text, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      key: ValueKey(text), // Important for AnimatedSwitcher
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: const Size(60, 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}