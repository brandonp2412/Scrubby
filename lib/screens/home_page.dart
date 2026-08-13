import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/home_assistant.dart';
import '../theme.dart';
import '../widgets/shared.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.state,
    required this.onOpenSettings,
  });
  final AppState state;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final vacuum = state.vacuum;
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: _greeting(),
            subtitle: vacuum.isCleaning
                ? '${vacuum.name} is making the floors lovely.'
                : '${vacuum.name} is ready when you are.',
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 760;
              final hero = _ControlHero(
                state: state,
                onOpenSettings: onOpenSettings,
              );
              final side = _StatusColumn(state: state);
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: hero),
                        const SizedBox(width: 18),
                        Expanded(flex: 4, child: side),
                      ],
                    )
                  : Column(children: [hero, const SizedBox(height: 18), side]);
            },
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Today at a glance',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'THU, 6 AUG',
                maxLines: 1,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth > 640
                  ? (constraints.maxWidth - 24) / 3
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Metric(
                    width: itemWidth,
                    icon: Icons.route_rounded,
                    value: '1.24 km',
                    label: 'Travelled',
                    onTap: () => _showMetric(
                      context,
                      title: 'Distance travelled',
                      value: '1.24 km',
                      detail: 'Distance covered during today’s cleaning runs.',
                    ),
                  ),
                  _Metric(
                    width: itemWidth,
                    icon: Icons.square_foot_rounded,
                    value: '68 m²',
                    label: 'Cleaned',
                    onTap: () => _showMetric(
                      context,
                      title: 'Area cleaned',
                      value: '68 m²',
                      detail: 'Floor area completed by your vacuum today.',
                    ),
                  ),
                  _Metric(
                    width: itemWidth,
                    icon: Icons.timer_outlined,
                    value: '42 min',
                    label: 'Run time',
                    onTap: () => _showMetric(
                      context,
                      title: 'Cleaning time',
                      value: '42 min',
                      detail: 'Total time spent cleaning today.',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    return hour < 12
        ? 'Good morning.'
        : hour < 18
        ? 'Good afternoon.'
        : 'Good evening.';
  }

  void _showMetric(
    BuildContext context, {
    required String title,
    required String value,
    required String detail,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cream,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(value, style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: 10),
              Text(detail, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlHero extends StatelessWidget {
  const _ControlHero({required this.state, required this.onOpenSettings});
  final AppState state;
  final VoidCallback onOpenSettings;

  Future<void> _action(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vacuum = state.vacuum;
    return Semantics(
      key: const ValueKey('open-vacuum-settings'),
      button: true,
      label: 'Open ${vacuum.name} settings',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpenSettings,
        child: Container(
          height: 400,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2217211E),
                blurRadius: 35,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vacuum.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          vacuum.isDocked
                              ? 'On the dock'
                              : prettyState(vacuum.state),
                          style: const TextStyle(color: Colors.white54),
                        ),
                        const SizedBox(height: 7),
                        const Row(
                          children: [
                            Icon(
                              Icons.settings_outlined,
                              size: 15,
                              color: Colors.white70,
                            ),
                            SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Tap for settings',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    vacuum.battery == null
                        ? Icons.battery_unknown_rounded
                        : Icons.battery_5_bar_rounded,
                    color: (vacuum.battery ?? 100) < 20 ? coral : mint,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    vacuum.battery == null ? '—' : '${vacuum.battery}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white54,
                  ),
                ],
              ),
              const Spacer(),
              Center(
                child: Semantics(
                  button: true,
                  label: vacuum.isCleaning
                      ? 'Pause cleaning'
                      : vacuum.isPaused
                      ? 'Resume cleaning'
                      : 'Start cleaning',
                  child: InkWell(
                    onTap: state.isBusy
                        ? null
                        : () => _action(context, state.toggleCleaning),
                    customBorder: const CircleBorder(),
                    child: _Heartbeat(
                      active: vacuum.isCleaning,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        width: 174,
                        height: 174,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: vacuum.isCleaning ? coral : mint,
                          boxShadow: [
                            BoxShadow(
                              color: (vacuum.isCleaning ? coral : mint)
                                  .withValues(alpha: .18),
                              blurRadius: 0,
                              spreadRadius: 14,
                            ),
                          ],
                        ),
                        child: state.isBusy
                            ? const Padding(
                                padding: EdgeInsets.all(70),
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: ink,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    vacuum.isCleaning
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 55,
                                    color: ink,
                                  ),
                                  Text(
                                    vacuum.isCleaning
                                        ? 'PAUSE'
                                        : vacuum.isPaused
                                        ? 'RESUME'
                                        : 'START',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                      color: ink,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MiniAction(
                    icon: Icons.home_rounded,
                    label: 'Dock',
                    onTap: () => _action(context, state.dock),
                  ),
                  if (vacuum.isPaused) ...[
                    const SizedBox(width: 14),
                    _MiniAction(
                      icon: Icons.stop_rounded,
                      label: 'End clean',
                      onTap: () => _action(context, state.stopCleaning),
                    ),
                  ],
                  const SizedBox(width: 14),
                  _MiniAction(
                    icon: Icons.volume_up_outlined,
                    label: 'Find',
                    onTap: () => _action(context, state.locate),
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

class _Heartbeat extends StatefulWidget {
  const _Heartbeat({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_Heartbeat> createState() => _HeartbeatState();
}

class _HeartbeatState extends State<_Heartbeat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );
  late final Animation<double> _pulse = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.055), weight: 12),
    TweenSequenceItem(tween: Tween(begin: 1.055, end: 1), weight: 12),
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.035), weight: 10),
    TweenSequenceItem(tween: Tween(begin: 1.035, end: 1), weight: 10),
    TweenSequenceItem(tween: ConstantTween(1), weight: 56),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _Heartbeat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    widget.active ? _controller.repeat() : _controller.animateBack(0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _pulse, child: widget.child);
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white70,
        side: const BorderSide(color: Colors.white24),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
      ),
    );
  }
}

class _StatusColumn extends StatelessWidget {
  const _StatusColumn({required this.state});
  final AppState state;

  Future<void> _chooseSuction(BuildContext context) async {
    final vacuum = state.vacuum;
    final speeds = vacuum.fanSpeeds.isEmpty
        ? const ['Quiet', 'Balanced', 'Turbo']
        : vacuum.fanSpeeds;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cream,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Suction power',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 10),
              for (final speed in speeds)
                ListTile(
                  title: Text(speed),
                  leading: Icon(
                    speed == vacuum.fanSpeed
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: speed == vacuum.fanSpeed ? fern : Colors.black26,
                  ),
                  onTap: () => Navigator.pop(context, speed),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !context.mounted) return;
    try {
      await state.setFanSpeed(selected);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 320, child: _HomeMapCard(state: state)),
        const SizedBox(height: 18),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: InkWell(
            onTap: state.isBusy ? null : () => _chooseSuction(context),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: mint,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.air_rounded, color: fern),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Suction',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        state.vacuum.fanSpeed ?? 'Standard',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.black38,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeMapCard extends StatefulWidget {
  const _HomeMapCard({required this.state, this.fullScreen = false});

  final AppState state;
  final bool fullScreen;

  @override
  State<_HomeMapCard> createState() => _HomeMapCardState();
}

class _HomeMapCardState extends State<_HomeMapCard> {
  final _transformation = TransformationController();

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final current = _transformation.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(1.0, 5.0);
    _transformation.value = Matrix4.diagonal3Values(target, target, 1);
  }

  void _openFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _FullScreenMap(state: widget.state),
      ),
    );
  }

  Future<void> _addLabel() async {
    final result = await showDialog<_RoomLabelResult>(
      context: context,
      builder: (context) => _RoomLabelDialog(
        segments: widget.state.vacuumSegments,
        unavailableSegmentIds: widget.state.mapRoomLabels
            .map((label) => label.segmentId)
            .nonNulls
            .toSet(),
      ),
    );
    if (result == null || !mounted) return;
    try {
      await widget.state.addMapRoomLabel(result.name, result.segmentId!);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst(
        RegExp(r'^(Exception|FormatException):\s*'),
        '',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save the room label: $message')),
      );
    }
  }

  Future<void> _renameLabel(MapRoomLabel label) async {
    final result = await showDialog<_RoomLabelResult>(
      context: context,
      builder: (context) => _RoomLabelDialog(
        initialName: label.name,
        initialSegmentId: label.segmentId,
        segments: widget.state.vacuumSegments,
        unavailableSegmentIds: widget.state.mapRoomLabels
            .where((item) => item.id != label.id)
            .map((item) => item.segmentId)
            .nonNulls
            .toSet(),
      ),
    );
    if (result == null || !mounted) return;
    await widget.state.addMapRoomLabel(result.name, result.segmentId!);
  }

  String _segmentName(MapRoomLabel label) {
    final index = widget.state.vacuumSegments.indexWhere(
      (segment) => segment.id == label.segmentId,
    );
    return index < 0 ? 'Mapped room' : 'Room ${index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final map = widget.state.vacuum.mapImage;
    final card = SurfaceCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: map == null
            ? Container(
                color: const Color(0xFFE2EADF),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(28),
                child: const Text(
                  'No map entity found',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: fern, fontWeight: FontWeight.w700),
                ),
              )
            : ColoredBox(
                color: Colors.black,
                child: widget.fullScreen
                    ? Stack(
                        children: [
                          Positioned.fill(
                            child: InteractiveViewer(
                              transformationController: _transformation,
                              minScale: 1,
                              maxScale: 5,
                              child: Image.memory(
                                map,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                                gaplessPlayback: true,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 12,
                            top: 12,
                            child: FloatingActionButton.small(
                              heroTag: 'home-map-label',
                              tooltip: 'Name a room',
                              backgroundColor: Colors.white,
                              foregroundColor: ink,
                              onPressed: _addLabel,
                              child: const Icon(Icons.label_outline_rounded),
                            ),
                          ),
                          Positioned(
                            right: 12,
                            top: 68,
                            child: Column(
                              children: [
                                FloatingActionButton.small(
                                  heroTag: 'home-map-plus',
                                  tooltip: 'Zoom in',
                                  backgroundColor: Colors.white,
                                  foregroundColor: ink,
                                  onPressed: () => _zoom(1.35),
                                  child: const Icon(Icons.add),
                                ),
                                const SizedBox(height: 6),
                                FloatingActionButton.small(
                                  heroTag: 'home-map-minus',
                                  tooltip: 'Zoom out',
                                  backgroundColor: Colors.white,
                                  foregroundColor: ink,
                                  onPressed: () => _zoom(1 / 1.35),
                                  child: const Icon(Icons.remove),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Image.memory(
                        map,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        gaplessPlayback: true,
                      ),
              ),
      ),
    );
    final roomKey = widget.state.mapRoomLabels.isEmpty
        ? const SizedBox.shrink()
        : Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            color: Colors.white.withValues(alpha: .82),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final label in widget.state.mapRoomLabels)
                  GestureDetector(
                    onTap: widget.fullScreen ? () => _renameLabel(label) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cream,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ink.withValues(alpha: .1)),
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${_segmentName(label)}  ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            TextSpan(text: label.name),
                            if (widget.fullScreen) const TextSpan(text: '  ✎'),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
    if (widget.fullScreen) {
      return SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(child: card),
            roomKey,
          ],
        ),
      );
    }
    return Semantics(
      button: true,
      label: 'Open map full screen',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openFullScreen,
        child: Column(
          children: [
            Expanded(child: card),
            roomKey,
          ],
        ),
      ),
    );
  }
}

