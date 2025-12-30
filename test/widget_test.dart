// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:checkpro/main.dart';
import 'package:checkpro/models/auth_models.dart';
import 'package:checkpro/services/auth_service.dart';

class FakeAuthService implements AuthServiceBase {
  @override
  String? get accessToken => null;

  @override
  String? get currentEmail => null;

  @override
  String get apiBase => 'http://example.com';

  @override
  Future<AuthToken> login({
    required String identifier,
    required String password,
  }) async {
    return const AuthToken(accessToken: 'token', expiresIn: 3600);
  }

  @override
  Future<void> register({
    required String username,
    required String fullName,
    required String email,
    String? phone,
    required String iin,
    required String password,
  }) async {}

  @override
  Future<void> requestEmailVerification(String email) async {}

  @override
  Future<void> confirmEmail({required String email, required String code}) async {}

  @override
  Future<UserProfile> me() async => const UserProfile(
        id: '1',
        username: 'demo',
        fullName: 'Demo User',
        email: 'demo@example.com',
        role: 'installer',
      );

  @override
  String errorMessage(response) => 'error';
}

void main() {
  setUp(() {
    authService = FakeAuthService();
  });

  testWidgets('Login form leads to dashboard', (tester) async {
    await tester.pumpWidget(const CheckProApp());

    expect(find.text('CheckPro'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Рабочая почта'),
      'safety@checkpro.io',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Пароль'),
      'secure123',
    );

    await tester.tap(find.text('Войти в систему'));
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.textContaining('Привет'), findsOneWidget);
  });
}
