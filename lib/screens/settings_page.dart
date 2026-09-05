import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/home_assistant.dart';
import '../theme.dart';
import '../widgets/shared.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _searchController = TextEditingController();
  String _query = '';

  AppState get state => widget.state;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesSearch(VacuumSetting setting) {
    if (_query.isEmpty) return true;
    final searchable = [
      setting.name,
      setting.category,
      setting.entityId,
      setting.value,
      ...setting.options,
    ].join(' ').toLowerCase();
    return searchable.contains(_query);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<VacuumSetting>>{};
    final unavailableSettings = <VacuumSetting>[];
    for (final setting in state.vacuumSettings) {
      if (!_matchesSearch(setting)) continue;
      if (!setting.available) {
        unavailableSettings.add(setting);
        continue;
      }
      groups.putIfAbsent(setting.category, () => []).add(setting);
    }
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: '${state.vacuum.name} settings',
            subtitle:
                'Every setting your robot exposes through Home Assistant.',
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('edit-vacuum-name'),
              onPressed: () => _editVacuumName(context),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit vacuum name'),
            ),
          ),
          const SizedBox(height: 24),
          if (state.settingsLoading && state.vacuumSettings.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            )
          else if (state.settingsError != null && state.vacuumSettings.isEmpty)
            _EmptySettings(
              message: state.settingsError!,
              onRetry: state.refreshVacuumSettings,
            )
          else if (groups.isEmpty && unavailableSettings.isEmpty)
            if (_query.isEmpty)
              _EmptySettings(
                message:
                    'Home Assistant did not expose any configurable entities for this robot. Enable its switch, select, number, and button entities in Home Assistant, then refresh.',
                onRetry: state.refreshVacuumSettings,
              )
            else ...[
              _SettingsSearchField(
                controller: _searchController,
                query: _query,
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                onClear: _clearSearch,
              ),
              const SizedBox(height: 24),
              _NoSearchResults(
                query: _searchController.text.trim(),
                onClear: _clearSearch,
              ),
            ]
          else ...[
            _SettingsSearchField(
              controller: _searchController,
              query: _query,
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
              onClear: _clearSearch,
            ),
            const SizedBox(height: 24),
            if (state.settingsError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  state.settingsError!,
                  style: const TextStyle(color: coral),
                ),
              ),
            for (final group in groups.entries) ...[
              Row(
                children: [
                  Icon(_categoryIcon(group.key), color: fern, size: 22),
                  const SizedBox(width: 9),
                  Text(
                    group.key,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < group.value.length;
                      index++
                    ) ...[
                      _SettingTile(
                        setting: group.value[index],
                        state: state,
                        vacuumName: state.vacuum.name,
                      ),
                      if (index != group.value.length - 1)
                        Divider(
                          height: 1,
                          indent: 20,
                          endIndent: 20,
                          color: ink.withValues(alpha: .08),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (unavailableSettings.isNotEmpty) ...[
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  key: ValueKey('unavailable-settings-$_query'),
                  initiallyExpanded: _query.isNotEmpty,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  leading: const Icon(Icons.visibility_off_outlined),
                  title: Text(
                    'Unavailable settings (${unavailableSettings.length})',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('Tap to show'),
                  children: [
                    for (
                      var index = 0;
                      index < unavailableSettings.length;
                      index++
                    ) ...[
                      if (index == 0)
                        Divider(
                          height: 1,
                          indent: 20,
                          endIndent: 20,
                          color: ink.withValues(alpha: .08),
                        ),
                      _SettingTile(
                        setting: unavailableSettings[index],
                        state: state,
                        vacuumName: state.vacuum.name,
                      ),
                      if (index != unavailableSettings.length - 1)
                        Divider(
                          height: 1,
                          indent: 20,
                          endIndent: 20,
                          color: ink.withValues(alpha: .08),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Center(
              child: TextButton.icon(
                onPressed: state.settingsLoading
                    ? null
                    : state.refreshVacuumSettings,
                icon: state.settingsLoading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: const Text('Refresh supported settings'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) => switch (category) {
    'Carpets' => Icons.texture_rounded,
    'Cleaning' => Icons.auto_awesome_rounded,
    'Mopping' => Icons.water_drop_outlined,
    'Dock' => Icons.home_outlined,
    'Care & maintenance' => Icons.build_outlined,
    _ => Icons.tune_rounded,
  };

  Future<void> _editVacuumName(BuildContext context) async {
    final controller = TextEditingController(text: state.vacuum.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit vacuum name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Vacuum name'),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(context, value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null) await state.renameVacuum(name);
  }
}

class _SettingsSearchField extends StatelessWidget {
  const _SettingsSearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => TextField(
    key: const ValueKey('settings-search'),
    controller: controller,
    onChanged: onChanged,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: 'Search settings',
      prefixIcon: const Icon(Icons.search_rounded),
      suffixIcon: query.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear search',
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
            ),
      border: const OutlineInputBorder(),
    ),
  );
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => EmptyStatePanel(
    icon: Icons.search_off_rounded,
    title: 'No settings found',
    message: 'Nothing matches “$query”.',
    actionLabel: 'Clear search',
    actionIcon: Icons.close_rounded,
    onAction: onClear,
  );
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.setting,
    required this.state,
    required this.vacuumName,
  });

  final VacuumSetting setting;
  final AppState state;
  final String vacuumName;

  Future<void> _set(BuildContext context, Object? value) async {
    try {
      await state.setVacuumSetting(setting, value);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_message(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = state.busySettingIds.contains(setting.entityId);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      child: switch (setting.kind) {
        VacuumSettingKind.toggle => Row(
          children: [
            Expanded(
              child: _Label(setting: setting, vacuumName: vacuumName),
            ),
            if (busy)
              const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Switch.adaptive(
                value: setting.enabled,
                onChanged: setting.available
                    ? (value) => _set(context, value)
                    : null,
              ),
          ],
        ),
        VacuumSettingKind.select => Row(
          children: [
            Expanded(
              child: _Label(setting: setting, vacuumName: vacuumName),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 190),
              child: DropdownButton<String>(
                value: setting.options.contains(setting.value)
                    ? setting.value
                    : null,
                hint: Text(setting.value),
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: [
                  for (final option in setting.options)
                    DropdownMenuItem(value: option, child: Text(option)),
                ],
                onChanged: busy || !setting.available
                    ? null
                    : (value) {
                        if (value != null) _set(context, value);
                      },
              ),
            ),
          ],
        ),
        VacuumSettingKind.number => _NumberSetting(
          setting: setting,
          busy: busy,
          vacuumName: vacuumName,
          onChanged: (value) => _set(context, value),
        ),
        VacuumSettingKind.action => Row(
          children: [
            Expanded(
              child: _Label(setting: setting, vacuumName: vacuumName),
            ),
            FilledButton.tonal(
              onPressed: busy || !setting.available
                  ? null
                  : () => _set(context, null),
              child: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Run'),
            ),
          ],
        ),
      },
    );
  }
}

class _NumberSetting extends StatefulWidget {
  const _NumberSetting({
    required this.setting,
    required this.busy,
    required this.vacuumName,
    required this.onChanged,
  });

  final VacuumSetting setting;
  final bool busy;
  final String vacuumName;
  final ValueChanged<double> onChanged;

  @override
  State<_NumberSetting> createState() => _NumberSettingState();
}

class _NumberSettingState extends State<_NumberSetting> {
  late double value = _currentValue;

  double get _currentValue =>
      (double.tryParse(widget.setting.value) ?? widget.setting.minimum ?? 0)
          .clamp(widget.setting.minimum ?? 0, widget.setting.maximum ?? 100);

  @override
  void didUpdateWidget(covariant _NumberSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.setting.value != widget.setting.value) value = _currentValue;
  }

  @override
  Widget build(BuildContext context) {
    final minimum = widget.setting.minimum ?? 0;
    final maximum = widget.setting.maximum ?? 100;
    final step = widget.setting.step ?? 1;
    final divisions = step > 0 ? ((maximum - minimum) / step).round() : null;
    final display = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _Label(
                setting: widget.setting,
                vacuumName: widget.vacuumName,
              ),
            ),
            Text(
              '$display${widget.setting.unit == null ? '' : ' ${widget.setting.unit}'}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        Slider(
          value: value,
          min: minimum,
          max: maximum,
          divisions: divisions != null && divisions > 0 ? divisions : null,
          onChanged: widget.busy || !widget.setting.available
              ? null
              : (next) => setState(() => value = next),
          onChangeEnd: widget.onChanged,
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.setting, required this.vacuumName});

  final VacuumSetting setting;
  final String vacuumName;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _settingLabel(setting.name, vacuumName),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      if (!setting.available)
        Text(
          'Currently unavailable',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: coral),
        ),
    ],
  );
}

String _settingLabel(String settingName, String vacuumName) {
  final trimmedName = settingName.trim();
  final trimmedVacuumName = vacuumName.trim();
  if (trimmedVacuumName.isEmpty) return trimmedName;

  final prefix = RegExp(
    '^${RegExp.escape(trimmedVacuumName)}(?:\\s*[-–—:]\\s*|\\s+)',
    caseSensitive: false,
  );
  final label = trimmedName.replaceFirst(prefix, '').trim();
  return label.isEmpty ? trimmedName : label;
}

class _EmptySettings extends StatelessWidget {
  const _EmptySettings({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => EmptyStatePanel(
    icon: Icons.tune_rounded,
    title: 'No vacuum settings available',
    message: message,
    actionLabel: 'Try again',
    actionIcon: Icons.refresh_rounded,
    onAction: onRetry,
  );
}

String _message(Object error) => error.toString().replaceFirst(
  RegExp(r'^(Exception|FormatException):\s*'),
  '',
);
