import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/auth_models.dart';

const String _defaultApiBase = String.fromEnvironment(
  'CHECKPRO_API_BASE',
  defaultValue: 'https://api.checkpro.kz',
);

abstract class AuthServiceBase {
  String? get accessToken;
  String? get currentEmail;
  String get apiBase;

  Future<AuthToken> login({
    required String identifier,
    required String password,
  });

  Future<void> register({
    required String username,
    required String fullName,
    required String email,
    String? phone,
    required String iin,
    required String password,
  });

  Future<void> requestEmailVerification(String email);

  Future<void> confirmEmail({
    required String email,
    required String code,
  });

  Future<UserProfile> me();

  String errorMessage(http.Response response);
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthService implements AuthServiceBase {
  AuthService({http.Client? client, String? apiBase})
    : _client = client ?? http.Client(),
      _apiBase = apiBase ?? _defaultApiBase;

  final http.Client _client;
  final String _apiBase;
  String? _accessToken;
  String? _email;
  UserProfile? _profile;

  Uri _uri(String path) => Uri.parse('$_apiBase$path');

  @override
  String? get accessToken => _accessToken;

  @override
  String? get currentEmail => _email;

  @override
  String get apiBase => _apiBase;

  @override
  Future<AuthToken> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _client.post(
      _uri('/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier, 'password': password}),
    );

    if (kDebugMode) {
      debugPrint(
        'AuthService.login -> ${response.statusCode}: ${response.body}',
      );
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = AuthToken.fromJson(data);
      _accessToken = token.accessToken;
      _email = identifier;
      _profile = null;
      return token;
    }

    throw AuthException(errorMessage(response));
  }

  @override
  Future<void> register({
    required String username,
    required String fullName,
    required String email,
    String? phone,
    required String iin,
    required String password,
  }) async {
    final payload = <String, dynamic>{
      'username': username,
      'full_username': fullName,
      'email': email,
      'iin': iin,
      'password': password,
    };
    if (phone != null && phone.trim().isNotEmpty) {
      payload['phone'] = phone.trim();
    }

    final response = await _client.post(
      _uri('/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (kDebugMode) {
      debugPrint(
        'AuthService.register -> ${response.statusCode}: ${response.body}',
      );
    }
    if (response.statusCode == 201) {
      return;
    }

    throw AuthException(errorMessage(response));
  }

  @override
  Future<void> requestEmailVerification(String email) async {
    final response = await _client.post(
      _uri('/auth/verify-email/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (kDebugMode) {
      debugPrint(
        'AuthService.requestEmailVerification -> ${response.statusCode}: ${response.body}',
      );
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw AuthException(errorMessage(response));
  }

  @override
  Future<void> confirmEmail({
    required String email,
    required String code,
  }) async {
    final response = await _client.post(
      _uri('/auth/verify-email/confirm'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );

    if (kDebugMode) {
      debugPrint(
        'AuthService.confirmEmail -> ${response.statusCode}: ${response.body}',
      );
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw AuthException(errorMessage(response));
  }

  @override
  Future<UserProfile> me() async {
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      throw AuthException('Необходима авторизация');
    }

    final response = await _client.get(
      _uri('/auth/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'Cookie': 'access_token=$token',
      },
    );

    if (kDebugMode) {
      debugPrint('AuthService.me -> ${response.statusCode}: ${response.body}');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      _profile = UserProfile.fromJson(data);
      return _profile!;
    }

    throw AuthException(errorMessage(response));
  }

  @override
  String errorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
    } catch (_) {
      // ignore JSON errors
    }
    return kDebugMode
        ? 'Ошибка ${response.statusCode}: ${response.reasonPhrase}'
        : 'Что-то пошло не так. Попробуйте ещё раз';
  }
}

AuthServiceBase authService = AuthService();
