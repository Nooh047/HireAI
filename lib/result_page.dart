import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart'; // Import the permission_handler package
import 'theme_constants.dart'; // Import the theme constants

class ResultPage extends StatelessWidget {
  const ResultPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final rankedResults =
        ModalRoute.of(context)?.settings.arguments as List<dynamic>? ?? [];

    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.backgroundGradient, // Apply theme gradient
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          title: const Text(
            'Ranked Resumes',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary, // Use theme primary text color
            ),
          ),
          backgroundColor: Colors.transparent, // Remove header color
          centerTitle: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
        ),
        body: rankedResults.isNotEmpty
            ? ListView.separated(
                padding: const EdgeInsets.all(16.0),
                itemCount: rankedResults.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final candidate = rankedResults[index];

                  return Container(
                    decoration: AppTheme.cardDecoration, // Use theme card style
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      title: Text(
                        candidate['name'],
                        style: const TextStyle(
                          color: AppTheme.textPrimary, // Theme text color
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '''Phone: ${candidate['phone']}
Email: ${candidate['email']}
Score: ${candidate['score']}''',
                          style: const TextStyle(
                            color: AppTheme
                                .textSecondary, // Use theme secondary text color
                            fontSize: 14,
                          ),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              await _handlePermission(context, () {
                                return _openResumeFile(
                                    context, candidate['id']);
                              });
                            },
                            icon: const Icon(Icons.remove_red_eye,
                                color: AppTheme.textPrimary),
                            label: const Text(
                              "Preview",
                              style: TextStyle(color: AppTheme.textPrimary),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.download,
                                color: AppTheme.textPrimary),
                            onPressed: () async {
                              await _handlePermission(context, () {
                                return _downloadResume(context, candidate['id'],
                                    candidate['name']);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
            : const Center(
                child: Text(
                  'No ranked results available.',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
      ),
    );
  }

  /// Handles requesting permissions and executing the action if granted
  Future<void> _handlePermission(
      BuildContext context, Future<void> Function() action) async {
    if (await Permission.storage.request().isGranted) {
      // If permission is granted, perform the action
      await action();
    } else {
      // Show error message if permission is denied
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              "Storage permission is required to perform this action."),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _openResumeFile(BuildContext context, int resumeId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final File resumeFile = await _getResumeFile(resumeId);
      Navigator.pop(context);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PDFView(
            filePath: resumeFile.path,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: true,
            pageFling: true,
            pageSnap: true,
            defaultPage: 0,
            fitPolicy: FitPolicy.BOTH,
            preventLinkNavigation: false,
          ),
        ),
      );
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error opening resume: ${e.toString()}")),
      );
    }
  }

  Future<void> _downloadResume(
      BuildContext context, int resumeId, String candidateName) async {
    try {
      final String resumeUrl = "http://192.168.1.75:5000/resume/$resumeId";
      final response = await http.get(Uri.parse(resumeUrl));

      if (response.statusCode == 200) {
        // Get the Downloads folder
        final Directory downloadsDir =
            Directory("/storage/emulated/0/Download");

        // Ensure the directory exists
        if (!downloadsDir.existsSync()) {
          downloadsDir.createSync(recursive: true);
        }

        // Save the file in the Downloads folder
        final File file = File('${downloadsDir.path}/$candidateName.pdf');
        await file.writeAsBytes(response.bodyBytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Downloaded to: ${file.path}")),
        );
      } else {
        throw Exception('Failed to download resume');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Download failed: ${e.toString()}")),
      );
    }
  }

  Future<File> _getResumeFile(int resumeId) async {
    final String resumeUrl = "http://192.168.1.75:5000/resume/$resumeId";
    final response = await http.get(Uri.parse(resumeUrl));

    if (response.statusCode == 200) {
      final Directory tempDir = await getTemporaryDirectory();
      final File file = File('${tempDir.path}/resume_$resumeId.pdf');
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } else {
      throw Exception('Failed to load resume');
    }
  }
}
