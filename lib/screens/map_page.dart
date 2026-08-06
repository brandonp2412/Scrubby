import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
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
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Label this room'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Kitchen'),
          onSubmitted: (value) {
            final name = value.trim();
            if (name.isNotEmpty) Navigator.pop(context, name);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.pop(context, name);
            },
            child: const Text('Add label'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !mounted) return;
    widget.state.addMapRoomLabel(
      name,
      (details.localPosition.dx / size.width).clamp(0.05, 0.95),
      (details.localPosition.dy / size.height).clamp(0.05, 0.95),
    );
    setState(() => _labelMode = false);
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
                                child: Center(
                                  child: Image.memory(
                                    map,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                    gaplessPlayback: true,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          for (final label in widget.state.mapRoomLabels)
                            Positioned(
                              left: label.x * size.width,
                              top: label.y * size.height,
                              child: FractionalTranslation(
                                translation: const Offset(-0.5, -0.5),
                                child: InputChip(
                                  label: Text(label.name),
                                  onDeleted: () =>
                                      widget.state.removeMapRoomLabel(label),
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  backgroundColor: Colors.white,
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
                child: Center(
                  child: Image.memory(
                    widget.map,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    gaplessPlayback: true,
                  ),
                ),
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
