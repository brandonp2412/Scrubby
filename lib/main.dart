import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_state.dart';
import 'screens/dashboard_shell.dart';
import 'screens/login_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  runApp(const ScrubbyApp());
}

class ScrubbyApp extends StatefulWidget {
  const ScrubbyApp({super.key});

  @override
  State<ScrubbyApp> createState() => _ScrubbyAppState();
}

class _ScrubbyAppState extends State<ScrubbyApp> {
  final state = AppState();

  @override
  void initState() {
    super.initState();
    state.initialize();
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scrubby',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: state,
        builder: (context, _) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          child: state.vacuums.isEmpty
              ? LoginScreen(key: const ValueKey('login'), state: state)
              : DashboardShell(key: const ValueKey('home'), state: state),
        ),
      ),
    );
  }
}
