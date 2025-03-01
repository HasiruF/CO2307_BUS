import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart'; 
import 'registration_screen.dart';
import 'home_screen.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> _updateUserLocation(String userId) async {
    try {
      // Check if location permission is granted
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        // Request permission if not granted
        permission = await Geolocator.requestPermission();
      }
      // Get current location
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      // Get Firestore instance
      FirebaseFirestore firestore = FirebaseFirestore.instance;

      // Update the location field for the user
      await firestore.collection('users').doc(userId).update({
        'location': GeoPoint(position.latitude, position.longitude), // Set the location as GeoPoint
      });

      print('User location updated');
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  void _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        // Authenticate with Firebase
        UserCredential userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
                email: _usernameController.text.trim(),
                password: _passwordController.text.trim());

        print('Login successful: ${userCredential.user?.email}');
        String userEmail = userCredential.user!.email!;

        // Update the user's location in Firestore
        await _updateUserLocation(userCredential.user!.uid);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(userId: userCredential.user!.uid),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login successful')),
        );
      } catch (e) {
        // Error if login fails
        print('Error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: 'UserEmail'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a Email';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Password'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _login,
                child: Text('Login'),
              ),
              SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  // Navigate to the Registration Page
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RegistrationScreen()),
                  );
                },
                child: Text('Go to Registration Page'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
