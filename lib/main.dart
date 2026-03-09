import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/upload/image_upload_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider()..checkLoginStatus(),
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
      theme: ThemeData.dark(),
      home: const AuthGate(),
      routes: {
        '/home': (_) => const Scaffold(body: Center(child: Text('홈 화면'))),
        '/upload': (_) => const ImageUploadScreen(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return auth.isLoggedIn ? const Scaffold(body: Center(child: Text('홈 화면'))) : const LoginScreen();
  }
}