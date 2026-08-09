import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:googleapis_auth/auth_io.dart' as google_auth;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const _googleWindowsClientId = String.fromEnvironment(
  'GOOGLE_WINDOWS_CLIENT_ID',
);
const _googleWindowsClientSecret = String.fromEnvironment(
  'GOOGLE_WINDOWS_CLIENT_SECRET',
);
const _scopes = ['openid', 'email', 'profile'];
const _callbackTimeout = Duration(minutes: 5);

Future<UserCredential> signInWithGoogleOnWindows(FirebaseAuth auth) async {
  final clientId = _googleWindowsClientId.trim();
  final clientSecret = _googleWindowsClientSecret.trim();
  if (clientId.isEmpty) {
    throw FirebaseAuthException(
      code: 'missing-google-windows-client-id',
      message:
          'Windows Google Sign-In needs GOOGLE_WINDOWS_CLIENT_ID configured with a Google Desktop OAuth client ID.',
    );
  }

  if (clientSecret.isEmpty) {
    throw FirebaseAuthException(
      code: 'missing-google-windows-client-secret',
      message:
          'Windows Google Sign-In needs GOOGLE_WINDOWS_CLIENT_SECRET configured for the Google Desktop OAuth token exchange.',
    );
  }

  final httpClient = http.Client();
  try {
    final credentials = await google_auth
        .obtainAccessCredentialsViaUserConsent(
          google_auth.ClientId(clientId, clientSecret),
          _scopes,
          httpClient,
          _openSystemBrowser,
          customPostAuthPage: _postAuthPage,
        )
        .timeout(_callbackTimeout);
    final idToken = credentials.idToken?.trim() ?? '';
    if (idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google did not return an ID token for Firebase sign-in.',
      );
    }

    final credential = GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: credentials.accessToken.data,
    );
    return auth.signInWithCredential(credential);
  } on TimeoutException {
    throw FirebaseAuthException(
      code: 'windows-google-timeout',
      message: 'Google Sign-In timed out. Please try again.',
    );
  } on google_auth.UserConsentException catch (e) {
    throw FirebaseAuthException(code: 'user-cancelled', message: e.message);
  } on google_auth.ServerRequestFailedException catch (e) {
    throw FirebaseAuthException(
      code: 'google-oauth-failed',
      message: e.message,
    );
  } finally {
    httpClient.close();
  }
}

void _openSystemBrowser(String url) {
  unawaited(launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication));
}

const _postAuthPage = '''
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <title>Google Sign-In complete</title>
  </head>
  <body style="font-family: system-ui, sans-serif; padding: 32px;">
    <h2>Google Sign-In complete</h2>
    <p>You can close this window and return to Labmate.</p>
  </body>
</html>
''';
