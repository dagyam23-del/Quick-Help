import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

/// Forgot Password Dialog Widget
class _ForgotPasswordDialog extends StatefulWidget {
  final bool initialUsePhone;
  final BuildContext parentContext;

  const _ForgotPasswordDialog({
    required this.initialUsePhone,
    required this.parentContext,
  });

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _usePhone = false;
  bool _otpSent = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _usePhone = widget.initialUsePhone;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService =
          Provider.of<AuthService>(widget.parentContext, listen: false);

      if (!_usePhone) {
        // Email password reset
        await authService.resetPasswordForEmail(_emailController.text.trim());
        if (mounted) {
          Navigator.pop(context);
          if (widget.parentContext.mounted) {
            ScaffoldMessenger.of(widget.parentContext).showSnackBar(
              const SnackBar(
                content:
                    Text('Password reset email sent! Please check your inbox.'),
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      } else {
        // Phone password reset
        if (!_otpSent) {
          // Send OTP
          await authService.resetPasswordForPhone(_phoneController.text.trim());
          if (mounted) {
            setState(() {
              _otpSent = true;
              _isLoading = false;
            });
            if (widget.parentContext.mounted) {
              ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                const SnackBar(
                  content: Text('Verification code sent via SMS.'),
                ),
              );
            }
          }
        } else {
          // Verify OTP and update password
          final phoneForAuth = _phoneController.text.trim();
          await authService.verifyPhoneOtp(
            phoneNumber: phoneForAuth,
            otp: _otpController.text.trim(),
            password: _newPasswordController.text.trim(),
          );
          if (mounted) {
            Navigator.pop(context);
            if (widget.parentContext.mounted) {
              ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                const SnackBar(
                  content: Text('Password reset successfully!'),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Toggle between email and phone
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Email'),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Phone'),
                ),
              ],
              selected: {_usePhone},
              onSelectionChanged: (selection) {
                setState(() {
                  _usePhone = selection.first;
                  _otpSent = false;
                  _errorMessage = null;
                });
              },
            ),
            const SizedBox(height: 16),
            if (!_usePhone) ...[
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
              ),
            ] else ...[
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                  hintText: '+251912345678',
                ),
              ),
              if (_otpSent) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Verification Code',
                    prefixIcon: Icon(Icons.sms),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleReset,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _usePhone && _otpSent ? 'Reset Password' : 'Send Reset Link'),
        ),
      ],
    );
  }
}

