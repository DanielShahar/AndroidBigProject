import 'package:flutter/material.dart';
import 'second_menu_screen.dart';
import 'download_items_pdf.dart';


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
