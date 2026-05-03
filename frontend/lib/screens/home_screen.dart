import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tourapp/providers/api_provider.dart';
import 'package:tourapp/providers/auth_provider.dart';
import 'package:tourapp/providers/tour_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    if (auth.activeGroupId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('TourApp'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                ref.read(authProvider.notifier).logout();
                context.go('/login');
              },
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Create your first group to get started'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _showCreateGroupDialog(context, ref),
                child: const Text('Create Group'),
              ),
            ],
          ),
        ),
      );
    }

    final tours = ref.watch(toursProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tours'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
      body: tours.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('No tours yet'))
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final tour = list[i];
                  return ListTile(
                    title: Text(tour['name'] ?? ''),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/tours/${tour['id']}'),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showCreateTourDialog(context, ref),
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Group'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Group name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.isEmpty) return;
              final res = await ref.read(dioProvider).post('/groups/', data: {'name': ctrl.text});
              ref.read(authProvider.notifier).setActiveGroup(res.data['id']);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showCreateTourDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Tour'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Tour name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.isEmpty) return;
              await ref.read(dioProvider).post('/tours/', data: {'name': ctrl.text});
              ref.invalidate(toursProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
