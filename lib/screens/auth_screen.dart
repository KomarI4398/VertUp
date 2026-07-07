import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoginMode = true;
  bool _isLoading = false;

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (_isLoginMode) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Произошла ошибка';
      if (e.code == 'weak-password') {
        errorMessage = 'Пароль слишком слабый (минимум 6 символов).';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'Этот Email уже зарегистрирован.';
      } else if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        errorMessage = 'Неверная почта или пароль.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Используем SettingsProvider для локализации текстов ссылок
    final settings = context.watch<SettingsProvider>();
    // Берём цвета из текущей ThemeData, настроенной в main.dart
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // Авто-фон из темы
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isLoginMode 
                      ? settings.translate('Рады видеть!', 'Welcome back!') 
                      : settings.translate('Создать аккаунт', 'Create account'),
                  style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                // Поле Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: const TextStyle(color: Colors.grey),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.primary)),
                  ),
                  validator: (value) => (value == null || !value.contains('@')) ? 'Введи корректный Email' : null,
                ),
                const SizedBox(height: 20),
                // Поле Пароля
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: settings.translate('Пароль', 'Password'),
                    labelStyle: const TextStyle(color: Colors.grey),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.primary)),
                  ),
                  validator: (value) => (value == null || value.length < 6) ? 'Минимум 6 символов' : null,
                ),
                const SizedBox(height: 40),
                // Кнопка
                _isLoading
                    ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                    : ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          _isLoginMode 
                              ? settings.translate('Войти', 'Sign In') 
                              : settings.translate('Регистрация', 'Sign Up'), 
                          style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                const SizedBox(height: 20),
                // Ссылка переключения
                TextButton(
                  onPressed: () {
                    setState(() => _isLoginMode = !_isLoginMode);
                  },
                  child: Text(
                    _isLoginMode 
                        ? settings.translate('Ещё нет аккаунта? Создать', 'Don\'t have an account? Sign Up') 
                        : settings.translate('Уже есть аккаунт? Войти', 'Already have an account? Sign In'),
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}