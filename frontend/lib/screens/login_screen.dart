import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tourapp/l10n/app_strings.dart';
import 'package:tourapp/providers/api_provider.dart';
import 'package:tourapp/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  List<Map<String, dynamic>> _groups = const [];
  String? _selectedGroupId;
  bool _isRegisterMode = false;
  bool _loading = false;
  bool _loadingGroups = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String? _extractGroupIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
      return payload['group_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadGroups() async {
    setState(() {
      _loadingGroups = true;
      _error = null;
    });

    try {
      final res = await ref.read(dioProvider).get('/groups/');
      final groups = List<Map<String, dynamic>>.from(res.data);
      setState(() {
        _groups = groups;
        _selectedGroupId = groups.isNotEmpty ? groups.first['id'] as String : null;
      });
    } catch (_) {
      setState(() {
        _error = AppStrings.tr(context, 'auth.unableLoadGroups');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingGroups = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_isRegisterMode) {
      if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
        setState(() {
          _error = AppStrings.tr(context, 'auth.fillAllFields');
        });
        return;
      }

      setState(() {
        _loading = true;
        _error = null;
      });

      try {
        final res = await ref.read(dioProvider).post(
          '/auth/register',
          data: {
            'name': _nameCtrl.text.trim(),
            'email': _emailCtrl.text.trim(),
            'password': _passwordCtrl.text,
          },
        );

        final token = res.data['access_token'] as String;
        final groupId = _extractGroupIdFromToken(token);
        if (groupId == null) {
          throw Exception('Missing group_id in token');
        }

        ref.read(authProvider.notifier).setSession(token: token, selectedGroupId: groupId);
        if (mounted) context.go('/home');
      } catch (_) {
        setState(() {
          _error = AppStrings.tr(context, 'auth.registerFailed');
        });
      } finally {
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
      }
      return;
    }

    if (_selectedGroupId == null) {
      setState(() {
        _error = AppStrings.tr(context, 'auth.selectGroup');
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ref.read(dioProvider).post(
        '/auth/login',
        data: {
          'group_id': _selectedGroupId,
          'password': _passwordCtrl.text,
        },
      );
      ref.read(authProvider.notifier).setSession(
            token: res.data['access_token'],
            selectedGroupId: _selectedGroupId!,
          );

      if (mounted) context.go('/home');
    } catch (_) {
      setState(() {
        _error = AppStrings.tr(context, 'auth.authFailed');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Widget _fieldHelp(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: Colors.grey[600],
              ),
        ),
      ),
    );
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
                if (_isRegisterMode)
                  Column(
                    children: [
                      TextField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(labelText: AppStrings.tr(context, 'auth.groupName')),
                      ),
                      _fieldHelp(context, AppStrings.tr(context, 'auth.groupNameHelp')),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailCtrl,
                        decoration: InputDecoration(labelText: AppStrings.tr(context, 'auth.email')),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      _fieldHelp(context, AppStrings.tr(context, 'auth.emailHelp')),
                    ],
                  )
                else if (_loadingGroups)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: _selectedGroupId,
                    decoration: InputDecoration(labelText: AppStrings.tr(context, 'auth.group')),
                    items: _groups
                        .map(
                          (g) => DropdownMenuItem<String>(
                            value: g['id'] as String,
                            child: Text((g['name'] ?? '') as String),
                          ),
                        )
                        .toList(),
                    onChanged: _loading
                        ? null
                        : (value) {
                            setState(() {
                              _selectedGroupId = value;
                            });
                          },
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordCtrl,
                  decoration: InputDecoration(labelText: AppStrings.tr(context, 'auth.password')),
                  obscureText: true,
                ),
                if (_isRegisterMode) _fieldHelp(context, AppStrings.tr(context, 'auth.passwordHelp')),
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: (_loading || (!_isRegisterMode && (_loadingGroups || _groups.isEmpty)))
                        ? null
                        : _submit,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_isRegisterMode ? AppStrings.tr(context, 'auth.register') : AppStrings.tr(context, 'auth.login')),
                  ),
                ),
                if (!_isRegisterMode && !_loadingGroups && _groups.isEmpty)
                  TextButton(
                    onPressed: _loadGroups,
                    child: Text(AppStrings.tr(context, 'auth.retryLoadGroups')),
                  ),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() {
                            _error = null;
                            _isRegisterMode = !_isRegisterMode;
                          });
                        },
                  child: Text(
                    _isRegisterMode
                        ? AppStrings.tr(context, 'auth.alreadyRegistered')
                        : AppStrings.tr(context, 'auth.needAccount'),
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
