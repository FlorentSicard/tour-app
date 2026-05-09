import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tourapp/providers/api_provider.dart';
import 'package:tourapp/providers/auth_provider.dart';
import 'package:tourapp/utils/day_completeness.dart';

class HomeTimelineItem {
  final String id;
  final String kind;
  final String title;
  final String? subtitle;
  final DateTime? date;
  final DateTime? endDate;
  final String? tourId;

  const HomeTimelineItem({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle,
    this.date,
    this.endDate,
    this.tourId,
  });
}

final toursProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth.token == null) return [];
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

final dayMissingSectionsProvider = FutureProvider.family<List<String>, String>((ref, dayId) async {
  final dio = ref.read(dioProvider);

  final dayResponse = await dio.get('/days/$dayId');
  final day = Map<String, dynamic>.from(dayResponse.data);

  int scheduleCount = 0;
  if ((day['type'] ?? '').toString() == 'concert') {
    final scheduleResponse = await dio.get('/days/$dayId/schedule/');
    final schedules = List<Map<String, dynamic>>.from(scheduleResponse.data);
    scheduleCount = schedules.length;
  }

  return computeMissingSectionsForDay(day, scheduleCount: scheduleCount);
});

final homeTimelineProvider = FutureProvider<List<HomeTimelineItem>>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth.token == null) return [];

  final dio = ref.read(dioProvider);
  final toursResponse = await dio.get('/tours/');
  final daysResponse = await dio.get('/days/');

  final tours = List<Map<String, dynamic>>.from(toursResponse.data);
  final days = List<Map<String, dynamic>>.from(daysResponse.data);

  final Map<String, DateTime?> earliestTourDate = {};
  final Map<String, DateTime?> latestTourDate = {};
  final List<HomeTimelineItem> items = [];

  for (final day in days) {
    final dayDate = DateTime.tryParse((day['date'] ?? '').toString());
    final dayTourId = day['tour_id']?.toString();

    if (dayTourId != null) {
      final earliest = earliestTourDate[dayTourId];
      if (earliest == null || (dayDate != null && dayDate.isBefore(earliest))) {
        earliestTourDate[dayTourId] = dayDate;
      }

      final latest = latestTourDate[dayTourId];
      if (latest == null || (dayDate != null && dayDate.isAfter(latest))) {
        latestTourDate[dayTourId] = dayDate;
      }
    } else {
      final city = (day['city'] ?? '').toString();
      final venue = (day['venue'] ?? '').toString();
      items.add(
        HomeTimelineItem(
          id: day['id'].toString(),
          kind: 'isolated_day',
          title: 'Date isolée',
          subtitle: [city, venue].where((e) => e.isNotEmpty).join(' • '),
          date: dayDate,
        ),
      );
    }
  }

  for (final tour in tours) {
    final tourId = tour['id'].toString();
    items.add(
      HomeTimelineItem(
        id: tourId,
        kind: 'tour',
        title: (tour['name'] ?? '').toString(),
        subtitle: 'Tournée',
        date: earliestTourDate[tourId],
        endDate: latestTourDate[tourId],
        tourId: tourId,
      ),
    );
  }

  items.sort((a, b) {
    if (a.date == null && b.date == null) {
      final kindCmp = a.kind.compareTo(b.kind);
      return kindCmp != 0 ? kindCmp : a.id.compareTo(b.id);
    }
    if (a.date == null) return 1;
    if (b.date == null) return -1;

    final dateCmp = a.date!.compareTo(b.date!);
    if (dateCmp != 0) return dateCmp;

    final kindCmp = a.kind.compareTo(b.kind);
    return kindCmp != 0 ? kindCmp : a.id.compareTo(b.id);
  });

  return items;
});
