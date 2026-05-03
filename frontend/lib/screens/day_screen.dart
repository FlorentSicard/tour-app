import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tourapp/providers/api_provider.dart';
import 'package:tourapp/providers/tour_providers.dart';

class DayScreen extends ConsumerWidget {
  final String dayId;
  const DayScreen({super.key, required this.dayId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(dayDetailProvider(dayId));
    final schedule = ref.watch(scheduleProvider(dayId));
    final checklist = ref.watch(checklistProvider(dayId));

    return Scaffold(
      appBar: AppBar(
        title: day.when(
          data: (d) => Text('${d['date']} - ${d['city'] ?? 'Day'}'),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Error'),
        ),
      ),
      body: day.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (d) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _LogisticsCard(day: d),
            const SizedBox(height: 8),
            _ContactCard(day: d),
            const SizedBox(height: 8),
            _FinanceCard(day: d),
            const SizedBox(height: 8),
            _ScheduleCard(schedule: schedule, dayId: dayId, ref: ref),
            const SizedBox(height: 8),
            _ChecklistCard(checklist: checklist, dayId: dayId, ref: ref),
          ],
        ),
      ),
    );
  }
}

class _LogisticsCard extends StatelessWidget {
  final Map<String, dynamic> day;
  const _LogisticsCard({required this.day});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text('Logistics'),
        initiallyExpanded: true,
        children: [
          _InfoRow('Type', day['type']),
          _InfoRow('City', day['city']),
          _InfoRow('Venue', day['venue']),
          if (day['travel_notes'] != null) _InfoRow('Travel', day['travel_notes']),
          if (day['notes'] != null) _InfoRow('Notes', day['notes']),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final Map<String, dynamic> day;
  const _ContactCard({required this.day});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text('Contact'),
        children: [
          _InfoRow('Name', day['contact_name']),
          _InfoRow('Phone', day['contact_phone']),
          _InfoRow('Email', day['contact_email']),
        ],
      ),
    );
  }
}

class _FinanceCard extends StatelessWidget {
  final Map<String, dynamic> day;
  const _FinanceCard({required this.day});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text('Finance'),
        children: [
          _InfoRow('Deal', day['deal_amount'] != null
              ? '${day['deal_amount']} ${day['deal_currency'] ?? ''}'
              : null),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> schedule;
  final String dayId;
  final WidgetRef ref;
  const _ScheduleCard({required this.schedule, required this.dayId, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text('Schedule'),
        initiallyExpanded: true,
        children: [
          schedule.when(
            loading: () => const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (items) => Column(
              children: items.map((item) => ListTile(
                leading: Text(item['time'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                title: Text(item['label'] ?? ''),
                subtitle: item['notes'] != null ? Text(item['notes']) : null,
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> checklist;
  final String dayId;
  final WidgetRef ref;
  const _ChecklistCard({required this.checklist, required this.dayId, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text('Checklist'),
        initiallyExpanded: true,
        children: [
          checklist.when(
            loading: () => const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (items) => Column(
              children: items.map((item) => CheckboxListTile(
                value: item['is_done'] == true,
                title: Text(
                  item['label'] ?? '',
                  style: TextStyle(
                    decoration: item['is_done'] == true ? TextDecoration.lineThrough : null,
                    color: item['is_overdue_flagged'] == true ? Colors.red : null,
                  ),
                ),
                subtitle: item['due_date'] != null ? Text('Due: ${item['due_date']}') : null,
                onChanged: (val) async {
                  await ref.read(dioProvider).patch(
                    '/checklist-items/${item['id']}',
                    data: {'is_done': val},
                  );
                  ref.invalidate(checklistProvider(dayId));
                },
              )).toList(),
            ),
          ),
        ],
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
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value!)),
        ],
      ),
    );
  }
}
