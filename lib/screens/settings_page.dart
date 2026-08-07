import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/home_assistant.dart';
import '../theme.dart';
import '../widgets/shared.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<VacuumSetting>>{};
    final unavailableSettings = <VacuumSetting>[];
    for (final setting in state.vacuumSettings) {
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
            _EmptySettings(
              message:
                  'Home Assistant did not expose any configurable entities for this robot. Enable its switch, select, number, and button entities in Home Assistant, then refresh.',
              onRetry: state.refreshVacuumSettings,
            )
          else ...[
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
                      _SettingTile(setting: group.value[index], state: state),
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
                  key: const ValueKey('unavailable-settings'),
                  initiallyExpanded: false,
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
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({required this.setting, required this.state});

  final VacuumSetting setting;
  final AppState state;

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
            Expanded(child: _Label(setting: setting)),
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
            Expanded(child: _Label(setting: setting)),
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
          onChanged: (value) => _set(context, value),
        ),
        VacuumSettingKind.action => Row(
          children: [
            Expanded(child: _Label(setting: setting)),
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
    required this.onChanged,
  });

  final VacuumSetting setting;
  final bool busy;
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
            Expanded(child: _Label(setting: widget.setting)),
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
  const _Label({required this.setting});

  final VacuumSetting setting;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(setting.name, style: const TextStyle(fontWeight: FontWeight.w700)),
      if (!setting.available)
        Text(
          'Currently unavailable',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: coral),
        ),
    ],
  );
}

class _EmptySettings extends StatelessWidget {
  const _EmptySettings({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      children: [
        const Icon(Icons.tune_rounded, size: 38, color: fern),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}

String _message(Object error) => error.toString().replaceFirst(
  RegExp(r'^(Exception|FormatException):\s*'),
  '',
);
