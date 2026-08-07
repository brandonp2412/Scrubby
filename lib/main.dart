import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'core/app_state.dart';
import 'core/notifications.dart';
import 'screens/dashboard_shell.dart';
import 'screens/login_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalVacuumNotificationPresenter.instance.initialize();
  await configureBackgroundNotificationService();
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
  late final _LifecycleObserver _lifecycleObserver;

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = _LifecycleObserver(state);
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    state.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
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
          child: !state.isInitialized
              ? const _StartupScreen(key: ValueKey('startup'))
              : state.vacuums.isEmpty
              ? LoginScreen(key: const ValueKey('login'), state: state)
              : DashboardShell(key: const ValueKey('home'), state: state),
        ),
      ),
    );
  }
}

class _LifecycleObserver extends WidgetsBindingObserver {
  _LifecycleObserver(this.state);

  final AppState state;

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.paused) {
      state.enterBackground();
    } else if (lifecycleState == AppLifecycleState.resumed) {
      state.enterForeground();
    }
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.vacuum_2, size: 48, color: fern),
            SizedBox(height: 24),
            SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
