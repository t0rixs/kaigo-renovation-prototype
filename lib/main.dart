import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_state.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RenovationApp());
}

class RenovationApp extends StatefulWidget {
  const RenovationApp({super.key, this.appState});

  final AppState? appState;

  @override
  State<RenovationApp> createState() => _RenovationAppState();
}

class _RenovationAppState extends State<RenovationApp> {
  late final AppState state;

  @override
  void initState() {
    super.initState();
    state = widget.appState ?? AppState();
    state.load();
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1769AA);
    const danger = Color(0xFFC9372C);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: const Color(0xFFF8FAFC),
      error: danger,
    );
    return MaterialApp(
      title: '住宅改修',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF3F5F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF20262C),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF20262C),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: Color(0xFFDCE1E5)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Color(0xFFCDD4DA)),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          height: 68,
          backgroundColor: Colors.white,
          indicatorColor: Color(0xFFDDEEFF),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            minimumSize: const Size(48, 48),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            minimumSize: const Size(48, 46),
          ),
        ),
      ),
      home: AnimatedBuilder(
        animation: state,
        builder: (context, _) =>
            state.isReady ? HomeScreen(state: state) : const _LoadingScreen(),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
