import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/home_assistant.dart';
import '../theme.dart';
import '../widgets/shared.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key, required this.state});
  final AppState state;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _transformation = TransformationController();
  bool _labelMode = false;

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

  void _openFullscreen(Uint8List map) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullscreenMap(map: map, state: widget.state),
      ),
    );
  }

  Future<void> _addLabel(TapUpDetails details, Size size) async {
    final scenePosition = _transformation.toScene(details.localPosition);
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
      await widget.state.addMapRoomLabel(
        result.name,
        (scenePosition.dx / size.width).clamp(0.05, 0.95),
        (scenePosition.dy / size.height).clamp(0.05, 0.95),
        segmentId: result.segmentId,
      );
      if (mounted) setState(() => _labelMode = false);
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
    await widget.state.addMapRoomLabel(
      result.name,
      label.x,
      label.y,
      segmentId: result.segmentId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vacuum = widget.state.vacuum;
    final map = vacuum.mapImage;
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Your floor map',
            subtitle: map == null
                ? 'No compatible map entity was found for ${vacuum.name}.'
                : 'Tap the map for fullscreen, or add labels to your rooms.',
          ),
          const SizedBox(height: 24),
          Container(
            height: MediaQuery.sizeOf(context).width < 600 ? 470 : 620,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFDDE7DC),
              borderRadius: BorderRadius.circular(28),
            ),
            child: map == null
                ? _MapUnavailable(isDemo: widget.state.isDemo)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.biggest;
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: _labelMode
                                  ? null
                                  : () => _openFullscreen(map),
                              child: InteractiveViewer(
                                transformationController: _transformation,
                                minScale: 1,
                                maxScale: 5,
                                child: SizedBox.fromSize(
                                  size: size,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Image.memory(
                                          map,
                                          fit: BoxFit.contain,
                                          filterQuality: FilterQuality.high,
                                          gaplessPlayback: true,
                                        ),
                                      ),
                                      for (final label
                                          in widget.state.mapRoomLabels)
                                        Positioned(
                                          left: label.x * size.width,
                                          top: label.y * size.height,
                                          child: FractionalTranslation(
                                            translation: const Offset(
                                              -0.5,
                                              -0.5,
                                            ),
                                            child: InputChip(
                                              label: Text(label.name),
                                              tooltip: 'Rename ${label.name}',
                                              onPressed: () =>
                                                  _renameLabel(label),
                                              onDeleted: () => widget.state
                                                  .removeMapRoomLabel(label),
                                              deleteIcon: const Icon(
                                                Icons.close,
                                                size: 16,
                                              ),
                                              backgroundColor: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_labelMode)
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapUp: (details) => _addLabel(details, size),
                                child: Container(
                                  color: fern.withValues(alpha: .08),
                                  alignment: Alignment.bottomCenter,
                                  padding: const EdgeInsets.all(18),
                                  child: const Chip(
                                    avatar: Icon(Icons.touch_app_rounded),
                                    label: Text(
                                      'Tap inside a room to label it',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            left: 18,
                            top: 18,
                            child: Chip(
                              avatar: const Icon(
                                Icons.circle,
                                color: coral,
                                size: 12,
                              ),
                              label: Text(
                                prettyState(vacuum.state),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              backgroundColor: Colors.white,
                            ),
                          ),
                          Positioned(
                            right: 18,
                            top: 18,
                            child: FloatingActionButton.small(
                              heroTag: 'map-label',
                              tooltip: _labelMode
                                  ? 'Cancel room label'
                                  : 'Label a room',
                              backgroundColor: _labelMode ? fern : Colors.white,
                              foregroundColor: _labelMode ? Colors.white : ink,
                              onPressed: () =>
                                  setState(() => _labelMode = !_labelMode),
                              child: Icon(
                                _labelMode
                                    ? Icons.close
                                    : Icons.label_outline_rounded,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 18,
                            bottom: 18,
                            child: Column(
                              children: [
                                FloatingActionButton.small(
                                  heroTag: 'map-plus',
                                  backgroundColor: Colors.white,
                                  foregroundColor: ink,
                                  onPressed: () => _zoom(1.35),
                                  child: const Icon(Icons.add),
                                ),
                                const SizedBox(height: 8),
                                FloatingActionButton.small(
                                  heroTag: 'map-minus',
                                  backgroundColor: Colors.white,
                                  foregroundColor: ink,
                                  onPressed: () => _zoom(1 / 1.35),
                                  child: const Icon(Icons.remove),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
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

class _FullscreenMap extends StatefulWidget {
  const _FullscreenMap({required this.map, required this.state});
  final Uint8List map;
  final AppState state;

  @override
  State<_FullscreenMap> createState() => _FullscreenMapState();
}

class _FullscreenMapState extends State<_FullscreenMap> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ink,
      body: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transformation,
                minScale: 1,
                maxScale: 5,
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.memory(
                          widget.map,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          gaplessPlayback: true,
                        ),
                      ),
                      for (final label in widget.state.mapRoomLabels)
                        Positioned(
                          left: label.x * constraints.maxWidth,
                          top: label.y * constraints.maxHeight,
                          child: FractionalTranslation(
                            translation: const Offset(-0.5, -0.5),
                            child: Chip(
                              label: Text(label.name),
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 16,
              child: FloatingActionButton.small(
                heroTag: 'fullscreen-close',
                tooltip: 'Close fullscreen map',
                backgroundColor: Colors.white,
                foregroundColor: ink,
                onPressed: () => Navigator.pop(context),
                child: const Icon(Icons.close_rounded),
              ),
            ),
            Positioned(
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 18,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'fullscreen-plus',
                    backgroundColor: Colors.white,
                    foregroundColor: ink,
                    onPressed: () => _zoom(1.35),
                    child: const Icon(Icons.add),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'fullscreen-minus',
                    backgroundColor: Colors.white,
                    foregroundColor: ink,
                    onPressed: () => _zoom(1 / 1.35),
                    child: const Icon(Icons.remove),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable({required this.isDemo});
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: Icon(Icons.map_outlined, color: fern, size: 30),
              ),
              const SizedBox(height: 18),
              Text(
                isDemo ? 'No live map in demo mode' : 'Map feed unavailable',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                isDemo
                    ? 'Connect Home Assistant to display a map supplied by your vacuum integration.'
                    : 'Scrubby looks for a camera or image entity whose name contains “map” or “floor”. Enable that entity in your vacuum integration, then reconnect.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
