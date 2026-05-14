import 'dart:convert';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../network/backend_connector.dart';
import 'phone_mfa.dart';

// Represents the user's account details and permissions from the backend
class AuthStatus {
  final String uid;
  final String role;
  final String? email;
  final String? fullName;
  final bool mfaVerified;
  final String? mfaFactor;

  AuthStatus({
    required this.uid,
    required this.role,
    required this.email,
    required this.fullName,
    required this.mfaVerified,
    required this.mfaFactor,
  });

  factory AuthStatus.fromJson(Map<String, dynamic> json) {
    return AuthStatus(
      uid: json['uid'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
      mfaVerified: json['mfa_verified'] as bool? ?? false,
      mfaFactor: json['mfa_factor'] as String?,
    );
  }
}

enum AuthOtpFlowType { signInMfa, enrollPhone }

enum AuthNextStep { emailVerification, otp, companionReady }

// Wraps the result of an auth attempt to tell the UI where to go next
class AuthFlowResult {
  final AuthNextStep nextStep;
  final AuthOtpSession? otpSession;
  final String email;

  AuthFlowResult({
    required this.nextStep,
    required this.otpSession,
    required this.email,
  });
}

// Holds data needed to complete an SMS OTP verification
class AuthOtpSession {
  final String verificationId;
  final AuthOtpFlowType flowType;
  final String destination;
  final MultiFactorResolver? resolver;
  final String displayName;

  AuthOtpSession({
    required this.verificationId,
    required this.flowType,
    required this.destination,
    required this.resolver,
    required this.displayName,
  });
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BackendConnector _backend = BackendConnector.instance;

  // Handling email and multifactor authentication flows, and communicating with the backend to fetch user status and permissions
  Future<AuthFlowResult> startLoginFlow({
    required String email,
    required String password,
  }) async {
    try {
      // Attempt standard email/password sign-in
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw StateError('No authenticated user found.');
      }

      // Check if email is verified before proceeding
      if (!user.emailVerified) {
        await _sendEmailVerification(user);
        return AuthFlowResult(
          nextStep: AuthNextStep.emailVerification,
          otpSession: null,
          email: user.email ?? email,
        );
      }

      // Verify user role and branch by account type
      final authStatus = await fetchAuthStatus();

      if (authStatus.role == 'companion') {
        // Companions skip MFA no phone number on record
        return AuthFlowResult(
          nextStep: AuthNextStep.companionReady,
          otpSession: null,
          email: user.email ?? email,
        );
      }

      if (authStatus.role != 'patient') {
        await _auth.signOut();
        throw StateError('Access denied: only patient accounts are allowed.');
      }

      final phone = await _readUserPhone(user.uid);
      if (phone.isEmpty) {
        await _auth.signOut();
        throw StateError(
          'No phone number found. Please contact support to add your number.',
        );
      }
      // Trigger phone enrollment if MFA isn't set up yet
      final verificationId = await _sendEnrollmentOtp(user, phone);

      return AuthFlowResult(
        nextStep: AuthNextStep.otp,
        otpSession: AuthOtpSession(
          verificationId: verificationId,
          flowType: AuthOtpFlowType.enrollPhone,
          destination: maskLocalPhone(phone),
          resolver: null,
          displayName: 'Login phone',
        ),
        email: user.email ?? email,
      );
    } on FirebaseAuthMultiFactorException catch (error) {
      // Logic for users who ALREADY have MFA enabled
      final resolver = error.resolver;
      final phoneHint = resolver.hints
          .whereType<PhoneMultiFactorInfo>()
          .firstWhere(
            (hint) => hint.factorId == 'phone',
            orElse: () => throw StateError(
              'No phone-based second factor is available for this account.',
            ),
          );

      final verificationId = await _sendMfaOtp(resolver, phoneHint);
      final destination = phoneHint.phoneNumber;

      return AuthFlowResult(
        nextStep: AuthNextStep.otp,
        otpSession: AuthOtpSession(
          verificationId: verificationId,
          flowType: AuthOtpFlowType.signInMfa,
          destination: destination,
          resolver: resolver,
          displayName: 'Login phone',
        ),
        email: email,
      );
    } on FirebaseAuthException catch (error) {
      throw StateError(_mapFirebaseAuthErrorMessage(error));
    }
  }

  // Registers a new user and saves their profile to Firestore
  Future<AuthFlowResult> startSignupFlow({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final normalizedPhone = normalizeSriLankanPhone(phone);
    final _ = toSriLankanE164(normalizedPhone);

    // Create the account in Firebase Authentication
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw StateError('Failed to create user.');
    }

    final fullName = _buildFullName(firstName, lastName);
    await user.updateDisplayName(fullName);

    // Save additional user metadata to the 'users' collection
    await _firestore.collection('users').doc(user.uid).set({
      'fullName': fullName,
      'email': email,
      'phone': normalizedPhone,
      'role': 'patient',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _sendEmailVerification(user);

    return AuthFlowResult(
      nextStep: AuthNextStep.emailVerification,
      otpSession: null,
      email: user.email ?? email,
    );
  }

  // Explicitly triggers the SMS MFA setup process for the logged-in user
  Future<AuthOtpSession> startPhoneEnrollmentForCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Session expired. Please log in again.');
    }

    await user.reload();
    if (!user.emailVerified) {
      throw StateError('Please verify your email before continuing.');
    }

    final authStatus = await fetchAuthStatus();
    if (authStatus.role != 'patient') {
      await _auth.signOut();
      throw StateError('Access denied: only patient accounts are allowed.');
    }

    final phone = await _readUserPhone(user.uid);
    if (phone.isEmpty) {
      throw StateError('No phone number found. Please contact support.');
    }

    final verificationId = await _sendEnrollmentOtp(user, phone);

    return AuthOtpSession(
      verificationId: verificationId,
      flowType: AuthOtpFlowType.enrollPhone,
      destination: maskLocalPhone(phone),
      resolver: null,
      displayName: 'Login phone',
    );
  }

