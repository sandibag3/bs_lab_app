import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'auth_gate.dart';
import 'app_state.dart';
import 'firebase_options.dart';

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
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            fontFamily: 'Roboto',
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF14B8A6),
              secondary: Color(0xFF38BDF8),
              surface: Color(0xFF1E293B),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
          ),
          home: AuthGate(appState: appState),
        );
      },
    );
  }
}
