import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  String _error = '';
  bool _isRegistering = false;

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        if (_isRegistering) {
          await _auth.registerWithEmailAndPassword(
            _emailController.text,
            _passwordController.text,
            _nameController.text,
          );
        } else {
          await _auth.signInWithEmailAndPassword(
            _emailController.text,
            _passwordController.text,
          );
        }
      } catch (e) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Icon(
                Icons.assignment,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              const Text(
                'Assignment Reminder',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Keep track of your assignments and collaborate with your classmates',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 48),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (_isRegistering) ...[
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        keyboardType: TextInputType.name,
                        textInputAction: TextInputAction.next,
                        autofocus: true,
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Enter your name' : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofocus: true,
                      autocorrect: false,
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Enter an email' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                      enableInteractiveSelection: false,
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submitForm(),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Enter a password' : null,
                    ),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: Text(_isRegistering ? 'Register' : 'Login'),
                    ),
                    const SizedBox(height: 16),
                    if (!_isRegistering)
                      TextButton(
                        onPressed: () async {
                          if (_emailController.text.isEmpty) {
                            setState(() {
                              _error = 'Please enter your email first';
                            });
                            return;
                          }
                          try {
                            await _auth.resetPassword(_emailController.text);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Password reset email sent!'),
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() {
                              _error = e.toString();
                            });
                          }
                        },
                        child: const Text('Forgot Password?'),
                      ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isRegistering = !_isRegistering;
                          _error = '';
                        });
                      },
                      child: Text(
                        _isRegistering
                            ? 'Already have an account? Login'
                            : 'Don\'t have an account? Register',
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ),
                    // const SizedBox(height: 24),
                    // OutlinedButton.icon(
                    //   onPressed: () async {
                    //     try {
                    //       await _auth.signInWithGoogle();
                    //     } catch (e) {
                    //       setState(() {
                    //         _error = 'Failed to sign in with Google';
                    //       });
                    //     }
                    //   },
                    //   icon: Image.network(
                    //     'https://www.google.com/favicon.ico',
                    //     height: 24.0,
                    //   ),
                    //   label: const Text('Continue with Google'),
                    //   style: OutlinedButton.styleFrom(
                    //     minimumSize: const Size.fromHeight(50),
                    //   ),
                    // ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
