import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'app_state.dart';
import 'screens/home_screen.dart';
import 'screens/lab_access_screen.dart';
import 'screens/welcome_screen.dart';

class AuthGate extends StatefulWidget {
  final AppState appState;

  const AuthGate({super.key, required this.appState});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String _resolvedUserId = '';
  String _resolvedLabId = '';
  Future<bool>? _labContextFuture;

  Future<bool> _resolveLabContextFor(User user) {
    final selectedLabId = widget.appState.selectedLabId.trim();
    if (_resolvedUserId != user.uid ||
        _resolvedLabId != selectedLabId ||
        _labContextFuture == null) {
      _resolvedUserId = user.uid;
      _resolvedLabId = selectedLabId;
      _labContextFuture = widget.appState.resolveAuthenticatedLabContext();
    }

    return _labContextFuture!;
  }

  void _resetLabContextResolution() {
    _resolvedUserId = '';
    _resolvedLabId = '';
    _labContextFuture = null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          return FutureBuilder<bool>(
            key: ValueKey(user.uid),
            future: _resolveLabContextFor(user),
            builder: (context, labSnapshot) {
              if (labSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final hasLabContext = labSnapshot.data ?? false;
              if (hasLabContext) {
                return HomeScreen(appState: widget.appState);
              }

              return LabAccessScreen(appState: widget.appState);
            },
          );
        }

        _resetLabContextResolution();
        return WelcomeScreen(appState: widget.appState);
      },
    );
  }
}
