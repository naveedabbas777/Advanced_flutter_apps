import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
// import 'package:webview_flutter/webview_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isRegistered = false;
  Timer? _verificationCheckTimer;
  bool _isEmailVerified = false;
  // String? _recaptchaToken;
  // bool _isRecaptchaVerified = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _verificationCheckTimer?.cancel();
    super.dispose();
  }

  void _startVerificationCheck() {
    _verificationCheckTimer =
        Timer.periodic(Duration(seconds: 3), (timer) async {
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.emailVerified) {
        setState(() {
          _isEmailVerified = true;
        });
        timer.cancel();
        // Optionally, navigate to login or home automatically:
        // Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      await authProvider.register(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
      );

      if (authProvider.error == null) {
        setState(() {
          _isRegistered = true;
        });
        _startVerificationCheck();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authProvider.error!)),
        );
      }
    }
    // else if (!_isRecaptchaVerified) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text('Please complete the reCAPTCHA verification')),
    //   );
    // }
  }

  Future<void> _resendVerificationEmail() async {
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    await authProvider.resendVerificationEmail();

    if (authProvider.error == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent!')),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.error!)),
      );
    }
  }

  // void _showRecaptchaDialog() {
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (context) => Dialog(
  //       child: Container(
  //         height: 500,
  //         width: 400,
  //         child: Column(
  //           children: [
  //             Padding(
  //               padding: const EdgeInsets.all(8.0),
  //               child: Row(
  //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   Text(
  //                     'Verify you are human',
  //                     style: Theme.of(context).textTheme.titleLarge,
  //                   ),
  //                   IconButton(
  //                     icon: Icon(Icons.close),
  //                     onPressed: () => Navigator.pop(context),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //             Expanded(
  //               child: WebViewWidget(
  //                 controller: WebViewController()
  //                   ..setJavaScriptMode(JavaScriptMode.unrestricted)
  //                   ..setBackgroundColor(Colors.white)
  //                   ..setNavigationDelegate(
  //                     NavigationDelegate(
  //                       onPageFinished: (String url) {
  //                         if (url.contains('recaptcha/api2/userverify')) {
  //                           final token = Uri.parse(url).queryParameters['token'];
  //                           if (token != null) {
  //                             setState(() {
  //                               _recaptchaToken = token;
  //                               _isRecaptchaVerified = true;
  //                             });
  //                             Navigator.pop(context);
  //                           }
  //                         }
  //                       },
  //                     ),
  //                   )
  //                   ..loadRequest(
  //                     Uri.parse(
  //                       'https://www.google.com/recaptcha/api2/anchor?k=6Ldm8mArAAAAAI0hSSRphzEBD3SoCPNkp639BMD9&co=aHR0cHM6Ly9leGFtcGxlLmNvbTo0NDM.&hl=en&v=v1559547661201&size=normal&cb=1234567890',
  //                     ),
  //                   ),
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AppAuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Lottie.asset(
              'assets/lotties/loginbg.json',
              fit: BoxFit.cover,
              repeat: true,
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.person_add,
                      size: 80,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Create Account',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (!_isRegistered) ...[
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: authProvider.isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: authProvider.isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Register'),
                      ),
                    ] else ...[
                      Icon(
                        Icons.mark_email_read,
                        size: 80,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Verification Email Sent!',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Please check your email and click the verification link to activate your account.',
                        style: theme.textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _resendVerificationEmail,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Resend Verification Email'),
                      ),
                      const SizedBox(height: 24),
                      if (!_isEmailVerified)
                        Text(
                          'Waiting for email verification... You cannot continue until your email is verified.',
                          style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      if (_isEmailVerified)
                        Column(
                          children: [
                            Text(
                              'Email verified! You can now log in.',
                              style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Back to Login'),
                            ),
                          ],
                        ),
                    ],
                    const SizedBox(height: 16),
                    if (!_isRegistered || _isEmailVerified)
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Back to Login'),
                      ),
                    const SizedBox(height: 16),
                    IconButton(
                      onPressed: () {
                        themeProvider.toggleTheme();
                      },
                      icon: Icon(
                        themeProvider.isDarkMode
                            ? Icons.light_mode
                            : Icons.dark_mode,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