class _FullScreenMap extends StatelessWidget {
  const _FullScreenMap({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${state.vacuum.name} map')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: _HomeMapCard(state: state, fullScreen: true),
      ),
    );
  }
}

class _RoomLabelDialog extends StatefulWidget {
  const _RoomLabelDialog({
    required this.segments,
    required this.unavailableSegmentIds,
    this.initialName,
    this.initialSegmentId,
  });

  final String? initialName;
  final String? initialSegmentId;
  final List<VacuumSegment> segments;
  final Set<String> unavailableSegmentIds;

  @override
  State<_RoomLabelDialog> createState() => _RoomLabelDialogState();
}

class _RoomLabelDialogState extends State<_RoomLabelDialog> {
  late final _controller = TextEditingController(text: widget.initialName);
  late String? _segmentId =
      widget.initialSegmentId ??
      widget.segments
          .where(
            (segment) => !widget.unavailableSegmentIds.contains(segment.id),
          )
          .firstOrNull
          ?.id;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty && (widget.segments.isEmpty || _segmentId != null)) {
      Navigator.pop(
        context,
        _RoomLabelResult(name: name, segmentId: _segmentId),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initialName == null ? 'Label this room' : 'Rename room'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.segments.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            initialValue: _segmentId,
            decoration: const InputDecoration(labelText: 'Vacuum room'),
            items: [
              for (final segment in widget.segments)
                DropdownMenuItem(
                  value: segment.id,
                  enabled:
                      segment.id == widget.initialSegmentId ||
                      !widget.unavailableSegmentIds.contains(segment.id),
                  child: Text(segment.name),
                ),
            ],
            onChanged: (value) => setState(() => _segmentId = value),
          ),
          const SizedBox(height: 14),
        ],
        TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Display name'),
          onSubmitted: (_) => _submit(),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(widget.initialName == null ? 'Add label' : 'Save name'),
      ),
    ],
  );
}

class _RoomLabelResult {
  const _RoomLabelResult({required this.name, required this.segmentId});

  final String name;
  final String? segmentId;
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.width,
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
  });
  final double width;
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: SurfaceCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Icon(icon, color: fern),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(label, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const Spacer(),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.black26,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
