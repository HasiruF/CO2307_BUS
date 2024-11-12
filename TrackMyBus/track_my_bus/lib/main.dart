import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'registration_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Staff Bus App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: RegistrationScreen(),  // Change this to RegistrationScreen for initial testing
    );
  }
}