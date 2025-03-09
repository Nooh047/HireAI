import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class ResumePreviewPage extends StatefulWidget {
  final int resumeId;

  const ResumePreviewPage({Key? key, required this.resumeId}) : super(key: key);

  @override
  _ResumePreviewPageState createState() => _ResumePreviewPageState();
}

class _ResumePreviewPageState extends State<ResumePreviewPage> {
  String? localFilePath;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAndSaveResume();
  }

  Future<void> _fetchAndSaveResume() async {
    try {
      final url = "http://127.0.0.1:5000/resume/${widget.resumeId}";
      final response = await http.get(Uri.parse(url));

      debugPrint("Response Status Code: ${response.statusCode}");
      debugPrint("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File("${dir.path}/resume_${widget.resumeId}.pdf");
        await file.writeAsBytes(response.bodyBytes);
        setState(() {
          localFilePath = file.path;
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load resume");
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      debugPrint("Error loading resume: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Resume Preview",
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF3D52A0),
      ),
      backgroundColor: const Color(0xFFEDE8F5),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : localFilePath == null
              ? const Center(
                  child: Text(
                    "Failed to load resume",
                    style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFF2C3E50),
                        fontWeight: FontWeight.bold),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: PDFView(filePath: localFilePath!),
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
                          IconButton(
                            icon:
                                const Icon(Icons.download, color: Colors.black),
                            onPressed: () {
                              // Implement download functionality
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
