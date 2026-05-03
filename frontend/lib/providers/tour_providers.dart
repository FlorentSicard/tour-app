import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tourapp/providers/api_provider.dart';

final toursProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/tours/');
  return List<Map<String, dynamic>>.from(response.data);
});

final daysProvider = FutureProvider.family<List<Map<String, dynamic>>, String?>((ref, tourId) async {
  final dio = ref.read(dioProvider);
  final query = tourId != null ? '?tour_id=$tourId' : '';
  final response = await dio.get('/days/$query');
  return List<Map<String, dynamic>>.from(response.data);
});

final dayDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, dayId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/days/$dayId');
  return Map<String, dynamic>.from(response.data);
});

final scheduleProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, dayId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/days/$dayId/schedule/');
  return List<Map<String, dynamic>>.from(response.data);
});

final checklistProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, dayId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/days/$dayId/checklist');
  return List<Map<String, dynamic>>.from(response.data);
});
