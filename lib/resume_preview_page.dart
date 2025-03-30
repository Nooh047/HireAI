import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class ResumePreviewPage extends StatefulWidget {
  final int resumeId; // Resume ID passed dynamically

  const ResumePreviewPage({Key? key, required this.resumeId}) : super(key: key);

  @override
  _ResumePreviewPageState createState() => _ResumePreviewPageState();
}

class _ResumePreviewPageState extends State<ResumePreviewPage> {
  String? localFilePath; // Stores the path to the downloaded PDF
  bool isLoading = false; // Tracks whether the resume is being fetched

  // Function to fetch and save the resume from the backend
  Future<void> _fetchAndSaveResume() async {
    try {
      setState(() {
        isLoading = true; // Show loading indicator
      });

      // Replace with your FastAPI endpoint
      final url = "http://192.168.1.75:5000/resume/${widget.resumeId}";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // Save the PDF to a temporary location
        final dir = await getTemporaryDirectory();
        final file = File("${dir.path}/resume_${widget.resumeId}.pdf");
        await file.writeAsBytes(response.bodyBytes);

        setState(() {
          localFilePath = file.path; // Set file path
        });
      } else {
        throw Exception("Failed to fetch resume");
      }
    } catch (e) {
      debugPrint("Error fetching resume: $e");
      setState(() {
        localFilePath = null; // Reset file path on error
      });
    } finally {
      setState(() {
        isLoading = false; // Hide loading indicator
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Resume Preview",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF3D52A0),
      ),
      backgroundColor: const Color(0xFFEDE8F5),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (localFilePath != null)
            Expanded(
              child:
                  PDFView(filePath: localFilePath!), // Renders the fetched PDF
            )
          else
            const Center(
              child: Text(
                "Press 'Preview' to fetch resume",
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF2C3E50),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close, color: Colors.black),
                  label: const Text(
                    "Close",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await _fetchAndSaveResume(); // Trigger fetching resume
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF3D52A0),
                  ),
                  child: const Text(
                    "Preview",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
