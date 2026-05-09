import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:tourapp/l10n/app_strings.dart';
import 'package:tourapp/providers/api_provider.dart';
import 'package:tourapp/providers/tour_providers.dart';
import 'package:tourapp/utils/day_completeness.dart';
import 'package:tourapp/utils/file_download.dart';
import 'package:tourapp/widgets/missing_badge.dart';
import 'dart:typed_data';

class DayScreen extends ConsumerWidget {
  final String dayId;
  const DayScreen({super.key, required this.dayId});

  String _visibilityDescription(BuildContext context, String visibility) {
    return visibility == 'public'
        ? AppStrings.tr(context, 'day.visibilityPublicHelp')
        : AppStrings.tr(context, 'day.visibilityPrivateHelp');
  }

  Future<void> _patchDay(BuildContext context, WidgetRef ref, Map<String, dynamic> data) async {
    await ref.read(dioProvider).patch('/days/$dayId', data: data);
    ref.invalidate(dayDetailProvider(dayId));
  }

  Future<void> _showFreeTextEditor(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String field,
    required String? initialValue,
    int maxLength = 3000,
  }) async {
    final ctrl = TextEditingController(text: initialValue ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          minLines: 4,
          maxLines: 8,
          maxLength: maxLength,
          decoration: InputDecoration(labelText: title, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.tr(context, 'common.cancel'))),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.length > maxLength) return;
              final normalized = ctrl.text.trim();
              await ref.read(dioProvider).patch('/days/$dayId', data: {
                field: normalized.isEmpty ? null : normalized,
              });
              ref.invalidate(dayDetailProvider(dayId));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(AppStrings.tr(context, 'common.save')),
          ),
        ],
      ),
    );
  }

  Future<void> _showLocationEditor(BuildContext context, WidgetRef ref, Map<String, dynamic> day) async {
    final cityCtrl = TextEditingController(text: (day['city'] ?? '').toString());
    final venueCtrl = TextEditingController(text: (day['venue'] ?? '').toString());
    final addressCtrl = TextEditingController(text: (day['address'] ?? '').toString());

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.tr(context, 'day.editLocation')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: cityCtrl, decoration: InputDecoration(labelText: AppStrings.tr(context, 'day.city'))),
            const SizedBox(height: 8),
            TextField(controller: venueCtrl, decoration: InputDecoration(labelText: AppStrings.tr(context, 'day.venue'))),
            const SizedBox(height: 8),
            TextField(controller: addressCtrl, decoration: InputDecoration(labelText: AppStrings.tr(context, 'day.address'))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.tr(context, 'common.cancel'))),
          FilledButton(
            onPressed: () async {
              if (addressCtrl.text.trim().isEmpty) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(AppStrings.tr(context, 'day.addressRequired'))),
                  );
                }
                return;
              }

              await ref.read(dioProvider).patch('/days/$dayId', data: {
                'city': cityCtrl.text.trim().isEmpty ? null : cityCtrl.text.trim(),
                'venue': venueCtrl.text.trim().isEmpty ? null : venueCtrl.text.trim(),
                'address': addressCtrl.text.trim(),
              });
              ref.invalidate(dayDetailProvider(dayId));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(AppStrings.tr(context, 'common.save')),
          ),
        ],
      ),
    );
  }

  Future<void> _showScheduleForm(
    BuildContext context,
    WidgetRef ref, {
    Map<String, dynamic>? existing,
  }) async {
    final labelCtrl = TextEditingController(text: (existing?['label'] ?? '').toString());
    final notesCtrl = TextEditingController(text: (existing?['notes'] ?? '').toString());
    String visibility = (existing?['visibility'] ?? 'private').toString();

    final rawTime = (existing?['time'] ?? '').toString();
    final parts = rawTime.split(':');
    TimeOfDay selectedTime = TimeOfDay.now();
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) {
        selectedTime = TimeOfDay(hour: h, minute: m);
      }
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? AppStrings.tr(context, 'day.addSchedule') : AppStrings.tr(context, 'day.editSchedule')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                ),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final picked = await showTimePicker(context: ctx, initialTime: selectedTime);
                  if (picked != null) setState(() => selectedTime = picked);
                },
              ),
              TextField(controller: labelCtrl, decoration: InputDecoration(labelText: AppStrings.tr(context, 'day.labelField'))),
              const SizedBox(height: 8),
              TextField(controller: notesCtrl, decoration: InputDecoration(labelText: AppStrings.tr(context, 'day.notesOptional'))),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: visibility,
                decoration: InputDecoration(labelText: AppStrings.tr(context, 'day.visibility')),
                items: [
                  DropdownMenuItem(value: 'private', child: Text(AppStrings.tr(context, 'day.private'))),
                  DropdownMenuItem(value: 'public', child: Text(AppStrings.tr(context, 'day.public'))),
                ],
                onChanged: (value) => setState(() => visibility = value ?? 'private'),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppStrings.tr(context, 'day.visibilityHelp'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600], fontSize: 11),
                ),
              ),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _visibilityDescription(context, visibility),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600], fontSize: 11),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.tr(context, 'common.cancel'))),
            FilledButton(
              onPressed: () async {
                if (labelCtrl.text.trim().isEmpty) return;
                final hh = selectedTime.hour.toString().padLeft(2, '0');
                final mm = selectedTime.minute.toString().padLeft(2, '0');

                if (existing != null) {
                  await ref.read(dioProvider).delete('/days/$dayId/schedule/${existing['id']}');
                }

                await ref.read(dioProvider).post('/days/$dayId/schedule/', data: {
                  'time': '$hh:$mm',
                  'label': labelCtrl.text.trim(),
                  'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  'visibility': visibility,
                });

                ref.invalidate(scheduleProvider(dayId));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(existing == null ? AppStrings.tr(context, 'day.add') : AppStrings.tr(context, 'common.save')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf(BuildContext context, WidgetRef ref, String path, String successMessage) async {
    final emptyPdfText = AppStrings.tr(context, 'day.emptyPdf');
    final exportFailedText = AppStrings.tr(context, 'day.exportFailed');

    try {
      final response = await ref.read(dioProvider).get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw Exception(emptyPdfText);
      }

      final disposition = response.headers.value('content-disposition') ?? '';
      final match = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
      final fallback = path.contains('roadmap') ? 'roadmap.pdf' : 'export.pdf';
      final filename = match?.group(1) ?? fallback;

      downloadBytes(Uint8List.fromList(bytes), filename);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$successMessage: $filename')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$exportFailedText: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(dayDetailProvider(dayId));
    final schedule = ref.watch(scheduleProvider(dayId));

    return Scaffold(
      appBar: AppBar(
        title: day.when(
          data: (d) => Text('${d['date']} - ${d['city'] ?? AppStrings.tr(context, 'day.label')}'),
          loading: () => Text(AppStrings.tr(context, 'day.loading')),
          error: (_, __) => Text(AppStrings.tr(context, 'day.error')),
        ),
      ),
      body: day.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${AppStrings.tr(context, 'common.error')}: $e')),
        data: (d) {
          final isDayOff = d['type'] == 'day_off';
          final isCoplateau = d['coplateau'] == true;

          final scheduleItems = schedule.asData?.value ?? const <Map<String, dynamic>>[];
          final scheduleLoaded = schedule.asData != null;
          final missingSections = computeMissingSectionsForDay(d, scheduleCount: scheduleItems.length);

          String tooltipFor(List<String> keys) {
            final filtered = keys.where(missingSections.contains).toList();
            if (filtered.isEmpty) return '';
            return missingSectionsTooltip(context, filtered);
          }

          final dateInfoWarning = !isDayOff &&
              (missingSections.contains(MissingSectionKey.city) ||
                  missingSections.contains(MissingSectionKey.venue) ||
                  missingSections.contains(MissingSectionKey.address));
          final contactWarning = !isDayOff && missingSections.contains(MissingSectionKey.contact);
          final dealWarning = !isDayOff && missingSections.contains(MissingSectionKey.deal);
          final scheduleWarning = !isDayOff && scheduleLoaded && missingSections.contains(MissingSectionKey.planning);
          final hebergementWarning = missingSections.contains(MissingSectionKey.hebergement);

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => _exportPdf(context, ref, '/days/$dayId/export/full', AppStrings.tr(context, 'day.fullPdfGenerated')),
                      child: Text(AppStrings.tr(context, 'day.exportFullPdf')),
                    ),
                  ),
                  if (!isDayOff) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => _exportPdf(context, ref, '/days/$dayId/export/roadmap', AppStrings.tr(context, 'day.roadmapPdfGenerated')),
                        child: Text(AppStrings.tr(context, 'day.exportRoadmapPdf')),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              _Section(
                title: AppStrings.tr(context, 'day.dateInfo'),
                warningTooltip: dateInfoWarning
                    ? tooltipFor(const [
                        MissingSectionKey.city,
                        MissingSectionKey.venue,
                        MissingSectionKey.address,
                      ])
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(AppStrings.tr(context, 'day.type'), d['type']?.toString()),
                    _InfoRow(AppStrings.tr(context, 'day.date'), d['date']?.toString()),
                    if (!isDayOff) ...[
                      _InfoRow(AppStrings.tr(context, 'day.city'), d['city']?.toString()),
                      _InfoRow(AppStrings.tr(context, 'day.venue'), d['venue']?.toString()),
                      _InfoRow(AppStrings.tr(context, 'day.address'), d['address']?.toString()),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => _showLocationEditor(context, ref, d),
                          child: Text(AppStrings.tr(context, 'day.editCityVenueAddress')),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isDayOff) ...[
                const SizedBox(height: 8),
                _Section(
                  title: AppStrings.tr(context, 'day.trackingSection'),
                  child: Column(
                    children: [
                      CheckboxListTile(
                        value: d['promo_sent'] == true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(AppStrings.tr(context, 'day.promoSent')),
                        onChanged: (value) => _patchDay(context, ref, {'promo_sent': value == true}),
                      ),
                      CheckboxListTile(
                        value: isCoplateau,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(AppStrings.tr(context, 'day.coplateau')),
                        onChanged: (value) => _patchDay(context, ref, {
                          'coplateau': value == true,
                          if (value != true) 'roadmap_sent': false,
                          if (value != true) 'backline_conversation': false,
                        }),
                      ),
                      if (isCoplateau) ...[
                        CheckboxListTile(
                          value: d['roadmap_sent'] == true,
                          contentPadding: const EdgeInsets.only(left: 16),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(AppStrings.tr(context, 'day.roadmapSent')),
                          onChanged: (value) => _patchDay(context, ref, {'roadmap_sent': value == true}),
                        ),
                        CheckboxListTile(
                          value: d['backline_conversation'] == true,
                          contentPadding: const EdgeInsets.only(left: 16),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(AppStrings.tr(context, 'day.backlineConversation')),
                          onChanged: (value) => _patchDay(context, ref, {'backline_conversation': value == true}),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (!isDayOff) ...[
                const SizedBox(height: 8),
                _Section(
                  title: AppStrings.tr(context, 'day.contact'),
                  warningTooltip: contactWarning ? tooltipFor(const [MissingSectionKey.contact]) : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((d['contact_text'] ?? AppStrings.tr(context, 'day.noContentYet')).toString()),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => _showFreeTextEditor(
                            context,
                            ref,
                            title: AppStrings.tr(context, 'day.contact'),
                            field: 'contact_text',
                            initialValue: d['contact_text']?.toString(),
                          ),
                          child: Text(AppStrings.tr(context, 'day.editContact')),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _Section(
                  title: AppStrings.tr(context, 'day.deal'),
                  warningTooltip: dealWarning ? tooltipFor(const [MissingSectionKey.deal]) : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((d['finance_text'] ?? AppStrings.tr(context, 'day.noContentYet')).toString()),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => _showFreeTextEditor(
                            context,
                            ref,
                            title: AppStrings.tr(context, 'day.deal'),
                            field: 'finance_text',
                            initialValue: d['finance_text']?.toString(),
                          ),
                          child: Text(AppStrings.tr(context, 'day.editDeal')),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _Section(
                  title: AppStrings.tr(context, 'day.schedule'),
                  warningTooltip: scheduleWarning ? tooltipFor(const [MissingSectionKey.planning]) : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => _showScheduleForm(context, ref),
                          child: Text(AppStrings.tr(context, 'day.addScheduleItem')),
                        ),
                      ),
                      schedule.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(),
                        ),
                        error: (e, _) => Text('${AppStrings.tr(context, 'common.error')}: $e'),
                        data: (items) {
                          if (items.isEmpty) return Text(AppStrings.tr(context, 'day.noScheduleYet'));
                          return Column(
                            children: items
                                .map(
                                  (item) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Text((item['time'] ?? '').toString()),
                                    title: Text((item['label'] ?? '').toString()),
                                    subtitle: Text(
                                      [
                                        (item['notes'] ?? '').toString().trim(),
                                        '${(item['visibility'] ?? 'private').toString().toUpperCase()} · ${_visibilityDescription(context, (item['visibility'] ?? 'private').toString())}',
                                      ].where((v) => v.isNotEmpty).join('\n'),
                                    ),
                                    trailing: Wrap(
                                      spacing: 4,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () => _showScheduleForm(context, ref, existing: item),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline),
                                          onPressed: () async {
                                            await ref.read(dioProvider).delete('/days/$dayId/schedule/${item['id']}');
                                            ref.invalidate(scheduleProvider(dayId));
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _Section(
                title: AppStrings.tr(context, 'day.hebergement'),
                warningTooltip: hebergementWarning ? tooltipFor(const [MissingSectionKey.hebergement]) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((d['hebergement'] ?? AppStrings.tr(context, 'day.noContentYet')).toString()),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => _showFreeTextEditor(
                          context,
                          ref,
                          title: AppStrings.tr(context, 'day.hebergement'),
                          field: 'hebergement',
                          initialValue: d['hebergement']?.toString(),
                        ),
                        child: Text(AppStrings.tr(context, 'day.editHebergement')),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _Section(
                title: AppStrings.tr(context, 'day.note'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((d['day_note'] ?? AppStrings.tr(context, 'day.noContentYet')).toString()),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => _showFreeTextEditor(
                          context,
                          ref,
                          title: AppStrings.tr(context, 'day.note'),
                          field: 'day_note',
                          initialValue: d['day_note']?.toString(),
                        ),
                        child: Text(AppStrings.tr(context, 'day.editNote')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final String? warningTooltip;
  const _Section({required this.title, required this.child, this.warningTooltip});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                if (warningTooltip != null && warningTooltip!.trim().isNotEmpty)
                  MissingBadge(tooltip: warningTooltip!),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}
