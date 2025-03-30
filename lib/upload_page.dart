import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'theme_constants.dart'; // Import the theme constants

var logger = Logger();

class UploadPage extends StatefulWidget {
  const UploadPage({Key? key}) : super(key: key);

  @override
  _UploadPageState createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  List<PlatformFile> _selectedFiles = [];
  bool _isLoading = false;

  /// Clears the database and deletes uploaded resumes
  Future<void> _resetDatabase() async {
    try {
      var response =
          await http.delete(Uri.parse('http://192.168.1.75:5000/reset/'));
      if (response.statusCode == 200) {
        logger.i("Database reset successfully.");
      } else {
        logger.e("Failed to reset database: ${response.body}");
      }
    } catch (e) {
      logger.e("Error while resetting database: $e");
    }
  }

  /// Picks files after clearing database
  Future<void> _browseFiles() async {
    setState(() => _isLoading = true);

    await _resetDatabase();

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: kIsWeb,
    );

    if (result != null) {
      setState(() {
        _selectedFiles = result.files;
      });
    }

    setState(() => _isLoading = false);
  }

  Future<bool> _uploadResumes() async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://192.168.1.75:5000/upload/'),
    );

    for (var file in _selectedFiles) {
      if (kIsWeb) {
        if (file.bytes != null) {
          request.files.add(http.MultipartFile.fromBytes(
            'files',
            file.bytes!,
            filename: file.name,
          ));
        }
      } else {
        if (file.path != null) {
          request.files.add(await http.MultipartFile.fromPath(
            'files',
            file.path!,
          ));
        }
      }
    }

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      logger.i("Response Status Code: ${response.statusCode}");
      logger.i("Response Body: ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      logger.e("Error uploading files: $e");
      return false;
    }
  }

  Future<void> _submitUpload() async {
    if (_selectedFiles.isNotEmpty) {
      setState(() => _isLoading = true);
      final uploadSuccess = await _uploadResumes();
      if (uploadSuccess) {
        Navigator.pushNamed(context, '/criteria');
      } else {
        _showErrorSnackBar('Resume upload failed. Check logs.');
      }
      setState(() => _isLoading = false);
    } else {
      _showErrorSnackBar('Please select resumes to upload.');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          title: const Text(
            "Upload Resumes",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary, // Change font color to #161926
            ),
          ),
          backgroundColor: Colors.transparent, // Remove background color
          centerTitle: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Upload Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(30.0),
                    decoration: AppTheme.cardDecoration,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: AppTheme.accentGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.upload_file_rounded,
                            size: 40,
                            color: AppTheme.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Upload Resumes",
                          style: AppTheme.headingMedium,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Select PDF resumes to analyze",
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 25),

                        // Browse Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: AppTheme.secondaryButtonStyle,
                            onPressed: _browseFiles,
                            child: const Text(
                              'Browse Files',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        _selectedFiles.isNotEmpty
                            ? Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  // ignore: deprecated_member_use
                                  color:
                                      // ignore: deprecated_member_use
                                      AppTheme.backgroundLight.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '${_selectedFiles.length} resumes selected',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Upload & Next Button
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.accentPrimary,
                            ),
                          )
                        : ElevatedButton(
                            style: AppTheme.primaryButtonStyle,
                            onPressed: _submitUpload,
                            child: const Text(
                              'Upload & Continue',
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
}
