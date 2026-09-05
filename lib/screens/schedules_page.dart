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
            _EmptySchedules(onCreate: () => _add(context))
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              primary: false,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: state.schedules.length,
              onReorderItem: state.reorderSchedules,
              itemBuilder: (context, index) {
                final schedule = state.schedules[index];
                return Padding(
                  key: ValueKey(schedule.id),
                  padding: const EdgeInsets.only(bottom: 13),
                  child: _ScheduleCard(
                    schedule: schedule,
                    vacuumName: state.vacuumName(schedule.vacuumEntityId),
                    roomSummary: state.scheduleRooms(schedule),
                    busy: state.busyScheduleIds.contains(schedule.id),
                    onTap: () => _edit(context, index),
                    onChanged: (value) => state.toggleSchedule(index, value),
                    onDelete: () => _delete(context, index),
                    dragHandle: ReorderableDragStartListener(
                      index: index,
                      child: Tooltip(
                        message: 'Reorder schedule',
                        child: Icon(
                          Icons.drag_handle_rounded,
                          color: ink.withValues(alpha: .45),
                        ),
                      ),
                    ),
                  ),
                );
              },
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
  const _EmptySchedules({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => EmptyStatePanel(
    icon: Icons.event_available_rounded,
    title: 'No cleaning schedules yet',
    message: 'Create one to let Home Assistant start your vacuum.',
    actionLabel: 'New schedule',
    actionIcon: Icons.add_rounded,
    onAction: onCreate,
  );
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.schedule,
    required this.vacuumName,
    required this.roomSummary,
    required this.busy,
    required this.onTap,
    required this.onChanged,
    required this.onDelete,
    required this.dragHandle,
  });
  final CleaningSchedule schedule;
  final String vacuumName;
  final String roomSummary;
  final bool busy;
  final VoidCallback onTap;
  final ValueChanged<bool> onChanged;
  final VoidCallback onDelete;
  final Widget dragHandle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Edit ${schedule.title}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: busy ? null : onTap,
        child: SurfaceCard(
          padding: EdgeInsets.zero,
          color: schedule.enabled
              ? Colors.white.withValues(alpha: .9)
              : ink.withValues(alpha: .035),
          child: Column(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: schedule.enabled ? fern : ink.withValues(alpha: .12),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 14, 12),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            color: schedule.enabled
                                ? mint
                                : ink.withValues(alpha: .07),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                schedule.time,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 19,
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
                        const SizedBox(width: 16),
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
                                '$roomSummary · $vacuumName',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (schedule.fanSpeed != null ||
                                  schedule.settings.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(
                                  [
                                    if (schedule.fanSpeed != null)
                                      schedule.fanSpeed!,
                                    ...schedule.settings.map(
                                      (item) => item.value,
                                    ),
                                    if (schedule.cycles > 1)
                                      '${schedule.cycles} cycles',
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Semantics(
                          label: 'Reorder ${schedule.title}',
                          child: dragHandle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Switch(
                          value: schedule.enabled,
                          onChanged: onChanged,
                          activeThumbColor: fern,
                        ),
                        const Spacer(),
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
  late final Set<String> selectedSegments;
  late int cycles;
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
    selectedSegments = schedule?.segmentIds.toSet() ?? <String>{};
    cycles = schedule?.cycles ?? 1;
    for (final setting in schedule?.settings ?? const <VacuumSetting>[]) {
      settingValues[setting.entityId] = setting.value;
    }
    _seedDefaults(existing: schedule != null);
  }

  VacuumEntity get selectedVacuum => widget.state.vacuums.firstWhere(
    (vacuum) => vacuum.entityId == vacuumEntityId,
    orElse: () => widget.state.vacuum,
  );

  List<VacuumSetting> get availableSelects => widget.state
      .settingsForVacuum(vacuumEntityId)
      .where(
        (setting) =>
            setting.available &&
            setting.kind == VacuumSettingKind.select &&
            setting.options.isNotEmpty,
      )
      .toList(growable: false);

  String _searchable(VacuumSetting setting) =>
      '${setting.entityId} ${setting.name}'.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]+'),
        ' ',
      );

  VacuumSetting? get cleanGeniusSetting {
    final matches = availableSelects.where((setting) {
      final value = _searchable(setting);
      return (value.contains('cleangenius') ||
              value.contains('clean genius')) &&
          !value.contains('cleangenius mode') &&
          !value.contains('clean genius mode') &&
          setting.options.any(_isOff);
    }).toList();
    return matches.isEmpty ? null : matches.first;
  }

  VacuumSetting? _exactSetting(String name) {
    final matches = availableSelects.where((setting) {
      final normalizedName = setting.name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .trim();
      return normalizedName == name;
    }).toList();
    return matches.isEmpty ? null : matches.first;
  }

  VacuumSetting? get cleaningModeSetting => _exactSetting('cleaning mode');
  VacuumSetting? get cleaningRouteSetting => _exactSetting('cleaning route');
  SegmentCleaningCapability? get segmentCapability =>
      widget.state.segmentCleaningCapabilityFor(vacuumEntityId);
  List<VacuumSegment> get segments =>
      widget.state.segmentsForVacuum(vacuumEntityId);

  bool _isOff(String value) => value.toLowerCase().trim() == 'off';

  String _selectedValue(VacuumSetting setting) {
    final selected = settingValues[setting.entityId];
    if (selected != null && setting.options.contains(selected)) return selected;
    if (setting.options.contains(setting.value)) return setting.value;
    return setting.options.first;
  }

  bool get usesCleanGenius {
    final setting = cleanGeniusSetting;
    return setting != null && !_isOff(_selectedValue(setting));
  }

  bool get customModeUsesSuction {
    final setting = cleaningModeSetting;
    if (setting == null) return true;
    final mode = _selectedValue(
      setting,
    ).toLowerCase().replaceAll('_', ' ').trim();
    return mode != 'mop' && mode != 'mopping';
  }

  void _seedDefaults({required bool existing}) {
    final cleanGenius = cleanGeniusSetting;
    if (cleanGenius != null && settingValues[cleanGenius.entityId] == null) {
      settingValues[cleanGenius.entityId] = existing
          ? cleanGenius.options.firstWhere(
              _isOff,
              orElse: () => cleanGenius.options.first,
            )
          : cleanGenius.value;
    }
    if (!existing && fanSpeed == null) {
      fanSpeed = selectedVacuum.fanSpeeds.contains(selectedVacuum.fanSpeed)
          ? selectedVacuum.fanSpeed
          : selectedVacuum.fanSpeeds.firstOrNull;
    }
    for (final setting in [cleaningModeSetting, cleaningRouteSetting]) {
      if (setting != null && settingValues[setting.entityId] == null) {
        settingValues[setting.entityId] = setting.value;
      }
    }
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cleanGenius = cleanGeniusSetting;
    final cleaningMode = cleaningModeSetting;
    final cleaningRoute = cleaningRouteSetting;
    final canChooseRooms = segmentCapability != null && segments.isNotEmpty;
    final validSegmentIds = segments.map((segment) => segment.id).toSet();
    selectedSegments.retainAll(validSegmentIds);
    final maximumCycles = segmentCapability?.maximumRepeats ?? 1;
    cycles = cycles.clamp(1, maximumCycles);
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
                        selectedSegments.clear();
                        cycles = 1;
                      });
                      await widget.state.refreshVacuumSettingsFor(value);
                      if (mounted) {
                        setState(() => _seedDefaults(existing: false));
                      }
                    }
                  },
                ),
              ],
              if (canChooseRooms) ...[
                const SizedBox(height: 20),
                Text('Rooms', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Choose individual rooms, or leave Whole home selected.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Whole home'),
                      selected: selectedSegments.isEmpty,
                      onSelected: (_) =>
                          setState(() => selectedSegments.clear()),
                    ),
                    for (final segment in segments)
                      FilterChip(
                        label: Text(
                          widget.state.segmentNameFor(vacuumEntityId, segment),
                        ),
                        selected: selectedSegments.contains(segment.id),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            selectedSegments.add(segment.id);
                          } else {
                            selectedSegments.remove(segment.id);
                          }
                        }),
                      ),
                  ],
                ),
              ],
              if (cleanGenius != null) ...[
                const SizedBox(height: 20),
                Text(
                  'Cleaning plan',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('cleangenius-$vacuumEntityId'),
                  initialValue: _selectedValue(cleanGenius),
                  decoration: const InputDecoration(labelText: 'CleanGenius'),
                  items: [
                    for (final option in cleanGenius.options)
                      DropdownMenuItem(
                        value: option,
                        child: Text(_isOff(option) ? 'Custom' : option),
                      ),
                  ],
                  onChanged: (value) => setState(
                    () => settingValues[cleanGenius.entityId] = value,
                  ),
                ),
              ],
              if (!usesCleanGenius && cleaningMode != null) ...[
                const SizedBox(height: 14),
                _ScheduleSettingField(
                  key: ValueKey(cleaningMode.entityId),
                  setting: cleaningMode,
                  value: _selectedValue(cleaningMode),
                  valueLabel: _cleaningModeLabel,
                  onChanged: (value) => setState(
                    () => settingValues[cleaningMode.entityId] = value,
                  ),
                ),
              ],
              if (!usesCleanGenius &&
                  customModeUsesSuction &&
                  selectedVacuum.fanSpeeds.isNotEmpty) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  key: ValueKey('suction-$vacuumEntityId'),
                  initialValue: selectedVacuum.fanSpeeds.contains(fanSpeed)
                      ? fanSpeed
                      : selectedVacuum.fanSpeeds.first,
                  decoration: const InputDecoration(labelText: 'Suction power'),
                  items: [
                    for (final speed in selectedVacuum.fanSpeeds)
                      DropdownMenuItem(value: speed, child: Text(speed)),
                  ],
                  onChanged: (value) => setState(() => fanSpeed = value),
                ),
              ],
              if (!usesCleanGenius && cleaningRoute != null) ...[
                const SizedBox(height: 14),
                _ScheduleSettingField(
                  key: ValueKey(cleaningRoute.entityId),
                  setting: cleaningRoute,
                  value: _selectedValue(cleaningRoute),
                  onChanged: (value) => setState(
                    () => settingValues[cleaningRoute.entityId] = value,
                  ),
                ),
              ],
              if (!usesCleanGenius &&
                  selectedSegments.isNotEmpty &&
                  (segmentCapability?.supportsRepeats ?? false)) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: cycles,
                  decoration: const InputDecoration(labelText: 'Cycles'),
                  items: [
                    for (var count = 1; count <= maximumCycles; count++)
                      DropdownMenuItem(
                        value: count,
                        child: Text(
                          '$count ${count == 1 ? 'cycle' : 'cycles'}',
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => cycles = value ?? cycles),
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
                      fanSpeed: usesCleanGenius || !customModeUsesSuction
                          ? null
                          : fanSpeed,
                      segmentIds: selectedSegments.toList(growable: false),
                      cycles: selectedSegments.isEmpty ? 1 : cycles,
                      settings: [
                        if (cleanGenius != null)
                          cleanGenius.copyWithValue(
                            _selectedValue(cleanGenius),
                          ),
                        if (!usesCleanGenius && cleaningMode != null)
                          cleaningMode.copyWithValue(
                            _selectedValue(cleaningMode),
                          ),
                        if (!usesCleanGenius && cleaningRoute != null)
                          cleaningRoute.copyWithValue(
                            _selectedValue(cleaningRoute),
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

  String _cleaningModeLabel(String value) {
    final normalized = value.toLowerCase().replaceAll('_', ' ').trim();
    if (normalized == 'sweeping' || normalized == 'vacuuming') return 'Vacuum';
    if (normalized == 'mopping') return 'Mop';
    if (normalized == 'sweeping and mopping' ||
        normalized == 'vacuum and mop') {
      return 'Vacuum & mop';
    }
    if (normalized == 'mopping after sweeping' ||
        normalized == 'mop after vacuum') {
      return 'Mop after vacuum';
    }
    return value;
  }
}

class _ScheduleSettingField extends StatelessWidget {
  const _ScheduleSettingField({
    super.key,
    required this.setting,
    required this.value,
    required this.onChanged,
    this.valueLabel,
  });

  final VacuumSetting setting;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String Function(String value)? valueLabel;

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
      items: [
        for (final choice in choices)
          DropdownMenuItem(
            value: choice,
            child: Text(
              setting.kind == VacuumSettingKind.toggle
                  ? (choice == 'on' ? 'On' : 'Off')
                  : (valueLabel?.call(choice) ?? choice),
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
