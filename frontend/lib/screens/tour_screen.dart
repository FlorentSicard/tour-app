import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tourapp/providers/api_provider.dart';
import 'package:tourapp/providers/tour_providers.dart';

class TourScreen extends ConsumerWidget {
  final String tourId;
  const TourScreen({super.key, required this.tourId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(daysProvider(tourId));

    return Scaffold(
      appBar: AppBar(title: const Text('Tour Days')),
      body: days.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('No days yet'))
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final day = list[i];
                  final type = day['type'] == 'concert' ? 'Concert' : 'Day Off';
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      title: Text('${day['date']} - $type'),
                      subtitle: Text([day['city'], day['venue']].where((s) => s != null).join(' - ')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/days/${day['id']}'),
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
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('New Day'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('${selectedDate.toIso8601String().split('T').first}'),
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
              TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'City')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                await ref.read(dioProvider).post('/days/', data: {
                  'tour_id': tourId,
                  'date': selectedDate.toIso8601String().split('T').first,
                  'city': cityCtrl.text,
                });
                ref.invalidate(daysProvider(tourId));
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}
