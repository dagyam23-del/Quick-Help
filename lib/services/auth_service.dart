import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication service handling user sign up, sign in, and sign out
class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get the current logged-in user
  User? get currentUser => _supabase.auth.currentUser;

  /// Stream of authentication state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Get the current URL for email confirmation redirect (web only)
  /// For mobile, returns null (email confirmation redirect not needed)
  String? get _redirectUrl {
    // For web, use the current URL with a reset password route
    // For mobile, returns null (email confirmation redirect not needed)
    if (kIsWeb) {
      // Get the current origin (protocol + host + port)
      final uri = Uri.base;
      // Use the actual deployment URL (Vercel)
      // Replace with your actual Vercel URL if different
      final baseUrl = uri.host.contains('vercel.app') || uri.host.contains('localhost')
          ? '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}'
          : 'https://quickhelp-app.vercel.app'; // Your Vercel deployment URL
      return '$baseUrl/reset-password';
    }
    return null;
  }

  /// Sign up a new user
  /// Returns a map with success status and user information
  Future<Map<String, dynamic>> signUp(
      String email, String password, String name) async {
    try {
      // Normalize email to lowercase
      final cleanEmail = email.trim().toLowerCase();

      final response = await _supabase.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {'name': name},
        emailRedirectTo: _redirectUrl,
      );

      // Check if user was created successfully
      if (response.user != null) {
        final userId = response.user!.id;
        final userEmail = response.user!.email;
        final session = response.session;

        // If session exists, user is automatically signed in (email confirmation disabled)
        // If session is null, user needs to confirm email first
        if (session != null) {
          // User is signed in, verify current user matches
          final currentUser = _supabase.auth.currentUser;
          if (currentUser?.id == userId) {
            return {
              'success': true,
              'userCreated': true,
              'emailSent': true,
              'needsConfirmation': false,
              'autoSignedIn': true,
              'userId': userId,
              'userEmail': userEmail,
            };
          }
        }

        // If no session, user needs email confirmation
        return {
          'success': true,
          'userCreated': true,
          'emailSent': false,
          'needsConfirmation': true,
          'autoSignedIn': false,
          'userId': userId,
          'userEmail': userEmail,
        };
      }

      throw Exception('Failed to create account. User object is null.');
    } catch (e) {
      // Check if it's an email sending error
      final errorString = e.toString().toLowerCase();
      final isEmailError = errorString.contains('confirmation email') ||
          errorString.contains('sending') ||
          errorString.contains('error sending') ||
          (e is AuthException && e.statusCode?.toString() == '500');

      if (isEmailError) {
        // Account might have been created even if email failed
        return {
          'success': true,
          'userCreated': true,
          'emailSent': false,
          'needsConfirmation': true,
          'emailError': true,
          'message':
              'Account may have been created, but confirmation email failed. Try signing in directly.',
        };
      }

      // Re-throw other errors
      if (e is AuthException) {
        if (kDebugMode) {
          debugPrint(
              'SignUp AuthException: ${e.message}, code: ${e.code}, statusCode: ${e.statusCode}');
        }
        throw Exception('Failed to create account: ${e.message}');
      }
      if (kDebugMode) {
        debugPrint('SignUp error: ${e.toString()}');
      }
      throw Exception('Failed to create account: ${e.toString()}');
    }
  }

  /// Sign in an existing user
  Future<void> signIn(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      if (response.user == null) {
        throw Exception('Invalid email or password');
      }

      // Ensure a public profile row exists (so other users can see name/avatar).
      await ensureProfile();

      // Sign in successful - Supabase handles email confirmation automatically
    } on AuthException catch (e) {
      // Handle specific auth errors
      if (e.message.contains('Invalid login credentials') ||
          e.message.contains('invalid') ||
          (e.statusCode?.toString() == '400' &&
              e.code == 'invalid_credentials')) {
        throw Exception(
            'Invalid email or password. If you just signed up, please check your email '
            'and click the confirmation link first. Otherwise, verify your credentials are correct.');
      } else if (e.message.contains('Email not confirmed') ||
          e.message.contains('confirmation') ||
          e.message.contains('not been confirmed')) {
        throw Exception(
            'Please check your email and click the confirmation link before signing in. '
            'If you didn\'t receive the email, check your spam folder.');
      }
      throw Exception(e.message);
    } catch (e) {
      // Re-throw other errors
      if (e.toString().contains('Exception: ')) {
        rethrow;
      }
      throw Exception('Sign in failed: ${e.toString()}');
    }
  }

  /// Send an SMS OTP to a phone number.
  /// This works for both login and registration (Supabase will create the user
  /// if phone auth is enabled and `shouldCreateUser` is true).
  Future<void> sendPhoneOtp(String phoneNumber,
      {bool shouldCreateUser = true}) async {
    try {
      final cleanPhone = phoneNumber.trim().replaceAll(RegExp(r'\s+'), '');
      if (cleanPhone.isEmpty) {
        throw Exception('Please enter a phone number');
      }

      await _supabase.auth.signInWithOtp(
        phone: cleanPhone,
        shouldCreateUser: shouldCreateUser,
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      if (e.toString().contains('Exception: ')) rethrow;
      throw Exception('Failed to send OTP: ${e.toString()}');
    }
  }

  /// Verify an SMS OTP received by the user.
  /// After verification, the user will be signed in.
  /// If password is provided, it will be set for the user account.
  Future<void> verifyPhoneOtp({
    required String phoneNumber,
    required String otp,
    String? name,
    String? password,
  }) async {
    try {
      final cleanPhone = phoneNumber.trim().replaceAll(RegExp(r'\s+'), '');
      final cleanOtp = otp.trim();
      if (cleanPhone.isEmpty) {
        throw Exception('Please enter a phone number');
      }
      if (cleanOtp.isEmpty) {
        throw Exception('Please enter the verification code');
      }

      final response = await _supabase.auth.verifyOTP(
        type: OtpType.sms,
        phone: cleanPhone,
        token: cleanOtp,
      );

      if (response.session == null && _supabase.auth.currentUser == null) {
        throw Exception('Verification failed. Please try again.');
      }

      // Set password if provided (for new sign-ups)
      final cleanPassword = password?.trim();
      if (cleanPassword != null && cleanPassword.isNotEmpty) {
        if (cleanPassword.length < 6) {
          throw Exception('Password must be at least 6 characters');
        }
        await _supabase.auth.updateUser(
          UserAttributes(password: cleanPassword),
        );
      }

      // Optionally store name in user metadata (works for new or existing users).
      final cleanName = name?.trim();
      if (cleanName != null && cleanName.isNotEmpty) {
        await _supabase.auth.updateUser(
          UserAttributes(
            data: {'name': cleanName},
          ),
        );
      }

      // Ensure profile exists and sync name if provided.
      await ensureProfile(nameOverride: cleanName);
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      if (e.toString().contains('Exception: ')) rethrow;
      throw Exception('Failed to verify OTP: ${e.toString()}');
    }
  }

  /// Sign in using phone number and password
  Future<void> signInWithPhonePassword(
      String phoneNumber, String password) async {
    try {
      final cleanPhone = phoneNumber.trim().replaceAll(RegExp(r'\s+'), '');
      if (cleanPhone.isEmpty) {
        throw Exception('Please enter a phone number');
      }
      if (password.isEmpty) {
        throw Exception('Please enter your password');
      }

      final response = await _supabase.auth.signInWithPassword(
        phone: cleanPhone,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Invalid phone number or password');
      }

      // Ensure a public profile row exists (so other users can see name/avatar).
      await ensureProfile();
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials') ||
          e.message.contains('invalid') ||
          (e.statusCode?.toString() == '400' &&
              e.code == 'invalid_credentials')) {
        throw Exception('Invalid phone number or password');
      }
      throw Exception(e.message);
    } catch (e) {
      if (e.toString().contains('Exception: ')) rethrow;
      throw Exception('Sign in failed: ${e.toString()}');
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Reset password for email
  Future<void> resetPasswordForEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    await _supabase.auth.resetPasswordForEmail(
      cleanEmail,
      redirectTo: _redirectUrl,
    );
  }

  /// Reset password for phone (send OTP)
  Future<void> resetPasswordForPhone(String phoneNumber) async {
    final cleanPhone = phoneNumber.trim().replaceAll(RegExp(r'\s+'), '');
    await _supabase.auth.signInWithOtp(
      phone: cleanPhone,
      shouldCreateUser: false,
    );
  }

  /// Update password after password reset
  /// This should be called when user is on the reset password screen
  /// (after clicking the reset link in email)
  Future<void> updatePassword(String newPassword) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception(
          'No active session. Please click the reset link from your email again.');
    }

    await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  /// Get the current user's name from metadata
  String? getUserName() {
    return _supabase.auth.currentUser?.userMetadata?['name'] as String?;
  }

  /// Update user's name in metadata
  Future<void> updateUserName(String name) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _supabase.auth.updateUser(
      UserAttributes(
        data: {
          'name': name,
        },
      ),
    );

    // Keep profiles table in sync so other users can see the updated name.
    await ensureProfile(nameOverride: name);
  }

  /// Ensure a row exists in `profiles` for the current user.
  /// This is used to show name/avatar to other users (requests list, etc).
  Future<void> ensureProfile({String? nameOverride}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final nameFromMeta =
        nameOverride ?? (user.userMetadata?['name'] as String?);
    final payload = <String, dynamic>{
      'id': user.id,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (nameFromMeta != null && nameFromMeta.trim().isNotEmpty) {
      payload['name'] = nameFromMeta.trim();
    }

    try {
      await _supabase.from('profiles').upsert(payload);
    } catch (e) {
      // Don't block auth flows if profiles table isn't created yet.
      if (kDebugMode) {
        debugPrint('ensureProfile failed: $e');
      }
    }
  }
}
