// second_menu_screen.dart
// Secondary menu screen providing additional navigation options
// Currently serves as a placeholder for future functionality expansion

import 'package:flutter/material.dart';

/// Secondary menu screen widget
class SecondMenuScreen extends StatelessWidget {
  const SecondMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // App bar with back navigation
      appBar: AppBar(
        title: const Text(
          'Additional Menu',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 2,
        // Custom back button with explicit navigation
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Go back to main menu',
          onPressed: () => Navigator.pop(context),
        ),
      ),

      // Main content area
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Placeholder icon
            const Icon(
              Icons.construction,
              size: 80,
              color: Color(0xFFE36565),
            ),
            
            const SizedBox(height: 24),
            
            // Main message
            const Text(
              'Additional Features',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF421D1D),
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            
            // Descriptive text
            const Text(
              'This area is reserved for future functionality.\n\n'
              'Potential features could include:\n'
              '• App settings and preferences\n'
              '• Reading progress tracking\n'
              '• Favorite books management\n'
              '• User profile settings\n'
              '• Help and support information',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF666666),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 40),
            
            // Action button to return to main screen
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.home),
              label: const Text(
                'Return to Main Menu',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF25C6E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}