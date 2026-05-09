import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tourapp/l10n/app_strings.dart';
import 'package:tourapp/providers/api_provider.dart';
import 'package:tourapp/providers/auth_provider.dart';
import 'package:tourapp/providers/tour_providers.dart';
import 'package:tourapp/utils/day_completeness.dart';
import 'package:tourapp/widgets/missing_badge.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = ref.watch(homeTimelineProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(context, 'home.timeline')),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: AppStrings.tr(context, 'logout'),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
      body: timeline.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${AppStrings.tr(context, 'common.error')}: $e')),
        data: (list) => list.isEmpty
            ? Center(child: Text(AppStrings.tr(context, 'home.noData')))
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final item = list[i];
                  final isIsolatedDay = item.kind == 'isolated_day';
                  final isTour = item.kind == 'tour';

                  final dateText = item.date == null
                      ? AppStrings.tr(context, 'home.noDate')
                      : item.date!.toIso8601String().split('T').first;

                  String periodText;
                  if (isTour) {
                    final firstDate = item.date;
                    final lastDate = item.endDate;
                    final firstText = firstDate == null ? AppStrings.tr(context, 'home.noDate') : firstDate.toIso8601String().split('T').first;
                    final lastText = lastDate == null ? AppStrings.tr(context, 'home.noDate') : lastDate.toIso8601String().split('T').first;
                    periodText = '$firstText → $lastText';
                  } else {
                    periodText = dateText;
                  }

                  final missingAsync = isIsolatedDay ? ref.watch(dayMissingSectionsProvider(item.id)) : null;
                  return ListTile(
                    leading: Chip(
                      label: Text(item.kind == 'tour' ? AppStrings.tr(context, 'home.tour') : AppStrings.tr(context, 'home.isolatedDate')),
                      visualDensity: VisualDensity.compact,
                    ),
                    title: Text(item.title),
                    subtitle: Text([periodText, item.subtitle].where((e) => e != null && e.isNotEmpty).join(' • ')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isIsolatedDay && missingAsync != null)
                          missingAsync.when(
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (missing) {
                              if (missing.isEmpty) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: MissingBadge(
                                  tooltip: missingSectionsTooltip(context, missing),
                                ),
                              );
                            },
                          ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () {
                      if (item.kind == 'tour' && item.tourId != null) {
                        context.push('/tours/${item.tourId}');
                      } else {
                        context.push('/days/${item.id}');
                      }
                    },
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showCreateEntryDialog(context, ref),
      ),
    );
  }

  void _showCreateEntryDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final venueCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    bool isIsolatedDay = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(isIsolatedDay ? AppStrings.tr(context, 'home.newIsolatedConcertDay') : AppStrings.tr(context, 'home.newTour')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(AppStrings.tr(context, 'home.createIsolated')),
                value: isIsolatedDay,
                onChanged: (value) => setState(() => isIsolatedDay = value),
              ),
              if (!isIsolatedDay)
                TextField(controller: ctrl, decoration: InputDecoration(labelText: AppStrings.tr(context, 'home.tourName')))
              else ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(selectedDate.toIso8601String().split('T').first),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setState(() => selectedDate = picked);
                  },
                ),
                TextField(controller: cityCtrl, decoration: InputDecoration(labelText: AppStrings.tr(context, 'home.city'))),
                const SizedBox(height: 8),
                TextField(controller: venueCtrl, decoration: InputDecoration(labelText: AppStrings.tr(context, 'home.venue'))),
                const SizedBox(height: 8),
                TextField(controller: addressCtrl, decoration: InputDecoration(labelText: AppStrings.tr(context, 'day.address'))),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.tr(context, 'common.cancel'))),
            FilledButton(
              onPressed: () async {
                if (!isIsolatedDay) {
                  if (ctrl.text.trim().isEmpty) return;
                  await ref.read(dioProvider).post('/tours/', data: {'name': ctrl.text.trim()});
                } else {
                  if (addressCtrl.text.trim().isEmpty) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(AppStrings.tr(context, 'day.addressRequired'))),
                      );
                    }
                    return;
                  }
                  await ref.read(dioProvider).post('/days/', data: {
                    'tour_id': null,
                    'type': 'concert',
                    'date': selectedDate.toIso8601String().split('T').first,
                    'city': cityCtrl.text.trim().isEmpty ? null : cityCtrl.text.trim(),
                    'venue': venueCtrl.text.trim().isEmpty ? null : venueCtrl.text.trim(),
                    'address': addressCtrl.text.trim(),
                  });
                }
                ref.invalidate(homeTimelineProvider);
                ref.invalidate(toursProvider);
                ref.invalidate(daysProvider(null));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(AppStrings.tr(context, 'common.create')),
            ),
          ],
        ),
      ),
    );
  }
}
