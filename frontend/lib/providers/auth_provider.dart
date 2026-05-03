import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tourapp/providers/api_provider.dart';

class AuthState {
  final String? token;
  final String? activeGroupId;

  const AuthState({this.token, this.activeGroupId});

  bool get isAuthenticated => token != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  void setToken(String token) {
    state = AuthState(token: token, activeGroupId: state.activeGroupId);
    authToken = token;
  }

  void setActiveGroup(String groupId) {
    state = AuthState(token: state.token, activeGroupId: groupId);
    activeGroupId = groupId;
  }

  void logout() {
    state = const AuthState();
    authToken = null;
    activeGroupId = null;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