/// Authentication screen for login and signup
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _phonePasswordController = TextEditingController();
  String? _e164PhoneNumber;
  bool _isLogin = true;
  bool _usePhone = false;
  bool _otpSent = false;
  bool _isLoading = false;
  bool _rememberMe = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _loadSavedPhoneCredentials();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _phonePasswordController.dispose();
    super.dispose();
  }

  /// Load saved email and password if remember me was checked
  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('saved_email');
      final savedPassword = prefs.getString('saved_password');
      final rememberMe = prefs.getBool('remember_me') ?? false;

      if (rememberMe && savedEmail != null && savedPassword != null) {
        setState(() {
          _emailController.text = savedEmail;
          _passwordController.text = savedPassword;
          _rememberMe = true;
        });
      }
    } catch (e) {
      // If loading fails, just continue without saved credentials
    }
  }

  /// Save email and password if remember me is checked
  Future<void> _saveCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('saved_email', _emailController.text.trim());
        await prefs.setString('saved_password', _passwordController.text);
        await prefs.setBool('remember_me', true);
      } else {
        // Clear saved credentials if remember me is unchecked
        await prefs.remove('saved_email');
        await prefs.remove('saved_password');
        await prefs.remove('remember_me');
      }
    } catch (e) {
      // If saving fails, continue anyway
    }
  }

  /// Save phone and password if remember me is checked
  Future<void> _savePhoneCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        final phoneForAuth = (_e164PhoneNumber ?? _phoneController.text).trim();
        await prefs.setString('saved_phone', phoneForAuth);
        await prefs.setString(
            'saved_phone_password', _phonePasswordController.text);
        await prefs.setBool('remember_phone', true);
      } else {
        // Clear saved credentials if remember me is unchecked
        await prefs.remove('saved_phone');
        await prefs.remove('saved_phone_password');
        await prefs.remove('remember_phone');
      }
    } catch (e) {
      // If saving fails, continue anyway
    }
  }

  /// Load saved phone credentials if remember me was checked
  Future<void> _loadSavedPhoneCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPhone = prefs.getString('saved_phone');
      final savedPhonePassword = prefs.getString('saved_phone_password');
      final rememberPhone = prefs.getBool('remember_phone') ?? false;

      if (rememberPhone && savedPhone != null && savedPhonePassword != null) {
        setState(() {
          _phoneController.text = savedPhone;
          _phonePasswordController.text = savedPhonePassword;
          _rememberMe = true;
        });
      }
    } catch (e) {
      // If loading fails, just continue without saved credentials
    }
  }

  /// Handle authentication (login or signup)
  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      if (_usePhone) {
        final phoneForAuth = (_e164PhoneNumber ?? _phoneController.text).trim();

        if (_isLogin) {
          // Phone + Password login only (no OTP option for login)
          await authService.signInWithPhonePassword(
            phoneForAuth,
            _phonePasswordController.text,
          );
          // Save credentials if remember me is checked
          await _savePhoneCredentials();
          // On success, AuthWrapper will route to HomeScreen
        } else {
          // Phone sign-up: step 1 send OTP, step 2 verify OTP and set password
          if (!_otpSent) {
            // Send OTP for sign-up
            await authService.sendPhoneOtp(
              phoneForAuth,
              shouldCreateUser: true,
            );

            if (mounted) {
              setState(() {
                _otpSent = true;
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Verification code sent via SMS.'),
                  duration: Duration(seconds: 4),
                ),
              );
            }
            return;
          } else {
            // Verify OTP and set password for sign-up
            await authService.verifyPhoneOtp(
              phoneNumber: phoneForAuth,
              otp: _otpController.text.trim(),
              name: _nameController.text.trim(),
              password: _phonePasswordController.text.trim(),
            );
            // On success, AuthWrapper will route to HomeScreen
          }
        }
      } else {
        // Email/password flow (existing)
        if (_isLogin) {
          await authService.signIn(
            _emailController.text.trim(),
            _passwordController.text,
          );
          // Save credentials if remember me is checked
          await _saveCredentials();
        } else {
          final result = await authService.signUp(
            _emailController.text.trim(),
            _passwordController.text,
            _nameController.text.trim(),
          );

          if (mounted) {
            // Show appropriate message based on result
            String message;
            Color backgroundColor = Colors.green;

            if (result['emailError'] == true) {
              message = 'Account created, but email confirmation failed. '
                  'If email confirmation is enabled, please check your email for a confirmation link. '
                  'Otherwise, you may need to disable email confirmation in Supabase settings.';
              backgroundColor = Colors.orange;
            } else if (result['needsConfirmation'] == true) {
              message =
                  'Account created! Please check your email and click the confirmation link to activate your account.';
            } else {
              final userId = result['userId'] ?? 'unknown';
              message =
                  'Account created successfully! User ID: ${userId.substring(0, 8)}... You are now signed in.';
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                duration: const Duration(seconds: 6),
                backgroundColor: backgroundColor,
              ),
            );

            // Reset form and switch to login
            _formKey.currentState?.reset();
            setState(() {
              _isLoading = false;
              _isLogin = true;
            });
            return;
          }
        }
      }
    } catch (e) {
      String errorMsg = e.toString().replaceAll('Exception: ', '');
      final lower = errorMsg.toLowerCase();

      // Provide more helpful error messages
      if (errorMsg.contains('404') || errorMsg.contains('empty response')) {
        errorMsg =
            'Supabase not configured. Please update YOUR_SUPABASE_URL and YOUR_SUPABASE_ANON_KEY in lib/main.dart with your Supabase credentials.';
      } else if (!_usePhone && errorMsg.contains('Invalid email or password')) {
        errorMsg = 'Invalid email or password. Please check your credentials.';
      } else if (!_usePhone && errorMsg.contains('Failed to create account')) {
        errorMsg =
            'Failed to create account. The email might already be in use.';
      } else if (!_usePhone &&
          (errorMsg.contains('confirmation email') ||
              errorMsg.contains('sending') ||
              errorMsg.contains('500'))) {
        errorMsg =
            'Email confirmation failed. Your account may still have been created. '
            'Please check your Supabase email settings or try signing in directly.';
      } else if (_usePhone && lower.contains('unsupported phone provider')) {
        errorMsg =
            'SMS OTP is not configured or your SMS provider doesn\'t support this destination. '
            'In Supabase: Authentication → Providers → Phone, enable Phone and configure an SMS provider '
            '(Twilio/Vonage/etc). If using Twilio, also enable SMS Geo Permissions for this country.';
      } else if (_usePhone &&
          (lower.contains('twilio') ||
              lower.contains('sms') ||
              lower.contains('otp'))) {
        // Generic phone OTP guidance for provider/config issues
        errorMsg =
            'Could not send SMS code. Please verify Supabase Phone provider is set to Twilio, '
            'your Twilio credentials are correct, and Twilio allows sending SMS to this country '
            '(Geo Permissions).';
      }

      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
      });
    }
  }

  void _resetPhoneFlow() {
    _otpController.clear();
    _phonePasswordController.clear();
    _e164PhoneNumber = null;
    setState(() {
      _otpSent = false;
    });
  }

  /// Show forgot password dialog
  Future<void> _showForgotPasswordDialog() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ForgotPasswordDialog(
        initialUsePhone: _usePhone,
        parentContext: context,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    Icons.volunteer_activism,
                    size: 80,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'QuickHelp',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin
                        ? 'Sign in to help others'
                        : 'Create an account to get started',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Auth method toggle
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('Email'),
                        icon: Icon(Icons.email_outlined),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Phone'),
                        icon: Icon(Icons.phone_android_outlined),
                      ),
                    ],
                    selected: {_usePhone},
                    onSelectionChanged: _isLoading
                        ? null
                        : (selection) {
                            final nextUsePhone = selection.first;
                            setState(() {
                              _usePhone = nextUsePhone;
                              _errorMessage = null;
                            });
                            if (nextUsePhone) {
                              _resetPhoneFlow();
                            }
                          },
                  ),
                  const SizedBox(height: 16),
                  if (!_isLogin) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        // Letters/spaces only (allow accents), plus common name punctuation.
                        final name = value.trim();
                        final nameRegex = RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿ' -]+$");
                        if (!nameRegex.hasMatch(name)) {
                          return 'Name can only contain letters and spaces';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_usePhone) ...[
                    IntlPhoneField(
                      controller: _phoneController,
                      disableLengthCheck: false,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        border: OutlineInputBorder(),
                      ),
                      initialCountryCode: 'ET',
                      onChanged: (phone) {
                        // Store E.164 phone number like +251912345678
                        _e164PhoneNumber = phone.completeNumber;
                      },
                      onCountryChanged: (_) {
                        // Clear OTP state when user changes country code.
                        if (_otpSent) {
                          _resetPhoneFlow();
                        }
                      },
                      validator: (phone) {
                        final value = phone?.completeNumber.trim() ?? '';
                        if (value.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        if (!value.startsWith('+')) {
                          return 'Invalid phone number';
                        }
                        return null;
                      },
                    ),
                    // For login: show password field only (no OTP option)
                    if (_isLogin) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phonePasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Remember me'),
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ],
                    // For sign-up: show OTP flow
                    if (!_isLogin && _otpSent) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Verification code',
                          prefixIcon: Icon(Icons.sms),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (!_otpSent) return null;
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the code';
                          }
                          if (value.trim().length < 4) {
                            return 'Code looks too short';
                          }
                          return null;
                        },
                      ),
                      // For sign-up: show password field after OTP is sent
                      if (!_isLogin) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phonePasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(),
                            helperText: 'Set a password for your account',
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
                      ],
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () async {
                                // resend
                                final messenger = ScaffoldMessenger.of(context);
                                final phoneForAuth =
                                    (_e164PhoneNumber ?? _phoneController.text)
                                        .trim();
                                setState(() {
                                  _isLoading = true;
                                  _errorMessage = null;
                                });
                                try {
                                  final authService = Provider.of<AuthService>(
                                      context,
                                      listen: false);
                                  await authService.sendPhoneOtp(
                                    phoneForAuth,
                                    shouldCreateUser: !_isLogin,
                                  );
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Code re-sent.'),
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    setState(() {
                                      _errorMessage = e
                                          .toString()
                                          .replaceAll('Exception: ', '');
                                    });
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() {
                                      _isLoading = false;
                                    });
                                  }
                                }
                              },
                        child: const Text('Resend code'),
                      ),
                    ],
                  ] else ...[
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
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
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
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
                    if (_isLogin) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Remember me'),
                              value: _rememberMe,
                              onChanged: (value) {
                                setState(() {
                                  _rememberMe = value ?? false;
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => _showForgotPasswordDialog(),
                            child: const Text('Forgot Password?'),
                          ),
                        ],
                      ),
                    ],
                  ],
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
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleAuth,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _usePhone
                                ? (_isLogin
                                    ? 'Sign In'
                                    : (_otpSent ? 'Verify Code' : 'Send Code'))
                                : (_isLogin ? 'Sign In' : 'Sign Up'),
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _isLogin = !_isLogin;
                              _errorMessage = null;
                              _formKey.currentState?.reset();
                              if (_usePhone) {
                                _resetPhoneFlow();
                              }
                            });
                          },
                    child: Text(
                      _isLogin
                          ? 'Don\'t have an account? Sign Up'
                          : 'Already have an account? Sign In',
                    ),
                  ),
                  if (_usePhone && _otpSent) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _errorMessage = null;
                              });
                              _resetPhoneFlow();
                            },
                      child: const Text('Change phone number'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
