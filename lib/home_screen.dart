import 'package:flutter/material.dart';
import 'theme_constants.dart'; // Import the theme constants

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0, // Remove shadow
          backgroundColor: Colors.transparent, // Make header transparent
          title: const Text(
            "",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary, // Change text color to dark navy
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo or Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Icon(
                      Icons.work_rounded,
                      size: 50,
                      color: AppTheme.white,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Title
                  const Text(
                    'HireAI',
                    style: AppTheme.headingLarge,
                  ),
                  const SizedBox(height: 10),

                  // Subtitle
                  const Text(
                    'Intelligent Resume Analysis',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 50),

                  // Get Started Button
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    child: ElevatedButton(
                      style: AppTheme.primaryButtonStyle,
                      onPressed: () {
                        Navigator.pushNamed(context, '/upload');
                      },
                      child: const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Learn More Button
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    child: ElevatedButton(
                      style: AppTheme.secondaryButtonStyle,
                      onPressed: () {
                        _showHowToUseDialog(context);
                      },
                      child: const Text(
                        'Learn More',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Dialog for "Learn More"
  void _showHowToUseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'How to Use HireAI',
                  style: AppTheme.headingMedium,
                ),
                const SizedBox(height: 20),
                const SingleChildScrollView(
                  child: Text(
                    'Step 1: Launch & Get Started\n'
                    'Tap "Get Started" to begin your hiring journey!\n\n'
                    'Step 2: Upload Resumes\n'
                    'Select PDF resumes for AI analysis.\n\n'
                    'Step 3: Set Hiring Criteria\n'
                    'Define skills, experience, and qualifications.\n\n'
                    'Step 4: View the Top Candidates\n'
                    'See the best-matching resumes ranked for you.\n\n'
                    'Step 5: Hire Like a Pro!\n'
                    'Shortlist and contact the best candidates!',
                    style: AppTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          color: AppTheme.accentPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
