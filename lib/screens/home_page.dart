import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../theme.dart';
import '../widgets/shared.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.state, required this.onOpenMap});
  final AppState state;
  final VoidCallback onOpenMap;

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
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: mint,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 8, color: fern),
                  const SizedBox(width: 7),
                  Text(
                    prettyState(vacuum.state),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: fern,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 760;
              final hero = _ControlHero(state: state);
              final side = _StatusColumn(state: state, onOpenMap: onOpenMap);
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
  const _ControlHero({required this.state});
  final AppState state;

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
    return Container(
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vacuum.name,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    vacuum.isDocked ? 'On the dock' : prettyState(vacuum.state),
                    style: const TextStyle(color: Colors.white54),
                  ),
                ],
              ),
              const Spacer(),
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
            ],
          ),
          const Spacer(),
          Center(
            child: Semantics(
              button: true,
              label: vacuum.isCleaning ? 'Pause cleaning' : 'Start cleaning',
              child: InkWell(
                onTap: state.isBusy
                    ? null
                    : () => _action(context, state.toggleCleaning),
                customBorder: const CircleBorder(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  width: 174,
                  height: 174,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: vacuum.isCleaning ? coral : mint,
                    boxShadow: [
                      BoxShadow(
                        color: (vacuum.isCleaning ? coral : mint).withValues(
                          alpha: .18,
                        ),
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
                              vacuum.isCleaning ? 'PAUSE' : 'START',
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
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MiniAction(
                icon: Icons.home_rounded,
                label: 'Dock',
                onTap: () => _action(context, state.dock),
              ),
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
    );
  }
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
  const _StatusColumn({required this.state, required this.onOpenMap});
  final AppState state;
  final VoidCallback onOpenMap;

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
        SizedBox(
          height: 250,
          child: SurfaceCard(
            padding: EdgeInsets.zero,
            child: InkWell(
              onTap: onOpenMap,
              borderRadius: BorderRadius.circular(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: state.vacuum.mapImage == null
                          ? Container(
                              color: const Color(0xFFE2EADF),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(28),
                              child: const Text(
                                'No map entity found',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: fern,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : Image.memory(
                              state.vacuum.mapImage!,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                    ),
                    Positioned(
                      left: 20,
                      top: 18,
                      child: Text(
                        'Live map',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const Positioned(
                      right: 18,
                      top: 16,
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(Icons.arrow_outward_rounded, color: fern),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      bottom: 18,
                      child: Text(
                        'Tap to view route',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
