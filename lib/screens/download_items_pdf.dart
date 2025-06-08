import 'package:flutter/material.dart';

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
  final List<DownloadState> _downloadStates =
      List.generate(2, (index) => DownloadState.initial);

  void _startDownload(int index) {
    setState(() {
      _downloadStates[index] = DownloadState.downloading;
    });

    Future.delayed(const Duration(seconds: 2)).then((_) {
      if (!mounted) return;
      setState(() {
        _downloadStates[index] = DownloadState.completed;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ages ${widget.ageRange}'),
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
            child: ListView.builder(
              itemCount: 2,
              itemBuilder: (context, index) {
                return BookListItem(
                  title: 'Book ${index + 1}',
                  icon: Icons.ac_unit,
                  downloadState: _downloadStates[index],
                  onTap: () {
                    if (_downloadStates[index] == DownloadState.initial) {
                      _startDownload(index);
                    }
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
                onPressed: () {},
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
        DownloadState.completed => _buildButton('OPEN', () {}),
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
