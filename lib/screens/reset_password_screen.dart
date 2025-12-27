import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

/// Screen for resetting password after clicking email link
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isCheckingSession = true;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    // Try to recover session from URL if on web
    _checkAndRecoverSession();
  }

  Future<void> _checkAndRecoverSession() async {
    if (!mounted) return;

    // On web, try to explicitly get session from URL immediately
    if (kIsWeb) {
      try {
        final supabase = Supabase.instance.client;
        final uri = Uri.base;

        if (kDebugMode) {
          debugPrint('ResetPasswordScreen - Checking URL. Path: ${uri.path}, Hash length: ${uri.fragment.length}');
        }

        // Try to get session from URL (handles hash fragments)
        await supabase.auth.getSessionFromUrl(uri);

        // Give it a moment for the session to be set
        await Future.delayed(const Duration(milliseconds: 800));
      } catch (e) {
        // Error recovering session, continue anyway
        if (kDebugMode) {
          debugPrint('Error recovering session from URL: $e');
        }
      }
    } else {
      // On mobile, wait a moment for session processing
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (!mounted) return;

    // Check if we have a current session (might have been recovered)
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.currentUser != null) {
      if (kDebugMode) {
        debugPrint('ResetPasswordScreen - Session recovered successfully');
      }
      if (mounted) {
        setState(() {
          _isCheckingSession = false;
        });
      }
      return;
    }

    // No session found - but don't show error immediately, user might still be able to use the form
    // The error will show when they try to submit
    if (kDebugMode) {
      debugPrint('ResetPasswordScreen - No session found after recovery attempt');
    }
    if (mounted) {
      setState(() {
        _isCheckingSession = false;
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Check if user has a session (should have one from password reset link)
      if (authService.currentUser == null) {
        throw Exception(
          'No active session. Please click the password reset link from your email again. '
          'The link may have expired or already been used.'
        );
      }

      await authService.updatePassword(_passwordController.text);

      if (mounted) {
        setState(() {
          _successMessage = 'Password reset successfully! Redirecting to sign in...';
          _isLoading = false;
        });

        // Sign out the recovery session and navigate to auth screen
        await authService.signOut();
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/auth');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          String errorMsg = e.toString().replaceAll('Exception: ', '');
          if (errorMsg.contains('No active session')) {
            _errorMessage = errorMsg;
          } else {
            _errorMessage = 'Failed to reset password: $errorMsg';
          }
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Reset Password'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.lock_reset,
                    size: 80,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Reset Your Password',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your new password below',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                  if (_successMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        _successMessage!,
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _resetPassword,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Reset Password'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.of(context).pushReplacementNamed('/auth');
                          },
                    child: const Text('Back to Sign In'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

