import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../theme.dart';
import '../widgets/shared.dart';

class SchedulesPage extends StatelessWidget {
  const SchedulesPage({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Cleaning rhythm',
            subtitle: state.isDemo
                ? 'Demo schedules stay in this session.'
                : 'Schedules run in Home Assistant, even when Scrubby is closed.',
            trailing: FilledButton.icon(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New schedule'),
            ),
          ),
          const SizedBox(height: 26),
          if (state.scheduleError != null) ...[
            _ScheduleError(
              message: state.scheduleError!,
              onRetry: state.refreshSchedules,
            ),
            const SizedBox(height: 13),
          ],
          if (state.schedulesLoading && state.schedules.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.schedules.isEmpty)
            const _EmptySchedules()
          else
            for (var i = 0; i < state.schedules.length; i++) ...[
              _ScheduleCard(
                schedule: state.schedules[i],
                vacuumName: state.vacuumName(state.schedules[i].vacuumEntityId),
                busy: state.busyScheduleIds.contains(state.schedules[i].id),
                onChanged: (value) => state.toggleSchedule(i, value),
                onDelete: () => _delete(context, i),
              ),
              const SizedBox(height: 13),
            ],
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final result = await showModalBottomSheet<CleaningSchedule>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cream,
      builder: (_) => _ScheduleSheet(state: state),
    );
    if (result != null) await state.addSchedule(result);
  }

  Future<void> _delete(BuildContext context, int index) async {
    final schedule = state.schedules[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete schedule?'),
        content: Text(
          state.isDemo
              ? '“${schedule.title}” will be removed.'
              : '“${schedule.title}” will be removed from Home Assistant.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await state.deleteSchedule(index);
  }
}

class _ScheduleError extends StatelessWidget {
  const _ScheduleError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptySchedules extends StatelessWidget {
  const _EmptySchedules();

  @override
  Widget build(BuildContext context) {
    return const SurfaceCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.event_available_rounded, size: 38, color: fern),
              SizedBox(height: 12),
              Text(
                'No cleaning schedules yet',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 5),
              Text('Create one to let Home Assistant start your vacuum.'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.schedule,
    required this.vacuumName,
    required this.busy,
    required this.onChanged,
    required this.onDelete,
  });
  final CleaningSchedule schedule;
  final String vacuumName;
  final bool busy;
  final ValueChanged<bool> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: schedule.enabled ? ink : ink.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      schedule.time,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: schedule.enabled ? Colors.white : ink,
                      ),
                    ),
                    Text(
                      'START',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1,
                        color: schedule.enabled
                            ? Colors.white54
                            : ink.withValues(alpha: .45),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      schedule.days,
                      style: const TextStyle(
                        color: fern,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Whole home · $vacuumName',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              else ...[
                Switch(
                  value: schedule.enabled,
                  onChanged: onChanged,
                  activeThumbColor: fern,
                ),
                Spacer(),
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Delete schedule',
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({required this.state});
  final AppState state;
  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  TimeOfDay time = const TimeOfDay(hour: 9, minute: 0);
  final title = TextEditingController(text: 'Morning clean');
  final Set<int> weekdays = {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  };
  late String vacuumEntityId = widget.state.vacuum.entityId;

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 28,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'New schedule',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 22),
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: const Text('Start time'),
              trailing: Text(
                time.format(context),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onTap: () async {
                final value = await showTimePicker(
                  context: context,
                  initialTime: time,
                );
                if (value != null) setState(() => time = value);
              },
            ),
            const SizedBox(height: 12),
            Text('Days', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              children: [
                for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                  FilterChip(
                    label: Text(
                      const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][day - 1],
                    ),
                    selected: weekdays.contains(day),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        weekdays.add(day);
                      } else if (weekdays.length > 1) {
                        weekdays.remove(day);
                      }
                    }),
                  ),
              ],
            ),
            if (widget.state.vacuums.length > 1) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: vacuumEntityId,
                decoration: const InputDecoration(labelText: 'Vacuum'),
                items: [
                  for (final vacuum in widget.state.vacuums)
                    DropdownMenuItem(
                      value: vacuum.entityId,
                      child: Text(vacuum.name),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => vacuumEntityId = value);
                },
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  CleaningSchedule(
                    id: 'scrubby_${DateTime.now().microsecondsSinceEpoch}',
                    entityId: '',
                    title: title.text.trim().isEmpty
                        ? 'Cleaning'
                        : title.text.trim(),
                    weekdays: weekdays.toList()..sort(),
                    time:
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                    vacuumEntityId: vacuumEntityId,
                  ),
                ),
                child: const Text('Create schedule'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
