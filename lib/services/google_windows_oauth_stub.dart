import 'package:firebase_auth/firebase_auth.dart';

Future<UserCredential> signInWithGoogleOnWindows(FirebaseAuth auth) {
  throw FirebaseAuthException(
    code: 'operation-not-supported-in-this-environment',
    message: 'Windows Google Sign-In is only available on desktop builds.',
  );
}
