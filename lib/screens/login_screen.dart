import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isRegistering = false;
  bool _showPassword = false;
  String _errorMessage = '';

    // Check if email is allowed
  Future<bool> _isEmailAllowed(String email) async {
  try {
    final cleanEmail = email.trim().toLowerCase();
    print('🔍 Searching for email: $cleanEmail');

    // First, try to get the whole collection
    print('📂 Attempting to read allowed_emails collection...');
    final allDocs = await FirebaseFirestore.instance
        .collection('allowed_emails')
        .get();
    
    print('📊 Found ${allDocs.docs.length} documents in collection');
    
    // Print all documents
    for (var doc in allDocs.docs) {
      print('👉 Document ID: ${doc.id}');
      print('   Data: ${doc.data()}');
      
      // Check if this document matches
      final docEmail = doc.data()['email'];
      print('   Comparing: "$docEmail" == "$cleanEmail"');
      
      if (docEmail == cleanEmail) {
        print('✅ Match found!');
        return true;
      }
    }
    
    print('❌ No match found in ${allDocs.docs.length} documents');
    return false;
    
  } catch (e) {
    print('🔥 CRITICAL ERROR: $e');
    print('🔥 Error type: ${e.runtimeType}');
    setState(() {
      _errorMessage = 'Database error: ${e.toString()}';
    });
    return false;
  }
}

  // Check if account is blocked
  Future<bool> _isAccountBlocked(String email) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('login_attempts')
          .doc(email.trim().toLowerCase())
          .get();
      if (doc.exists) {
        final attempts = doc.data()?['attempts'] ?? 0;
        final blocked = doc.data()?['blocked'] ?? false;
        if (blocked || attempts >= 3) return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Record failed login attempt
  Future<void> _recordFailedAttempt(String email) async {
    final ref = FirebaseFirestore.instance
        .collection('login_attempts')
        .doc(email.trim().toLowerCase());
    final doc = await ref.get();
    int attempts = 1;
    if (doc.exists) {
      attempts = (doc.data()?['attempts'] ?? 0) + 1;
    }
    await ref.set({
      'attempts': attempts,
      'blocked': attempts >= 3,
      'lastAttempt': DateTime.now(),
      'email': email.trim().toLowerCase(),
    }, SetOptions(merge: true));
  }

  // Reset attempts after successful login
  Future<void> _resetAttempts(String email) async {
    await FirebaseFirestore.instance
        .collection('login_attempts')
        .doc(email.trim().toLowerCase())
        .set({'attempts': 0, 'blocked': false}, SetOptions(merge: true));
  }

  // Email & Password Login
  Future<void> _loginWithEmail() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter email and password';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final email = _emailController.text.trim().toLowerCase();

      // Check if blocked
      if (await _isAccountBlocked(email)) {
        setState(() {
          _errorMessage =
              'Account blocked after 3 failed attempts. Contact admin.';
          _isLoading = false;
        });
        return;
      }

      // Check if email is allowed
      if (!await _isEmailAllowed(email)) {
        setState(() {
          _errorMessage =
              'Access denied. Your email is not authorized. Contact admin.';
          _isLoading = false;
        });
        return;
      }

      // Try login
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      await _resetAttempts(email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        await _recordFailedAttempt(_emailController.text.trim());
        final doc = await FirebaseFirestore.instance
            .collection('login_attempts')
            .doc(_emailController.text.trim().toLowerCase())
            .get();
        final attempts = doc.data()?['attempts'] ?? 3;
        final remaining = 3 - attempts;
        if (remaining <= 0) {
          setState(() {
            _errorMessage =
                'Account blocked after 3 failed attempts. Contact admin.';
          });
        } else {
          setState(() {
            _errorMessage = 'Wrong password. $remaining attempt(s) remaining.';
          });
        }
      } else if (e.code == 'user-not-found') {
        setState(() {
          _errorMessage = 'No account found with this email.';
        });
      } else {
        setState(() {
          _errorMessage = 'Error: ${e.message ?? e.code}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  // Register New User
  Future<void> _registerWithEmail() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter email and password';
      });
      return;
    }
    if (_passwordController.text.trim().length < 6) {
      setState(() {
        _errorMessage = 'Password must be at least 6 characters';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final email = _emailController.text.trim().toLowerCase();

      // Check if email is allowed
      if (!await _isEmailAllowed(email)) {
        setState(() {
          _errorMessage =
              'Access denied. Your email is not authorized. Contact admin.';
          _isLoading = false;
        });
        return;
      }

      // Register
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email,
            password: _passwordController.text.trim(),
          );

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({'email': email, 'createdAt': DateTime.now(), 'role': 'user'});
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        setState(() {
          _errorMessage = 'This email is already registered. Try Login.';
        });
      } else {
        setState(() {
          _errorMessage = 'Error: ${e.message ?? e.code}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  // Google Sign In
  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.setCustomParameters({
        'prompt': 'select_account',
        'client_id':
            '455567012708-243capj9rkrki8dq3pds46q3c58a73c2.apps.googleusercontent.com',
      });

      final userCredential = await FirebaseAuth.instance.signInWithPopup(
        googleProvider,
      );

      final email = userCredential.user?.email ?? '';

      if (email.isEmpty) {
        await FirebaseAuth.instance.signOut();
        setState(() {
          _errorMessage = 'Could not get email from Google.';
          _isLoading = false;
        });
        return;
      }

      if (!await _isEmailAllowed(email)) {
        await FirebaseAuth.instance.signOut();
        setState(() {
          _errorMessage = 'Access denied. $email is not authorized.';
          _isLoading = false;
        });
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'name': userCredential.user!.displayName,
            'email': email,
            'lastLogin': DateTime.now(),
            'role': 'user',
          }, SetOptions(merge: true));
    } catch (e) {
      setState(() {
        _errorMessage = 'Google error: ${e.toString()}';
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 80, color: Colors.blue),
                const SizedBox(height: 24),
                Text(
                  _isRegistering ? 'Create Account' : 'Welcome Back',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Authorized users only',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),

                // Email Field
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),

                // Password Field with Show/Hide
                TextField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _showPassword = !_showPassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Error Message
                if (_errorMessage.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Login / Register Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : (_isRegistering
                              ? _registerWithEmail
                              : _loginWithEmail),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _isRegistering ? 'Register' : 'Login',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),

                // Toggle Login/Register
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isRegistering = !_isRegistering;
                      _errorMessage = '';
                    });
                  },
                  child: Text(
                    _isRegistering
                        ? 'Already have an account? Login'
                        : 'No account? Register here',
                  ),
                ),
                const SizedBox(height: 16),

                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('OR'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),

                // Google Login Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    icon: const Icon(
                      Icons.g_mobiledata,
                      size: 28,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'Sign in with Google',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
}
