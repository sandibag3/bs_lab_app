import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'app_state.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';

class AuthGate extends StatelessWidget {
  final AppState appState;

  const AuthGate({
    super.key,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData) {
          return HomeScreen(appState: appState);
        }

        return WelcomeScreen(appState: appState);
      },
    );
  }
}