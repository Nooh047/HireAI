import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'theme_constants.dart'; // Import the theme constants

class CriteriaPage extends StatefulWidget {
  const CriteriaPage({Key? key}) : super(key: key);

  @override
  _CriteriaPageState createState() => _CriteriaPageState();
}

class _CriteriaPageState extends State<CriteriaPage> {
  final _formKey = GlobalKey<FormState>();
  final _qualificationController = TextEditingController();
  final _skillController = TextEditingController();
  final _experienceController = TextEditingController();
  final _resumesSelectedController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _qualificationController.dispose();
    _skillController.dispose();
    _experienceController.dispose();
    _resumesSelectedController.dispose();
    super.dispose();
  }

  Future<void> _rankResumes() async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.75:5000/rank/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'qualification': _qualificationController.text.trim(),
          'skills': _skillController.text.trim(),
          'experience': int.parse(_experienceController.text),
          'resumes_selected': int.parse(_resumesSelectedController.text),
        }),
      );

      if (response.statusCode == 200) {
        Navigator.pushNamed(
          context,
          '/result',
          arguments: json.decode(response.body),
        );
      } else {
        String errorMessage = 'Failed to rank resumes';
        try {
          errorMessage = json.decode(response.body)['detail'] ?? errorMessage;
        } catch (_) {}
        _showErrorSnackBar(errorMessage);
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
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

  Future<void> _submitCriteria() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      await _rankResumes();
      setState(() => _isLoading = false);
    }
  }

  String? _validateQualifications(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter qualification';
    }
    if (!RegExp(r'^[A-Za-z\s]+(,[A-Za-z\s]+)*$').hasMatch(value.trim())) {
      return 'Enter valid qualifications (letters & spaces only)';
    }
    return null;
  }

  String? _validateSkills(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter skills';
    }
    if (!RegExp(r'^[A-Za-z\s]+(,[A-Za-z\s]+)*$').hasMatch(value.trim())) {
      return 'Enter valid skills (letters & spaces only)';
    }
    return null;
  }

  String? _validateExperience(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter experience';
    }
    if (!RegExp(r'^\d+$').hasMatch(value.trim())) {
      return 'Enter a valid number';
    }
    return null;
  }

  String? _validateResumesSelected(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter number of resumes';
    }
    if (!RegExp(r'^\d+$').hasMatch(value.trim())) {
      return 'Enter a valid number';
    }
    return null;
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
          title: const Text(
            "Resume Preview",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF161926), // Updated text color
            ),
          ),
          backgroundColor: Colors.transparent, // Remove background color
          elevation: 0, // Removes shadow
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.accentPrimary,
                ),
              )
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: AppTheme.cardDecoration,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Define Your Ideal Candidate",
                              style: AppTheme.headingMedium,
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              "Specify the criteria to rank resumes",
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 25),
                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildStyledTextField(
                                    controller: _qualificationController,
                                    label: 'Qualifications (comma-separated)',
                                    icon: Icons.school_rounded,
                                    validator: _validateQualifications,
                                  ),
                                  _buildStyledTextField(
                                    controller: _skillController,
                                    label: 'Skills (comma-separated)',
                                    icon: Icons.psychology_rounded,
                                    validator: _validateSkills,
                                  ),
                                  _buildStyledTextField(
                                    controller: _experienceController,
                                    label: 'Experience (years)',
                                    icon: Icons.work_history_rounded,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    validator: _validateExperience,
                                  ),
                                  _buildStyledTextField(
                                    controller: _resumesSelectedController,
                                    label: 'Number of Resumes to Select',
                                    icon: Icons.people_rounded,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    validator: _validateResumesSelected,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        child: ElevatedButton(
                          style: AppTheme.primaryButtonStyle,
                          onPressed: _submitCriteria,
                          child: const Text(
                            'Rank Resumes',
                            style: TextStyle(
                              color: Color(0xFFFFFFFF), // Updated text color
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
          prefixIcon: Icon(icon, color: AppTheme.accentPrimary),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15.0),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15.0),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15.0),
            borderSide:
                const BorderSide(color: AppTheme.accentPrimary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15.0),
            borderSide: const BorderSide(color: Colors.red, width: 1.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15.0),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
          errorStyle: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}
