import '../services/auth_service.dart';
//import 'package:firebase_auth/firebase_auth.dart';
//import 'main_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../utils/snackbar_utils.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';

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

  // Method to dismiss keyboard
  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

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
          // The error is already user-friendly from our auth service
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return GestureDetector(
      // Dismiss keyboard when tapping outside of text fields
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.translucent, // Allow taps to pass through to children
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withOpacity(0.95),
            ],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent, // Make scaffold transparent to show gradient
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  // Enhanced app icon with gradient container
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryColor.withOpacity(0.7),
                          primaryColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.assignment,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Enhanced app title with better typography
                  Text(
                    'Chrono',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Enhanced description text with better styling
                  Text(
                    'Keep track of your assignments and collaborate with your classmates',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Enhanced form with consistent modern styling
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (_isRegistering) ...[
                          _buildTextFormField(
                            controller: _nameController,
                            label: 'Full Name',
                            icon: Icons.person_rounded,
                            keyboardType: TextInputType.name,
                            validator: (value) => value?.isEmpty ?? true ? 'Enter your name' : null,
                          ),
                          const SizedBox(height: 16),
                        ],
                        _buildTextFormField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) => value?.isEmpty ?? true ? 'Enter an email' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextFormField(
                          controller: _passwordController,
                          label: 'Password',
                          icon: Icons.lock_rounded,
                          obscureText: true,
                          onFieldSubmitted: (_) => _submitForm(),
                          validator: (value) => value?.isEmpty ?? true ? 'Enter a password' : null,
                        ),
                        if (_error.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade100),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, size: 20, color: Colors.red.shade400),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _error,
                                    style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        // Enhanced primary action button with gradient
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                primaryColor,
                                primaryColor.withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _submitForm,
                              child: Center(
                                child: Text(
                                  _isRegistering ? 'Register' : 'Login',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
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
                                  SnackBarUtils.showAwesomeSnackBar(
                                    context: context,
                                    title: 'Success!',
                                    message: 'Password reset email sent! Check your inbox.',
                                    contentType: ContentType.success,
                                  );
                                }
                              } catch (e) {
                                setState(() {
                                  _error = e.toString();
                                });
                              }
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                            ),
                            child: Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        // Enhanced toggle button with better styling
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isRegistering = !_isRegistering;
                                _error = '';
                              });
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isRegistering ? Icons.login : Icons.person_add,
                                  size: 20,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isRegistering
                                      ? 'Already have an account? Login'
                                      : 'Don\'t have an account? Register',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Comment out Google sign-in option
                        // ...existing code...
                      ],
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
  
  // Helper method for consistent text form fields
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Function(String)? onFieldSubmitted,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
        keyboardType: keyboardType,
        textInputAction: onFieldSubmitted != null ? TextInputAction.done : TextInputAction.next,
        obscureText: obscureText,
        enableInteractiveSelection: !obscureText,
        autocorrect: false,
        onFieldSubmitted: onFieldSubmitted,
        validator: validator,
      ),
    );
  }
}
