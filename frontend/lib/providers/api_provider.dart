import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String baseUrl = 'http://localhost:8000';

String? authToken;

final dio = Dio(BaseOptions(baseUrl: baseUrl))
  ..interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      if (authToken != null) {
        options.headers['Authorization'] = 'Bearer $authToken';
      }
      handler.next(options);
    },
  ));

final dioProvider = Provider<Dio>((ref) => dio);
