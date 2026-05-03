import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthState {
  final String? token;
  final String? activeGroupId;

  const AuthState({this.token, this.activeGroupId});

  AuthState copyWith({String? token, String? activeGroupId}) {
    return AuthState(
      token: token ?? this.token,
      activeGroupId: activeGroupId ?? this.activeGroupId,
    );
  }

  bool get isAuthenticated => token != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  void setToken(String token) => state = state.copyWith(token: token);
  void setActiveGroup(String groupId) => state = state.copyWith(activeGroupId: groupId);
  void logout() => state = const AuthState();
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
