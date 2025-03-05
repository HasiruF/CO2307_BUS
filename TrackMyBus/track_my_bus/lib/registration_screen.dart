import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:email_validator/email_validator.dart';
import 'home_screen.dart';

class RegistrationScreen extends StatefulWidget {
  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  List<String> _deviceEmails = [];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void initState() {
    super.initState();
    _fetchDeviceEmails();
  }

  /// Fetch email addresses signed in on the device
  Future<void> _fetchDeviceEmails() async {
    try {
      // Fetch Google signed-in accounts
      List<GoogleSignInAccount?> googleAccounts = await Future.wait([
        _googleSignIn.signInSilently(),
        // Add other account types if needed
      ]);

      // Filter out null accounts and extract emails
      setState(() {
        _deviceEmails = googleAccounts
            .where((account) => account != null)
            .map((account) => account!.email)
            .toList();
      });

      print("Fetched device emails: $_deviceEmails");
    } catch (e) {
      print("Error fetching device emails: $e");
    }
  }

  /// Comprehensive email validation
  Future<bool> _validateEmail(String email) async {
    // Basic format validation
    if (!EmailValidator.validate(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid email format')),
      );
      return false;
    }

    // Predefined list of known email providers
    final validDomains = [
      'gmail.com',
      'yahoo.com',
      'hotmail.com',
      'outlook.com',
      'icloud.com',
      'protonmail.com',
      'aol.com',
      'zoho.com'
    ];

    // Extract domain from email
    String domain = email.split('@').last.toLowerCase();

    // Check if domain is in the list of valid domains
    if (!validDomains.contains(domain)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Email address from an unregistered provider. Please use a valid email provider.'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    try {
      // Fetch sign-in methods for the email
      var signInMethods = await _auth.fetchSignInMethodsForEmail(email);

      // If any sign-in method exists, the email is already in use
      if (signInMethods.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email is already registered')),
        );
        return false;
      }

      return true;
    } catch (e) {
      print("Email validation error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error validating email')),
      );
      return false;
    }
  }

  /// Register the user and send verification email
  Future<void> _register() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      String email = _emailController.text.trim();
      String password = _passwordController.text.trim();

      try {
        // Validate email first
        bool isValidEmail = await _validateEmail(email);
        if (!isValidEmail) {
          setState(() => _isLoading = false);
          return;
        }

        // Create user
        UserCredential userCredential =
            await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        User? user = userCredential.user;

        if (user != null) {
          // Send verification email
          await user.sendEmailVerification();

          // Store user details in Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'username': _usernameController.text.trim(),
            'email': email,
            'phone': _phoneController.text.trim(),
            'usertype': "Client",
            'verified': false,
          });

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification email sent! Please verify.')),
          );
        }
      } on FirebaseAuthException catch (e) {
        // Handle specific Firebase authentication errors
        String errorMessage = 'Registration failed';

        if (e.code == 'email-already-in-use') {
          errorMessage = 'Email is already registered';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'Invalid email address';
        } else if (e.code == 'weak-password') {
          errorMessage = 'Password is too weak';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      } catch (e) {
        // Handle any unexpected errors
        print('Unexpected registration error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred')),
        );
      } finally {
        // Ensure loading state is turned off
        setState(() => _isLoading = false);
      }
    }
  }

  /// Check email verification status
  Future<void> _checkEmailVerification() async {
    User? user = _auth.currentUser;
    await user?.reload();

    if (user != null && user.emailVerified) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'verified': true});

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage(userId: user.uid)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please verify your email before continuing.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: 'Username'),
                validator: (value) =>
                    value!.isEmpty ? 'Enter a username' : null,
              ),
              SizedBox(height: 10),
              // Device Emails Dropdown
              if (_deviceEmails.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select from your device emails:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      hint: Text('Choose an email from this device'),
                      items: _deviceEmails.map((email) {
                        return DropdownMenuItem(
                          value: email,
                          child: Text(
                            email,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (selectedEmail) {
                        if (selectedEmail != null) {
                          setState(() {
                            _emailController.text = selectedEmail;
                          });
                        }
                      },
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Or enter a new email:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),

              // Manual Email Entry
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: _deviceEmails.isEmpty
                      ? 'Enter email'
                      : 'Alternative email',
                ),
                validator: (value) => value!.isEmpty ? 'Enter an email' : null,
              ),

              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Password'),
                validator: (value) => value!.length < 6
                    ? 'Password must be at least 6 characters'
                    : null,
              ),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                validator: (value) =>
                    value!.isEmpty ? 'Enter a phone number' : null,
              ),
              SizedBox(height: 20),
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _register,
                      child: Text('Register'),
                    ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: _checkEmailVerification,
                child: Text('Check Email Verification'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Dispose controllers to prevent memory leaks
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
