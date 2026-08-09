import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'google_windows_oauth_stub.dart'
    if (dart.library.io) 'google_windows_oauth_io.dart';

class GoogleAuthService {
  static Future<void>? _googleSignInInitialization;

  final FirebaseAuth _auth;

  GoogleAuthService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  Future<void> _ensureGoogleSignInInitialized() async {
    _googleSignInInitialization ??= GoogleSignIn.instance.initialize();

    try {
      await _googleSignInInitialization;
    } catch (_) {
      _googleSignInInitialization = null;
      rethrow;
    }
  }

  Future<UserCredential> continueWithGoogle() async {
    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});

    if (kIsWeb) {
      return _auth.signInWithPopup(provider);
    }

    if (defaultTargetPlatform == TargetPlatform.windows) {
      return signInWithGoogleOnWindows(_auth);
    }

    await _ensureGoogleSignInInitialized();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw FirebaseAuthException(
        code: 'operation-not-supported-in-this-environment',
        message: 'Google Sign-In is not supported on this platform.',
      );
    }

    try {
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken?.trim() ?? '';

      if (idToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-google-id-token',
          message: 'Google did not return an ID token for Firebase sign-in.',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      return _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      throw FirebaseAuthException(
        code: _firebaseCodeForGoogleException(e),
        message: e.description ?? 'Google Sign-In failed.',
      );
    }
  }

  String _firebaseCodeForGoogleException(GoogleSignInException exception) {
    switch (exception.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'user-cancelled';
      case GoogleSignInExceptionCode.interrupted:
        return 'cancelled-popup-request';
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'operation-not-allowed';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'operation-not-supported-in-this-environment';
      case GoogleSignInExceptionCode.userMismatch:
      case GoogleSignInExceptionCode.unknownError:
        return 'google-sign-in-failed';
    }
  }
}
