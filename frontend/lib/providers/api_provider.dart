import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tourapp/providers/auth_provider.dart';

const String baseUrl = 'http://localhost:8000';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(baseUrl: baseUrl));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final auth = ref.read(authProvider);
      if (auth.token != null) {
        options.headers['Authorization'] = 'Bearer ${auth.token}';
      }
      if (auth.activeGroupId != null) {
        options.headers['X-Group-ID'] = auth.activeGroupId;
      }
      handler.next(options);
    },
  ));

  return dio;
});
