import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file_plus/open_file_plus.dart';


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

  @override
  void initState() {
    super.initState();
    // Remove FlutterDownloader.registerCallback(downloadCallback); from here.
    // It's now handled globally in main.dart.
  }

  @override
  void dispose() {
    // No need for removeCallback, as it's removed from API.
    super.dispose();
  }


  Future<void> _startDownload(String bookTitle, String fileUrl) async {
    setState(() {
      _downloadStates[bookTitle] = DownloadState.downloading;
    });

    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw Exception("Could not get external storage directory.");
      }
      final savedDir = directory.path;

      String extension = widget.fileType == 'word' ? 'docx' : 'pdf';
      final cleanFileName = bookTitle.replaceAll(RegExp(r'[^\w\s.-]'), '').trim();
      final fileName = '$cleanFileName.$extension';


      final taskId = await FlutterDownloader.enqueue(
        url: fileUrl,
        savedDir: savedDir,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: true,
      );

      if (taskId != null) {
        if (mounted) {
           setState(() {
            _downloadStates[bookTitle] = DownloadState.completed;
          });
        }
      } else {
         if (mounted) {
           setState(() {
            _downloadStates[bookTitle] = DownloadState.initial;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to start download.')),
          );
         }
      }


    } catch (e) {
      print('Download error: $e');
      if (mounted) {
        setState(() {
          _downloadStates[bookTitle] = DownloadState.initial;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ages ${widget.ageRange} ${widget.fileType.toUpperCase()} Books'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Image.network(
              widget.fileType == 'word'
                  ? 'https://img.icons8.com/color/48/000000/word.png'
                  : 'https://cdn-icons-png.flaticon.com/512/337/337946.png', // PDF
              height: 36,
              width: 36,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('ChildrenBooksLinks')
                  .where('age_range', isEqualTo: widget.ageRange)
                  .where('file_type', isEqualTo: widget.fileType)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No books found for this category.'));
                }

                final books = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: books.length,
                  itemBuilder: (context, index) {
                    final bookData = books[index].data() as Map<String, dynamic>;
                    final bookTitle = bookData['Title'] as String? ?? 'Unknown Title';
                    final bookLinkUrl = bookData['linkURL'] as String? ?? '';

                    _downloadStates.putIfAbsent(bookTitle, () => DownloadState.initial);

                    return BookListItem(
                      title: bookTitle,
                      icon: Icons.menu_book,
                      downloadState: _downloadStates[bookTitle]!,
                      onTap: () async {
                        if (_downloadStates[bookTitle] == DownloadState.initial) {
                          _startDownload(bookTitle, bookLinkUrl);
                        } else if (_downloadStates[bookTitle] == DownloadState.completed) {
                          final directory = await getExternalStorageDirectory();
                          if (directory != null) {
                            String extension = widget.fileType == 'word' ? 'docx' : 'pdf';
                            final cleanFileName = bookTitle.replaceAll(RegExp(r'[^\w\s.-]'), '').trim();
                            final filePath = '${directory.path}/$cleanFileName.$extension';
                            OpenFilePlus.open(filePath);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Could not access storage to open file.')),
                            );
                          }
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Upload book functionality not implemented yet.')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 242, 92, 110),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Upload Book',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

enum DownloadState { initial, downloading, completed }

class BookListItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final DownloadState downloadState;
  final VoidCallback onTap;

  const BookListItem({
    super.key,
    required this.title,
    required this.icon,
    required this.downloadState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Card(
        elevation: 2,
        child: ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.red.shade100,
            child: Icon(icon, size: 30, color: Colors.red),
          ),
          title: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          trailing: DownloadButton(
            downloadState: downloadState,
            onPressed: onTap,
          ),
        ),
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
      key: ValueKey(text),
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
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }
}