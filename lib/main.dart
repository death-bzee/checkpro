import 'package:flutter/material.dart';

import 'screens/login_screen.dart';

void main() {
  runApp(const CheckProApp());
}

class CheckProApp extends StatelessWidget {
  const CheckProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CheckPro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
