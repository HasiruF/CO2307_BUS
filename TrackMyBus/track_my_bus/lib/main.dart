import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'registration_screen.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If the user is logged in
        if (snapshot.hasData && snapshot.data != null) {
          return HomePage(userId: snapshot.data!.uid);
        }
        // If not logged in
        return LoginPage();
      },
    );
  }
  
}