  // Checks if the user has clicked the verification link in their email
  Future<bool> reloadAndCheckEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) {
      return false;
    }
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  // Validates the SMS code and completes sign-in or MFA enrollment
  Future<void> resendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Session expired. Please log in again.');
    }
    await _sendEmailVerification(user);
  }

  Future<void> verifyOtp(AuthOtpSession session, String code) async {
    final trimmed = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      throw StateError('Please enter a valid 6-digit OTP code.');
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: session.verificationId,
      smsCode: trimmed,
    );

    // Resolving an existing MFA challenge during login
    if (session.flowType == AuthOtpFlowType.signInMfa) {
      final resolver = session.resolver;
      if (resolver == null) {
        throw StateError('Verification session expired. Please log in again.');
      }

      final assertion = PhoneMultiFactorGenerator.getAssertion(credential);
      await resolver.resolveSignIn(assertion);

      final user = _auth.currentUser;
      if (user == null) {
        throw StateError('Session expired. Please log in again.');
      }

      if (!user.emailVerified) {
        await _sendEmailVerification(user);
        throw StateError(
          'Please verify your email first. We sent a verification link.',
        );
      }

      final authStatus = await fetchAuthStatus();
      if (authStatus.role != 'patient') {
        await _auth.signOut();
        throw StateError('Access denied: only patient accounts are allowed.');
      }
      return;
    }

    // Finalizing new MFA enrollment for a user
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Session expired. Please log in again.');
    }

    final assertion = PhoneMultiFactorGenerator.getAssertion(credential);
    await user.multiFactor.enroll(assertion, displayName: session.displayName);

    // Force refresh the token to include the new MFA claims
    await user.getIdToken(true);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      throw StateError('Please enter your email address first.');
    }
    try {
      await _auth.sendPasswordResetEmail(email: trimmed);
    } on FirebaseAuthException catch (error) {
      throw StateError(_mapFirebaseAuthErrorMessage(error));
    }
  }

  // Calls custom backend to get the user's specific role and status
  Future<AuthStatus> fetchAuthStatus() async {
    final response = await _backend.get('/auth/me');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return AuthStatus.fromJson(data);
    }

    throw StateError(
      'Failed to fetch auth status: ${response.statusCode} ${response.body}',
    );
  }

  // Prepares the multi-factor session for enrollment
  Future<String> _sendEnrollmentOtp(User user, String localPhone) async {
    final phoneNumber = toSriLankanE164(localPhone);
    final session = await user.multiFactor.getSession();

    return _sendOtp(phoneNumber: phoneNumber, multiFactorSession: session);
  }

  // Prepares the multi-factor session for existing MFA verification
  Future<String> _sendMfaOtp(
    MultiFactorResolver resolver,
    PhoneMultiFactorInfo phoneHint,
  ) async {
    return _sendOtp(
      multiFactorSession: resolver.session,
      multiFactorInfo: phoneHint,
    );
  }

  // Core internal method to trigger Firebase Phone verification
  Future<String> _sendOtp({
    String? phoneNumber,
    MultiFactorSession? multiFactorSession,
    PhoneMultiFactorInfo? multiFactorInfo,
  }) async {
    final completer = Completer<String>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      multiFactorSession: multiFactorSession,
      multiFactorInfo: multiFactorInfo,
      verificationCompleted: (credential) {
        // Keep manual OTP entry for consistent UX.
      },
      verificationFailed: (FirebaseAuthException error) {
        if (!completer.isCompleted) {
          completer.completeError(_mapFirebaseError(error));
        }
      },
      codeSent: (verificationId, resendToken) {
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!completer.isCompleted) {
          completer.complete(verificationId);
        }
      },
    );

    return completer.future;
  }

  // Helper to fetch the registered phone number from the user's Firestore doc
  Future<String> _readUserPhone(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    if (!snapshot.exists) {
      return '';
    }

    final data = snapshot.data();
    final phone = data == null ? null : data['phone'];
    if (phone is String) {
      return phone.trim();
    }

    return '';
  }

  // Provides user-friendly explanations for common Firebase Auth errors
  Object _mapFirebaseError(FirebaseAuthException error) {
    if (error.code == 'auth/operation-not-allowed') {
      return StateError(
        'SMS OTP is blocked by Firebase settings. Enable Phone provider, enable SMS MFA, and allow Sri Lanka (+94) in Authentication -> Settings -> SMS region policy.',
      );
    }

    return error;
  }

  String _mapFirebaseAuthErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No account was found with that email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network issue. Check your connection and try again.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }

  Future<void> _sendEmailVerification(User user) async {
    await user.sendEmailVerification();
  }

  // Safely combines first and last name into a single string
  String _buildFullName(String firstName, String lastName) {
    final left = firstName.trim();
    final right = lastName.trim();
    if (left.isEmpty && right.isEmpty) {
      return '';
    }
    if (right.isEmpty) {
      return left;
    }
    if (left.isEmpty) {
      return right;
    }
    return '$left $right';
  }
}
