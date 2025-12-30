import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import 'project_list_screen.dart';
import 'register_screen.dart';
import 'verify_email_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authLocal = LocalAuthentication();
  final _secureStorage = const FlutterSecureStorage();
  bool _rememberMe = true;
  bool _isSubmitting = false;
  bool _biometricAvailable = false;
  bool _hasStoredCreds = false;
  bool _hasPin = false;
  String? _flashMessage;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _initBiometric();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptQuickEntry());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initBiometric() async {
    try {
      final canCheck = await _authLocal.canCheckBiometrics;
      final supported = await _authLocal.isDeviceSupported();
      final storedEmail = await _secureStorage.read(key: 'quick_email');
      final storedPass = await _secureStorage.read(key: 'quick_password');
      final storedPin = await _secureStorage.read(key: 'quick_pin');
      setState(() {
        _biometricAvailable = canCheck && supported;
        _hasStoredCreds = (storedEmail != null && storedPass != null);
        _hasPin = storedPin != null;
        if (storedEmail != null) {
          _emailController.text = storedEmail;
        }
        if (storedPass != null) {
          _passwordController.text = storedPass;
        }
      });
      if (_hasStoredCreds) {
        _maybePromptQuickEntry();
      }
    } catch (_) {
      setState(() {
        _biometricAvailable = false;
        _hasStoredCreds = false;
      });
    }
  }

  Future<void> _openRegister() async {
    if (_isSubmitting) {
      return;
    }
    final result = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const RegisterScreen()));
    if (result != null && mounted) {
      setState(() => _flashMessage = result);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(result)));
    }
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _flashMessage = null;
      _errorText = null;
    });
    try {
      await authService.login(
        identifier: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await _storeQuickCredentials();
      await authService.me();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const ProjectListScreen(),
        ),
      );
    } on AuthException catch (error) {
      setState(() => _errorText = error.message);
    } catch (_) {
      setState(() => _errorText = 'Не удалось войти. Попробуйте ещё раз');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _storeQuickCredentials() async {
    // храним даже без биометрии — для быстрого входа
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;
    try {
      await _secureStorage.write(key: 'quick_email', value: email);
      await _secureStorage.write(key: 'quick_password', value: password);
      setState(() {
        _hasStoredCreds = true;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _quickLogin({bool forcePin = false}) async {
    if (!_hasStoredCreds) return;
    try {
      var unlocked = true;
      if (_biometricAvailable && !forcePin) {
        unlocked = await _authLocal.authenticate(
          localizedReason: 'Войдите по Face/Touch ID или короткому коду',
          biometricOnly: true,
        );
      }
      if (!unlocked && _hasPin) {
        unlocked = await _verifyPin();
      }
      if (!unlocked) return;
      if (_hasPin && (!_biometricAvailable || forcePin)) {
        final ok = await _verifyPin();
        if (!ok) return;
      }
      final email = await _secureStorage.read(key: 'quick_email') ?? '';
      final password = await _secureStorage.read(key: 'quick_password') ?? '';
      if (email.isEmpty || password.isEmpty) {
        setState(() => _errorText = 'Нет сохранённых данных для быстрого входа');
        return;
      }
      setState(() {
        _isSubmitting = true;
        _errorText = null;
      });
      await authService.login(identifier: email, password: password);
      await authService.me();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ProjectListScreen()),
      );
    } on PlatformException catch (e) {
      // если биометрия недоступна, пробуем код
      if (_hasPin) {
        final ok = await _verifyPin();
        if (ok) {
          return _quickLogin(forcePin: true);
        }
      }
      setState(() => _errorText = 'Быстрый вход не выполнен: ${e.message ?? e.code}');
    } catch (e) {
      setState(() => _errorText = 'Быстрый вход не выполнен: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _maybePromptQuickEntry() async {
    if (!_hasStoredCreds || _isSubmitting) return;
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Быстрый вход',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                'Войдите по биометрии или короткому коду. Можно пропустить и ввести пароль вручную.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (_biometricAvailable)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _quickLogin();
                  },
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Face/Touch ID'),
                ),
              if (_biometricAvailable) const SizedBox(height: 10),
              if (_hasPin)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _quickLogin(forcePin: true);
                  },
                  icon: const Icon(Icons.key_outlined),
                  label: const Text('Войти по коду'),
                ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Пропустить'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _configurePin() async {
    if (!_hasStoredCreds &&
        (_emailController.text.trim().isEmpty ||
            _passwordController.text.isEmpty)) {
      setState(() => _errorText = 'Сначала введите логин и пароль');
      return;
    }
    final pin = await _askPin(forSetup: true);
    if (pin == null) return;
    final hash = _hashPin(pin);
    await _secureStorage.write(key: 'quick_pin', value: hash);
    setState(() => _hasPin = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Короткий код сохранён')),
      );
    }
  }

  Future<bool> _verifyPin() async {
    final saved = await _secureStorage.read(key: 'quick_pin');
    if (saved == null) return false;
    final pin = await _askPin(forSetup: false);
    if (pin == null) return false;
    final isValid = _hashPin(pin) == saved;
    if (!isValid && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Неверный короткий код')),
      );
    }
    return isValid;
  }

  Future<String?> _askPin({required bool forSetup}) async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(forSetup ? 'Задайте короткий код' : 'Введите код'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: '4 цифры',
                  counterText: '',
                ),
              ),
              if (forSetup) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Повторите код',
                    counterText: '',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final pin = controller.text.trim();
                if (pin.length != 4) return;
                if (forSetup && pin != confirmController.text.trim()) {
                  return;
                }
                Navigator.of(context).pop(pin);
              },
              child: Text(forSetup ? 'Сохранить' : 'Готово'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    confirmController.dispose();
    return result;
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_flashMessage != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _flashMessage!,
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      Text(
                        'CheckPro',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Контроль проверок и инспекций в одном приложении',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (_errorText != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _errorText!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Рабочая почта',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Введите email';
                          }
                          if (!value.contains('@')) {
                            return 'Укажите корректный email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Пароль',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) {
                          if (value == null || value.trim().length < 6) {
                            return 'Минимум 6 символов';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch.adaptive(
                                value: _rememberMe,
                                onChanged: (value) =>
                                    setState(() => _rememberMe = value),
                              ),
                              const SizedBox(width: 8),
                              const Text('Запомнить меня'),
                            ],
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text('Забыли пароль?'),
                          ),
                          TextButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => VerifyEmailScreen(
                                          email: _emailController.text.trim(),
                                        ),
                                      ),
                                    ),
                            child: const Text('Подтвердить email'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward_rounded),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              _isSubmitting ? 'Входим…' : 'Войти в систему',
                            ),
                          ),
                          onPressed: _isSubmitting ? null : _submit,
                        ),
                      ),
                      if (_hasStoredCreds) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: Icon(
                              _biometricAvailable
                                  ? Icons.fingerprint
                                  : Icons.lock_open_outlined,
                            ),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('Быстрый вход'),
                            ),
                            onPressed: _isSubmitting ? null : _quickLogin,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                icon: const Icon(Icons.key_outlined),
                                onPressed: _isSubmitting ? null : _configurePin,
                                label: Text(_hasPin
                                    ? 'Изменить короткий код'
                                    : 'Задать короткий код'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_hasPin)
                              Expanded(
                                child: TextButton.icon(
                                  icon: const Icon(Icons.shield_outlined),
                                  onPressed: _isSubmitting
                                      ? null
                                      : () => _quickLogin(forcePin: true),
                                  label: const Text('Войти по коду'),
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.person_add_alt_1_outlined),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Создать аккаунт'),
                          ),
                          onPressed: _isSubmitting ? null : _openRegister,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Text(
                            'Нет аккаунта?',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          TextButton(
                            onPressed: _openRegister,
                            child: const Text('Зарегистрируйтесь'),
                          ),
                        ],
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
