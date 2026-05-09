import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tourapp/providers/api_provider.dart';

class AuthState {
  final String? token;
  final String? selectedGroupId;

  const AuthState({this.token, this.selectedGroupId});

  bool get isAuthenticated => token != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  void setSession({required String token, required String selectedGroupId}) {
    state = AuthState(token: token, selectedGroupId: selectedGroupId);
    authToken = token;
  }

  void logout() {
    state = const AuthState();
    authToken = null;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
