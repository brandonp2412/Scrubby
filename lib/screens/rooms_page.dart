import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../theme.dart';
import '../widgets/shared.dart';

class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key, required this.state});
  final AppState state;

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  final selected = <String>{'Kitchen', 'Living room'};
  String mode = 'Balanced';

  static const rooms = [
    ('Kitchen', Icons.countertops_outlined, Color(0xFFD9F1E3), '18 m²'),
    ('Living room', Icons.weekend_outlined, Color(0xFFFFE6BE), '26 m²'),
    ('Bedroom', Icons.bed_outlined, Color(0xFFDDE5FF), '16 m²'),
    ('Hallway', Icons.meeting_room_outlined, Color(0xFFFFDBD1), '8 m²'),
  ];

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Choose your rooms',
            subtitle: 'Send your vacuum exactly where it’s needed.',
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 700 ? 2 : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 14) / columns;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final room in rooms)
                    SizedBox(
                      width: width,
                      child: _RoomCard(
                        name: room.$1,
                        icon: room.$2,
                        color: room.$3,
                        area: room.$4,
                        selected: selected.contains(room.$1),
                        onTap: () => setState(
                          () => selected.contains(room.$1)
                              ? selected.remove(room.$1)
                              : selected.add(room.$1),
                        ),
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final showIcons = constraints.maxWidth >= 440;
                    Text label(String value) => Text(
                      value,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                    );
                    return SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'Quiet',
                            icon: showIcons
                                ? const Icon(Icons.air_rounded)
                                : null,
                            label: label('Quiet'),
                          ),
                          ButtonSegment(
                            value: 'Balanced',
                            icon: showIcons
                                ? const Icon(Icons.tune_rounded)
                                : null,
                            label: label('Balanced'),
                          ),
                          ButtonSegment(
                            value: 'Turbo',
                            icon: showIcons
                                ? const Icon(Icons.bolt_rounded)
                                : null,
                            label: label('Turbo'),
                          ),
                        ],
                        selected: {mode},
                        onSelectionChanged: (value) =>
                            setState(() => mode = value.first),
                        showSelectedIcon: false,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton.icon(
              onPressed: selected.isEmpty ? null : _start,
              style: FilledButton.styleFrom(
                backgroundColor: fern,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                selected.isEmpty
                    ? 'Choose at least one room'
                    : 'Clean ${selected.length} ${selected.length == 1 ? 'room' : 'rooms'}',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _start() async {
    try {
      await widget.state.toggleCleaning();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.state.vacuum.name} is heading to ${selected.join(', ')}.',
            ),
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
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.name,
    required this.icon,
    required this.color,
    required this.area,
    required this.selected,
    required this.onTap,
  });
  final String name;
  final IconData icon;
  final Color color;
  final String area;
  final bool selected;
  final VoidCallback onTap;

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
                    Text(area, style: Theme.of(context).textTheme.bodyMedium),
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
