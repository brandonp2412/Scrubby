import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/shared.dart';

enum HistoryMetric { overview, travelled, cleaned, runTime }

class CleaningHistoryPage extends StatefulWidget {
  const CleaningHistoryPage({
    super.key,
    this.initialMetric = HistoryMetric.overview,
  });

  final HistoryMetric initialMetric;

  @override
  State<CleaningHistoryPage> createState() => _CleaningHistoryPageState();
}

class _CleaningHistoryPageState extends State<CleaningHistoryPage> {
  late HistoryMetric _metric = widget.initialMetric;

  static const _days = ['Fri', 'Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Today'];
  static const _history = [
    _CleaningRun('Today, 9:12 AM', 'Whole home', '1.24 km', '68 m²', '42 min'),
    _CleaningRun(
      'Yesterday, 10:04 AM',
      'Kitchen + lounge',
      '0.86 km',
      '47 m²',
      '31 min',
    ),
    _CleaningRun('Tuesday, 8:45 AM', 'Bedrooms', '0.72 km', '39 m²', '27 min'),
    _CleaningRun('Monday, 9:02 AM', 'Whole home', '1.31 km', '71 m²', '45 min'),
    _CleaningRun('Saturday, 11:20 AM', 'Kitchen', '0.38 km', '21 m²', '16 min'),
  ];

  @override
  Widget build(BuildContext context) {
    final details = _detailsFor(_metric);
    return Scaffold(
      appBar: AppBar(title: const Text('Cleaning history')),
      body: PageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A look back at how your vacuum has been helping.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 22),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<HistoryMetric>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: HistoryMetric.overview,
                    label: Text('Overview'),
                  ),
                  ButtonSegment(
                    value: HistoryMetric.travelled,
                    label: Text('Travelled'),
                  ),
                  ButtonSegment(
                    value: HistoryMetric.cleaned,
                    label: Text('Cleaned'),
                  ),
                  ButtonSegment(
                    value: HistoryMetric.runTime,
                    label: Text('Run time'),
                  ),
                ],
                selected: {_metric},
                onSelectionChanged: (value) =>
                    setState(() => _metric = value.single),
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final chart = _TrendCard(details: details);
                final summary = _SummaryCard(details: details);
                if (constraints.maxWidth < 680) {
                  return Column(
                    children: [summary, const SizedBox(height: 12), chart],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 4, child: summary),
                    const SizedBox(width: 12),
                    Expanded(flex: 6, child: chart),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),
            Text(
              'Recent cleans',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            SurfaceCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Column(
                children: [
                  for (var index = 0; index < _history.length; index++) ...[
                    _HistoryRow(run: _history[index], metric: _metric),
                    if (index != _history.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.details});
  final _MetricDetails details;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(details.icon, color: fern),
        const SizedBox(height: 20),
        Text(
          'LAST 7 DAYS',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 6),
        Text(details.total, style: Theme.of(context).textTheme.displayLarge),
        const SizedBox(height: 8),
        Text(details.comparison, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.details});
  final _MetricDetails details;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(details.chartTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 20),
        SizedBox(
          height: 150,
          child: CustomPaint(
            painter: _BarChartPainter(details.values),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final day in _CleaningHistoryPageState._days)
              Text(day, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    ),
  );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.run, required this.metric});
  final _CleaningRun run;
  final HistoryMetric metric;

  String get value => switch (metric) {
    HistoryMetric.travelled => run.distance,
    HistoryMetric.cleaned => run.area,
    HistoryMetric.runTime => run.duration,
    HistoryMetric.overview => run.duration,
  };

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      children: [
        const Icon(Icons.cleaning_services_outlined, size: 20),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                run.when,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(run.rooms, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _BarChartPainter extends CustomPainter {
  const _BarChartPainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = values.reduce(math.max);
    final slot = size.width / values.length;
    final barWidth = math.min(24.0, slot * .48);
    final background = Paint()..color = mint;
    final foreground = Paint()..color = ink;
    for (var index = 0; index < values.length; index++) {
      final height = math.max(8.0, size.height * values[index] / maxValue);
      final left = slot * index + (slot - barWidth) / 2;
      final backgroundRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, barWidth, size.height),
        const Radius.circular(8),
      );
      final foregroundRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, size.height - height, barWidth, height),
        const Radius.circular(8),
      );
      canvas.drawRRect(backgroundRect, background);
      canvas.drawRRect(foregroundRect, foreground);
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.values != values;
}

_MetricDetails _detailsFor(HistoryMetric metric) => switch (metric) {
  HistoryMetric.overview => const _MetricDetails(
    Icons.auto_awesome_outlined,
    '6 cleans',
    '2 more cleans than last week',
    'Cleaning activity',
    [1, 0, 1, 1, 1, 0, 2],
  ),
  HistoryMetric.travelled => const _MetricDetails(
    Icons.route_rounded,
    '5.76 km',
    '12% further than last week',
    'Distance by day',
    [.8, 0, 1.1, 1.31, .72, .59, 1.24],
  ),
  HistoryMetric.cleaned => const _MetricDetails(
    Icons.square_foot_rounded,
    '314 m²',
    '18 m² more than last week',
    'Area cleaned by day',
    [42, 0, 56, 71, 39, 38, 68],
  ),
  HistoryMetric.runTime => const _MetricDetails(
    Icons.timer_outlined,
    '3h 28m',
    '14 minutes less than last week',
    'Run time by day',
    [29, 0, 38, 45, 27, 27, 42],
  ),
};

class _MetricDetails {
  const _MetricDetails(
    this.icon,
    this.total,
    this.comparison,
    this.chartTitle,
    this.values,
  );
  final IconData icon;
  final String total;
  final String comparison;
  final String chartTitle;
  final List<double> values;
}

class _CleaningRun {
  const _CleaningRun(
    this.when,
    this.rooms,
    this.distance,
    this.area,
    this.duration,
  );
  final String when;
  final String rooms;
  final String distance;
  final String area;
  final String duration;
}
