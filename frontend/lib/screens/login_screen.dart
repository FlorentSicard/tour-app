import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tourapp/providers/api_provider.dart';
import 'package:tourapp/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isRegister = false;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      final path = _isRegister ? '/auth/register' : '/auth/login';
      final body = _isRegister
          ? {'name': _nameCtrl.text, 'email': _emailCtrl.text, 'password': _passwordCtrl.text}
          : {'email': _emailCtrl.text, 'password': _passwordCtrl.text};
      final res = await ref.read(dioProvider).post(path, data: body);
      ref.read(authProvider.notifier).setToken(res.data['access_token']);

      final groups = await ref.read(dioProvider).get('/groups/');
      final groupList = List<Map<String, dynamic>>.from(groups.data);
      if (groupList.isNotEmpty) {
        ref.read(authProvider.notifier).setActiveGroup(groupList.first['id']);
      }

      if (mounted) context.go('/home');
    } catch (e) {
      setState(() { _error = 'Authentication failed'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('TourApp', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 32),
                if (_isRegister)
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordCtrl,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isRegister ? 'Register' : 'Login'),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() { _isRegister = !_isRegister; }),
                  child: Text(_isRegister ? 'Already have an account? Login' : 'No account? Register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
