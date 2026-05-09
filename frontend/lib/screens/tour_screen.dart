import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:tourapp/l10n/app_strings.dart';
import 'package:tourapp/providers/api_provider.dart';
import 'package:tourapp/providers/tour_providers.dart';
import 'package:tourapp/utils/day_completeness.dart';
import 'package:tourapp/utils/file_download.dart';
import 'package:tourapp/widgets/missing_badge.dart';
import 'dart:typed_data';

class TourScreen extends ConsumerWidget {
  final String tourId;
  const TourScreen({super.key, required this.tourId});

  String? _resolveTourName(List<Map<String, dynamic>> tours) {
    for (final tour in tours) {
      if (tour['id']?.toString() == tourId) {
        final name = (tour['name'] ?? '').toString().trim();
        return name.isEmpty ? null : name;
      }
    }
    return null;
  }

  Future<void> _exportTourPdf(BuildContext context, WidgetRef ref) async {
    try {
      final response = await ref.read(dioProvider).get<List<int>>(
            '/tours/$tourId/export/full',
            options: Options(responseType: ResponseType.bytes),
          );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Empty PDF response');
      }

      final disposition = response.headers.value('content-disposition') ?? '';
      final match = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
      final filename = match?.group(1) ?? 'tour-export.pdf';

      downloadBytes(Uint8List.fromList(bytes), filename);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.tr(context, 'tour.exported')}: $filename')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.tr(context, 'tour.exportFailed')}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(daysProvider(tourId));
    final tours = ref.watch(toursProvider);
    final tourName = tours.asData == null ? null : _resolveTourName(tours.asData!.value);

    return Scaffold(
      appBar: AppBar(
        title: Text(tourName ?? AppStrings.tr(context, 'tour.days')),
        actions: [
          IconButton(
            tooltip: AppStrings.tr(context, 'tour.exportPdfTooltip'),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => _exportTourPdf(context, ref),
          ),
        ],
      ),
      body: days.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${AppStrings.tr(context, 'common.error')}: $e')),
        data: (list) => list.isEmpty
            ? Center(child: Text(AppStrings.tr(context, 'tour.noDays')))
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final day = list[i];
                  final type = day['type'] == 'concert' ? AppStrings.tr(context, 'tour.concert') : AppStrings.tr(context, 'tour.dayOff');
                  final dayId = day['id'].toString();
                  final missingAsync = ref.watch(dayMissingSectionsProvider(dayId));

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Stack(
                      children: [
                        ListTile(
                          title: Text('${day['date']} - $type'),
                          subtitle: Text([day['city'], day['venue']].where((s) => s != null).join(' - ')),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/days/${day['id']}'),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: missingAsync.when(
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (missing) {
                              if (missing.isEmpty) return const SizedBox.shrink();
                              return MissingBadge(
                                tooltip: missingSectionsTooltip(context, missing),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showCreateDayDialog(context, ref),
      ),
    );
  }

  void _showCreateDayDialog(BuildContext context, WidgetRef ref) {
    final cityCtrl = TextEditingController();
    final venueCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedType = 'concert';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(AppStrings.tr(context, 'tour.newDay')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(selectedDate.toIso8601String().split('T').first),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => selectedDate = picked);
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: InputDecoration(labelText: AppStrings.tr(context, 'tour.type')),
                items: [
                  DropdownMenuItem(value: 'concert', child: Text(AppStrings.tr(context, 'tour.concert'))),
                  DropdownMenuItem(value: 'day_off', child: Text(AppStrings.tr(context, 'tour.dayOff'))),
                ],
                onChanged: (value) => setState(() => selectedType = value ?? 'concert'),
              ),
              const SizedBox(height: 8),
              if (selectedType == 'concert') ...[
                TextField(controller: cityCtrl, decoration: InputDecoration(labelText: AppStrings.tr(context, 'home.city'))),
                const SizedBox(height: 8),
                TextField(controller: venueCtrl, decoration: InputDecoration(labelText: AppStrings.tr(context, 'home.venue'))),
                const SizedBox(height: 8),
                TextField(controller: addressCtrl, decoration: InputDecoration(labelText: AppStrings.tr(context, 'day.address'))),
              ] else ...[
                TextField(
                  controller: noteCtrl,
                  maxLength: 3000,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(labelText: AppStrings.tr(context, 'tour.note')),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(AppStrings.tr(context, 'common.cancel'))),
            FilledButton(
              onPressed: () async {
                if (selectedType == 'concert' && addressCtrl.text.trim().isEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppStrings.tr(context, 'day.addressRequired'))),
                    );
                  }
                  return;
                }
                await ref.read(dioProvider).post('/days/', data: {
                  'tour_id': tourId,
                  'date': selectedDate.toIso8601String().split('T').first,
                  'type': selectedType,
                  'city': selectedType == 'concert' ? (cityCtrl.text.trim().isEmpty ? null : cityCtrl.text.trim()) : null,
                  'venue': selectedType == 'concert' ? (venueCtrl.text.trim().isEmpty ? null : venueCtrl.text.trim()) : null,
                  'address': selectedType == 'concert' ? addressCtrl.text.trim() : null,
                  'day_note': selectedType == 'day_off' ? (noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim()) : null,
                });
                ref.invalidate(daysProvider(tourId));
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(AppStrings.tr(context, 'common.create')),
            ),
          ],
        ),
      ),
    );
  }
}
