import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/quest_controller.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => QuestController()..init()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const VertUpApp(),
    ),
  );
}

class VertUpApp extends StatelessWidget {
  const VertUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    
    Color seed = const Color(0xFF7CFFB2);
    Color scaffoldBg = const Color(0xFF121212);
    Color cardBg = const Color(0xFF1E1E1E);

    if (settings.currentTheme == 'dark_sunset') {
      seed = const Color(0xFFFF6B9A);
    } else if (settings.currentTheme == 'dark_chocolate') {
      seed = const Color(0xFFD7CCC8);
      scaffoldBg = const Color(0xFF2D221E);
      cardBg = const Color(0xFF3E312C);
    } else if (settings.currentTheme == 'dark_neon') {
      seed = const Color(0xFF00E5FF);
      scaffoldBg = const Color(0xFF0A0E17);
      cardBg = const Color(0xFF141A29);
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VertUp',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: scaffoldBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
          surface: cardBg,
          primary: seed,
          secondary: seed.withValues(alpha: 0.7),
        ),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1.1),
          headlineMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.8),
          titleLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4),
          titleMedium: TextStyle(fontWeight: FontWeight.w700),
          bodyMedium: TextStyle(height: 1.35),
        ),
        cardTheme: CardThemeData(
          color: cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: scaffoldBg.withValues(alpha: 0.5),
          indicatorColor: seed.withValues(alpha: 0.16),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return const VertUpHome();
          }
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signInAnonymously();
                },
                child: const Text("Войти анонимно (Тест)"),
              ),
            ),
          );
        },
      ),
    );
  }
}