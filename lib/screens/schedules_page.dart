import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/home_assistant.dart';
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
                onTap: () => _edit(context, i),
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

  Future<void> _edit(BuildContext context, int index) async {
    final schedule = state.schedules[index];
    final result = await showModalBottomSheet<CleaningSchedule>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cream,
      builder: (_) => _ScheduleSheet(state: state, schedule: schedule),
    );
    if (result != null) await state.updateSchedule(result);
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
    required this.onTap,
    required this.onChanged,
    required this.onDelete,
  });
  final CleaningSchedule schedule;
  final String vacuumName;
  final bool busy;
  final VoidCallback onTap;
  final ValueChanged<bool> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Edit ${schedule.title}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: busy ? null : onTap,
        child: SurfaceCard(
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: ink.withValues(alpha: .07),
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
                            color: ink,
                          ),
                        ),
                        Text(
                          'START',
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1,
                            color: ink.withValues(alpha: .45),
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
                        if (schedule.fanSpeed != null ||
                            schedule.settings.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            [
                              if (schedule.fanSpeed != null) schedule.fanSpeed!,
                              ...schedule.settings.map((item) => item.value),
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({required this.state, this.schedule});
  final AppState state;
  final CleaningSchedule? schedule;
  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  late TimeOfDay time;
  late final TextEditingController title;
  late final Set<int> weekdays;
  late String vacuumEntityId;
  String? fanSpeed;
  final Map<String, String?> settingValues = {};

  bool get isEditing => widget.schedule != null;

  @override
  void initState() {
    super.initState();
    final schedule = widget.schedule;
    final timeParts = schedule?.time.split(':');
    time = timeParts != null && timeParts.length == 2
        ? TimeOfDay(
            hour: int.tryParse(timeParts[0]) ?? 9,
            minute: int.tryParse(timeParts[1]) ?? 0,
          )
        : const TimeOfDay(hour: 9, minute: 0);
    title = TextEditingController(text: schedule?.title ?? 'Morning clean');
    weekdays = schedule == null
        ? {
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
          }
        : schedule.weekdays.toSet();
    vacuumEntityId = schedule?.vacuumEntityId ?? widget.state.vacuum.entityId;
    fanSpeed = schedule?.fanSpeed;
    for (final setting in schedule?.settings ?? const <VacuumSetting>[]) {
      settingValues[setting.entityId] = setting.value;
    }
  }

  VacuumEntity get selectedVacuum => widget.state.vacuums.firstWhere(
    (vacuum) => vacuum.entityId == vacuumEntityId,
    orElse: () => widget.state.vacuum,
  );

  List<VacuumSetting> get scheduleSettings {
    final settings = widget.state
        .settingsForVacuum(vacuumEntityId)
        .where(
          (setting) =>
              setting.available &&
              (setting.kind == VacuumSettingKind.select ||
                  setting.kind == VacuumSettingKind.toggle) &&
              const {
                'Cleaning',
                'Mopping',
                'Carpets',
              }.contains(setting.category),
        )
        .toList();
    settings.sort((a, b) => a.name.compareTo(b.name));
    return settings;
  }

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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    isEditing ? 'Edit schedule' : 'New schedule',
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
                  onChanged: (value) async {
                    if (value != null) {
                      setState(() {
                        vacuumEntityId = value;
                        fanSpeed = null;
                        settingValues.clear();
                      });
                      await widget.state.refreshVacuumSettingsFor(value);
                      if (mounted) setState(() {});
                    }
                  },
                ),
              ],
              if (selectedVacuum.fanSpeeds.isNotEmpty) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  key: ValueKey('suction-$vacuumEntityId'),
                  initialValue: fanSpeed,
                  decoration: const InputDecoration(labelText: 'Suction power'),
                  hint: const Text('Use current'),
                  items: [
                    const DropdownMenuItem(
                      value: '__current__',
                      child: Text('Use current'),
                    ),
                    for (final speed in selectedVacuum.fanSpeeds)
                      DropdownMenuItem(value: speed, child: Text(speed)),
                  ],
                  onChanged: (value) => setState(
                    () => fanSpeed = value == '__current__' ? null : value,
                  ),
                ),
              ],
              if (scheduleSettings.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Cleaning preferences',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose what this schedule should apply before it starts.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                for (final setting in scheduleSettings) ...[
                  _ScheduleSettingField(
                    key: ValueKey(setting.entityId),
                    setting: setting,
                    value: settingValues[setting.entityId],
                    onChanged: (value) =>
                        setState(() => settingValues[setting.entityId] = value),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    CleaningSchedule(
                      id:
                          widget.schedule?.id ??
                          'scrubby_${DateTime.now().microsecondsSinceEpoch}',
                      entityId: widget.schedule?.entityId ?? '',
                      title: title.text.trim().isEmpty
                          ? 'Cleaning'
                          : title.text.trim(),
                      weekdays: weekdays.toList()..sort(),
                      time:
                          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                      vacuumEntityId: vacuumEntityId,
                      enabled: widget.schedule?.enabled ?? true,
                      fanSpeed: fanSpeed,
                      settings: [
                        for (final setting in scheduleSettings)
                          if (settingValues[setting.entityId] != null)
                            setting.copyWithValue(
                              settingValues[setting.entityId]!,
                            ),
                      ],
                    ),
                  ),
                  child: Text(isEditing ? 'Save changes' : 'Create schedule'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleSettingField extends StatelessWidget {
  const _ScheduleSettingField({
    super.key,
    required this.setting,
    required this.value,
    required this.onChanged,
  });

  final VacuumSetting setting;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final choices = switch (setting.kind) {
      VacuumSettingKind.select => setting.options,
      VacuumSettingKind.toggle => const ['on', 'off'],
      _ => const <String>[],
    };
    if (choices.isEmpty) return const SizedBox.shrink();
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: setting.name),
      hint: const Text('Use current'),
      items: [
        const DropdownMenuItem(
          value: '__current__',
          child: Text('Use current'),
        ),
        for (final choice in choices)
          DropdownMenuItem(
            value: choice,
            child: Text(
              setting.kind == VacuumSettingKind.toggle
                  ? (choice == 'on' ? 'On' : 'Off')
                  : choice,
            ),
          ),
      ],
      onChanged: (next) => onChanged(next == '__current__' ? null : next),
    );
  }
}
