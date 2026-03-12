// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/home/conversation_provider.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkLoginStatus()),
        ChangeNotifierProvider(create: (_) => ConversationProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '미리톡 사기 방지 시스템',
      theme: ThemeData.dark().copyWith(
        textTheme: GoogleFonts.notoSansKrTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return auth.isLoggedIn ? const HomeScreen() : const LoginScreen();
  }
}