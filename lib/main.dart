import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'auth_gate.dart';
import 'app_state.dart';
import 'firebase_options.dart';
import 'theme/labmate_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final appState = AppState();
  await appState.loadProfile();

  runApp(BSLabApp(appState: appState));
}

class BSLabApp extends StatelessWidget {
  final AppState appState;

  const BSLabApp({
    super.key,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Labmate',
          themeMode: appState.themeMode,
          theme: LabmateTheme.light,
          darkTheme: LabmateTheme.dark,
          home: AuthGate(appState: appState),
        );
      },
    );
  }
}
