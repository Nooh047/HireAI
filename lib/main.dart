import 'package:flutter/material.dart';
import 'upload_page.dart';
import 'criteria_page.dart';
import 'result_page.dart';
import 'home_screen.dart'; // Importing the new landing page

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HireAI',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/home', // Updated initial route to HomeScreen
      routes: {
        '/home': (context) => const HomeScreen(),
        '/upload': (context) => const UploadPage(),
        '/criteria': (context) => const CriteriaPage(),
        '/result': (context) => const ResultPage(),
      },
    );
  }
}