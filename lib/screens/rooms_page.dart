import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/home_assistant.dart';
import '../theme.dart';
import '../widgets/shared.dart';

class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key, required this.state});
  final AppState state;

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  final selected = <String>{};
  String? mode;
  String? cleaningMode;

  @override
  void initState() {
    super.initState();
    mode = widget.state.vacuum.fanSpeed;
    cleaningMode = _cleaningModeSetting?.value;
  }

  @override
  void didUpdateWidget(covariant RoomsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.vacuum.entityId != widget.state.vacuum.entityId) {
      selected.clear();
      mode = widget.state.vacuum.fanSpeed;
      cleaningMode = _cleaningModeSetting?.value;
    }
  }

  static const _icons = [
    Icons.countertops_outlined,
    Icons.weekend_outlined,
    Icons.bed_outlined,
    Icons.meeting_room_outlined,
  ];
  static const _colors = [
    Color(0xFFD9F1E3),
    Color(0xFFFFE6BE),
    Color(0xFFDDE5FF),
    Color(0xFFFFDBD1),
  ];

  VacuumSetting? get _cleaningModeSetting {
    final matches = widget.state.vacuumSettings.where((setting) {
      final name = '${setting.name} ${setting.entityId}'
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
      return setting.kind == VacuumSettingKind.select &&
          name.contains('cleaning mode') &&
          !name.contains('carpet cleaning mode') &&
          !RegExp(r'_room_\d+_cleaning_mode$').hasMatch(setting.entityId) &&
          setting.options.isNotEmpty;
    });
    return matches.firstOrNull;
  }

  String? get _effectiveCleaningMode =>
      _validCleaningMode(_cleaningModeSetting);

  String? _validCleaningMode(VacuumSetting? setting) {
    if (setting == null || setting.options.isEmpty) return null;
    if (cleaningMode != null && setting.options.contains(cleaningMode)) {
      return cleaningMode;
    }
    if (setting.options.contains(setting.value)) return setting.value;
    return setting.options.first;
  }

  bool get _modeUsesSuction {
    final normalized = _effectiveCleaningMode
        ?.toLowerCase()
        .replaceAll('_', ' ')
        .trim();
    return normalized != 'mop' && normalized != 'mopping';
  }

  @override
  Widget build(BuildContext context) {
    final powerModes = widget.state.vacuum.fanSpeeds.isEmpty
        ? const ['Quiet', 'Balanced', 'Turbo']
        : widget.state.vacuum.fanSpeeds;
    final selectedPowerMode = powerModes.contains(mode)
        ? mode
        : powerModes.contains(widget.state.vacuum.fanSpeed)
        ? widget.state.vacuum.fanSpeed
        : powerModes.first;
    final cleaningModeSetting = _cleaningModeSetting;
    final labelsBySegment = {
      for (final label in widget.state.mapRoomLabels) label.segmentId: label,
    };
    final rooms = <_RoomChoice>[
      for (final segment in widget.state.vacuumSegments)
        _RoomChoice(
          id: segment.id,
          name: labelsBySegment[segment.id]?.name ?? segment.name,
          segmentId: segment.id,
          isLabelled: labelsBySegment.containsKey(segment.id),
        ),
    ];
    final roomIds = rooms.map((room) => room.id).toSet();
    final activeSelection = selected.intersection(roomIds);
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Choose your rooms',
            subtitle: 'Send your vacuum exactly where it’s needed.',
          ),
          const SizedBox(height: 24),
          if (rooms.isEmpty)
            _NoRoomsCard(
              error: widget.state.roomCapabilityError,
              onRetry: widget.state.refreshRooms,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 700 ? 2 : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 14) / columns;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (var index = 0; index < rooms.length; index++)
                      SizedBox(
                        width: width,
                        child: _RoomCard(
                          name: rooms[index].name,
                          icon: _icons[index % _icons.length],
                          color: _colors[index % _colors.length],
                          selected: activeSelection.contains(rooms[index].id),
                          linked: rooms[index].segmentId != null,
                          labelled: rooms[index].isLabelled,
                          onTap: rooms[index].segmentId == null
                              ? null
                              : () => setState(() {
                                  final id = rooms[index].id;
                                  selected.contains(id)
                                      ? selected.remove(id)
                                      : selected.add(id);
                                }),
                        ),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 24),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cleaning power',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                if (cleaningModeSetting != null) ...[
                  DropdownButtonFormField<String>(
                    key: const ValueKey('manual-cleaning-mode'),
                    isExpanded: true,
                    initialValue: _effectiveCleaningMode,
                    decoration: const InputDecoration(
                      labelText: 'Cleaning mode',
                    ),
                    items: [
                      for (final option in cleaningModeSetting.options)
                        DropdownMenuItem(
                          value: option,
                          child: OptionLabel(
                            value: option,
                            label: _cleaningModeLabel(option),
                            field: 'Cleaning mode',
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => cleaningMode = value),
                  ),
                  if (_modeUsesSuction) const SizedBox(height: 14),
                ] else ...[
                  Text(
                    'Cleaning mode is not exposed by Home Assistant. Enable the vacuum’s Cleaning mode select entity, then refresh its settings.',
                    key: const ValueKey('manual-cleaning-mode-unavailable'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                ],
                if (_modeUsesSuction)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    items: powerModes
                        .map(
                          (powerMode) => DropdownMenuItem(
                            value: powerMode,
                            child: OptionLabel(
                              value: powerMode,
                              field: 'Suction power',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      mode = value;
                    }),
                    initialValue: selectedPowerMode,
                    decoration: const InputDecoration(
                      labelText: 'Suction power',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton.icon(
              onPressed: activeSelection.isEmpty
                  ? null
                  : () => _start(activeSelection, rooms),
              style: FilledButton.styleFrom(
                backgroundColor: fern,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                activeSelection.isEmpty
                    ? 'Choose at least one room'
                    : 'Clean ${activeSelection.length} ${activeSelection.length == 1 ? 'room' : 'rooms'}',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _start(Set<String> selectedIds, List<_RoomChoice> rooms) async {
    final selectedRooms = rooms
        .where((room) => selectedIds.contains(room.id))
        .toList(growable: false);
    final roomNames = selectedRooms
        .map((room) => room.name)
        .toList(growable: false);
    try {
      final supportedPower = widget.state.vacuum.fanSpeeds;
      final selectedPower = supportedPower.contains(mode)
          ? mode!
          : supportedPower.contains(widget.state.vacuum.fanSpeed)
          ? widget.state.vacuum.fanSpeed!
          : (supportedPower.isEmpty ? 'Balanced' : supportedPower.first);
      final cleaningModeSetting = _cleaningModeSetting;
      final selectedCleaningMode = _effectiveCleaningMode;
      if (cleaningModeSetting != null && selectedCleaningMode != null) {
        await widget.state.setVacuumSetting(
          cleaningModeSetting,
          selectedCleaningMode,
        );
      }
      if (_modeUsesSuction) await widget.state.setFanSpeed(selectedPower);
      await widget.state.cleanRooms(
        selectedRooms.map((room) => room.segmentId!).toList(growable: false),
      );
      if (mounted) {
        setState(selected.clear);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: fern,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cleaning started — ${roomNames.join(', ')}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  String _cleaningModeLabel(String value) {
    final normalized = value.toLowerCase().replaceAll('_', ' ').trim();
    if (normalized == 'sweeping' || normalized == 'vacuuming') return 'Vacuum';
    if (normalized == 'mopping') return 'Mop';
    if (normalized == 'sweeping and mopping' ||
        normalized == 'vacuum and mop') {
      return 'Vacuum & mop';
    }
    return value;
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.name,
    required this.icon,
    required this.color,
    required this.selected,
    required this.linked,
    required this.labelled,
    required this.onTap,
  });
  final String name;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool linked;
  final bool labelled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: selected ? color : Colors.white.withValues(alpha: .72),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? fern : ink.withValues(alpha: .06),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withValues(alpha: .62) : color,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: fern),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      linked
                          ? labelled
                                ? 'Mapped room'
                                : 'Vacuum room · label it on the map'
                          : 'Not linked to a vacuum room',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  color: selected ? fern : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? fern : ink.withValues(alpha: .18),
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 17,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoRoomsCard extends StatelessWidget {
  const _NoRoomsCard({this.error, required this.onRetry});

  final String? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => EmptyStatePanel(
    icon: Icons.meeting_room_outlined,
    title: 'No cleanable rooms found',
    message:
        error ??
        'Home Assistant did not report any cleanable rooms for this vacuum.',
    actionLabel: 'Try again',
    actionIcon: Icons.refresh_rounded,
    onAction: onRetry,
  );
}

class _RoomChoice {
  const _RoomChoice({
    required this.id,
    required this.name,
    required this.isLabelled,
    this.segmentId,
  });

  final String id;
  final String name;
  final String? segmentId;
  final bool isLabelled;
}
