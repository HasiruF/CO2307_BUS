import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';

class RegistrationScreen extends StatefulWidget {
  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  
  // Form key to validate the form fields
  final _formKey = GlobalKey<FormState>();

  // Function to handle registration
  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Register with Firebase
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // If registration is successful, show a success message
        Fluttertoast.showToast(msg: "Registration successful!", toastLength: Toast.LENGTH_SHORT);
        Navigator.pushReplacementNamed(context, '/home'); // Navigate to the home page (or next screen)

      } catch (e) {
        // Handle any errors during registration
        Fluttertoast.showToast(msg: e.toString(), toastLength: Toast.LENGTH_SHORT);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Register'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Email input field
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an email';
                  }
                  return null;
                },
              ),
              
              // Password input field
              TextFormField(
                controller: _passwordController,
                obscureText: true, // hides the password 
                decoration: InputDecoration(labelText: 'Password'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              
              // Register button
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _register, // Call the _register function when pressed
                child: Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}