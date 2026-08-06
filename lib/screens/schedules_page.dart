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
            subtitle: 'Make clean floors the default, not another chore.',
            trailing: FilledButton.icon(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New schedule'),
            ),
          ),
          const SizedBox(height: 26),
          for (var i = 0; i < state.schedules.length; i++) ...[
            _ScheduleCard(
              schedule: state.schedules[i],
              onChanged: (value) => state.toggleSchedule(i, value),
            ),
            const SizedBox(height: 13),
          ],
          const SizedBox(height: 12),
          SurfaceCard(
            color: mint.withValues(alpha: .58),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: fern,
                  foregroundColor: mint,
                  child: Icon(Icons.auto_awesome_rounded),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'A quieter kind of routine',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Scrubby respects Home Assistant automations—these schedules are a focused view for your vacuums.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final result = await showModalBottomSheet<CleaningSchedule>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cream,
      builder: (_) => const _ScheduleSheet(),
    );
    if (result != null) state.addSchedule(result);
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.schedule, required this.onChanged});
  final CleaningSchedule schedule;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
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
                  schedule.rooms,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Switch(
            value: schedule.enabled,
            onChanged: onChanged,
            activeThumbColor: fern,
          ),
        ],
      ),
    );
  }
}

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet();
  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  TimeOfDay time = const TimeOfDay(hour: 9, minute: 0);
  final title = TextEditingController(text: 'Morning clean');

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
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  CleaningSchedule(
                    title: title.text.trim().isEmpty
                        ? 'Cleaning'
                        : title.text.trim(),
                    days: 'EVERY DAY',
                    time:
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                    rooms: 'Whole home',
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
