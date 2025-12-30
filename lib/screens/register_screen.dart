import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _iinController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _acceptPolicy = false;
  bool _isSubmitting = false;
  String? _policyError;
  String? _errorText;

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _iinController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    if (!_acceptPolicy) {
      setState(() => _policyError = 'Подтвердите согласие с условиями.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _policyError = null;
      _errorText = null;
    });

    final trimmedEmail = _emailController.text.trim();
    try {
      // нормализуем телефон до +7XXXXXXXXXX
      String? phone;
      final phoneDigits = _digits(_phoneController.text);
      if (phoneDigits.isNotEmpty) {
        final normalized = _normalizePhone(phoneDigits);
        if (normalized == null) {
          setState(() {
            _errorText = 'Введите корректный номер телефона: +7 (XXX) XXX-XX-XX';
          });
          return;
        }
        phone = normalized;
      }

      await authService.register(
        username: _usernameController.text.trim(),
        fullName: _nameController.text.trim(),
        email: trimmedEmail,
        phone: phone,
        iin: _iinController.text.trim(),
        password: _passwordController.text,
      );
      try {
        await authService.requestEmailVerification(trimmedEmail);
      } catch (_) {
        // код уже создан — повторное письмо необязательно
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(email: trimmedEmail),
        ),
      );
    } on AuthException catch (error) {
      setState(() => _errorText = error.message);
    } catch (error) {
      setState(() {
        _errorText = kDebugMode
            ? 'Ошибка: $error'
            : 'Не удалось создать аккаунт. Попробуйте ещё раз.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final headline = Theme.of(
      context,
    ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold);

    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Присоединяйтесь к CheckPro', style: headline),
                      const SizedBox(height: 8),
                      Text(
                        'Создайте рабочий аккаунт для отслеживания проверок и инспекций.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Логин (латиница)',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return 'Придумайте логин';
                          }
                          final regex = RegExp(r'^[a-zA-Z0-9_.-]{3,}$');

                          if (!regex.hasMatch(trimmed)) {
                            return 'Используйте латиницу и цифры (мин. 3)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'ФИО',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().length < 3) {
                            return 'Введите имя полностью';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Рабочая почта',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return 'Укажите email';
                          }
                          if (!trimmed.contains('@')) {
                            return 'Нужен корректный email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Телефон (опционально)',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [_KzPhoneFormatter()],
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _iinController,
                        decoration: const InputDecoration(
                          labelText: 'ИИН',
                          prefixIcon: Icon(Icons.badge),
                        ),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(12),
                        ],
                        validator: (value) {
                          final digits = _digits(value ?? '');
                          if (digits.length != 12) {
                            return 'ИИН должен содержать 12 цифр';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Пароль',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().length < 6) {
                            return 'Минимум 6 символов';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Повторите пароль',
                          prefixIcon: Icon(Icons.lock_reset),
                        ),
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Повторите пароль';
                          }
                          if (value != _passwordController.text) {
                            return 'Пароли не совпадают';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _acceptPolicy,
                        onChanged: (value) => setState(() {
                          _acceptPolicy = value ?? false;
                          if (_acceptPolicy) {
                            _policyError = null;
                          }
                        }),
                        title: const Text(
                          'Я согласен с политикой обработки данных и правилами использования',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      if (_policyError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _policyError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      if (_errorText != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _errorText!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isSubmitting ? null : _submit,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              _isSubmitting ? 'Создаём…' : 'Зарегистрироваться',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).maybePop(),
                          child: const Text('У меня уже есть аккаунт'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _digits(String input) => input.replaceAll(RegExp(r'\D'), '');

// Превращает набор цифр в телефон вида +7XXXXXXXXXX или возвращает null
String? _normalizePhone(String digits) {
  if (digits.isEmpty) return null;
  var d = digits;
  if (d.startsWith('8')) {
    d = '7${d.substring(1)}';
  }
  if (!d.startsWith('7')) {
    d = '7$d';
  }
  if (d.length > 11) {
    d = d.substring(0, 11);
  }
  if (d.length != 11) {
    return null;
  }
  return '+$d';
}

class _KzPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = _digits(newValue.text);
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    if (digits.startsWith('8')) {
      digits = '7${digits.substring(1)}';
    } else if (!digits.startsWith('7')) {
      digits = '7$digits';
    }
    if (digits.length > 11) {
      digits = digits.substring(0, 11);
    }

    final formatted = _formatPhone(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String _formatPhone(String normalizedDigits) {
  // normalizedDigits: всегда начинается с 7, длина <= 11
  final rest = normalizedDigits.length > 1 ? normalizedDigits.substring(1) : '';
  final buf = StringBuffer('+7');
  if (rest.isNotEmpty) {
    buf.write(' (');
    buf.write(rest.substring(0, min(3, rest.length)));
    if (rest.length >= 3) buf.write(')');
  }
  if (rest.length > 3) {
    buf.write(' ');
    buf.write(rest.substring(3, min(6, rest.length)));
  }
  if (rest.length > 6) {
    buf.write('-');
    buf.write(rest.substring(6, min(8, rest.length)));
  }
  if (rest.length > 8) {
    buf.write('-');
    buf.write(rest.substring(8, min(10, rest.length)));
  }
  return buf.toString();
}
