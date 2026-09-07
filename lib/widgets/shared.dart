import 'package:flutter/material.dart';

import '../theme.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        28,
        24,
        MediaQuery.paddingOf(context).bottom + 28,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: child,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (trailing != null && constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [copy, const SizedBox(height: 14), trailing!],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: copy),
            ?trailing,
          ],
        );
      },
    );
  }
}

class EmptyStatePanel extends StatelessWidget {
  const EmptyStatePanel({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.actionIcon = Icons.arrow_forward_rounded,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 2),
          Icon(icon, size: 58, color: fern),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (message != null) ...[
            const SizedBox(height: 7),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAction,
              icon: Icon(actionIcon),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );

    return SurfaceCard(
      child: Center(
        child: onAction == null
            ? content
            : Semantics(
                button: true,
                label: actionLabel ?? title,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: onAction,
                  child: content,
                ),
              ),
      ),
    );
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.color,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ink.withValues(alpha: .06)),
      ),
      child: child,
    );
  }
}

String prettyState(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1).replaceAll('_', ' ')}';
}

IconData optionIcon(String value, {String? field}) {
  final text = '${field ?? ''} $value'
      .toLowerCase()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .trim();

  if (text.contains('vacuum & mop') ||
      text.contains('vacuum and mop') ||
      text.contains('sweep and mop')) {
    return Icons.cleaning_services_rounded;
  }
  if (text.contains('mop after') || text.contains('after vacuum')) {
    return Icons.format_list_numbered_rounded;
  }
  if (text.contains('mop') || text.contains('mopping')) {
    return Icons.water_drop_rounded;
  }
  if (text.contains('vacuum') || text.contains('sweep')) {
    return Icons.cyclone_rounded;
  }
  if (text.contains('quiet') || text.contains('silent')) {
    return Icons.volume_off_rounded;
  }
  if (text.contains('balanced') ||
      text.contains('standard') ||
      text.contains('normal')) {
    return Icons.balance_rounded;
  }
  if (text.contains('turbo') ||
      text.contains('max') ||
      text.contains('strong')) {
    return Icons.bolt_rounded;
  }
  if (text.contains('suction') || text.contains('power')) {
    return Icons.air_rounded;
  }
  if (text.contains('cleangenius') ||
      text.contains('clean genius') ||
      text.contains('smart') ||
      text.contains('intelligent')) {
    return Icons.auto_awesome_rounded;
  }
  if (text.contains('custom') || text.endsWith(' off')) {
    return Icons.tune_rounded;
  }
  if (text.contains('deep') || text.contains('intensive')) {
    return Icons.auto_fix_high_rounded;
  }
  if (text.contains('quick') || text.contains('fast')) {
    return Icons.speed_rounded;
  }
  if (text.contains('route')) return Icons.route_rounded;
  if (text.contains('cycle')) return Icons.repeat_rounded;
  if (text.contains('room')) return Icons.meeting_room_rounded;
  if (text.contains('on') || text.contains('enable')) {
    return Icons.check_circle_rounded;
  }
  if (text.contains('off') || text.contains('disable')) {
    return Icons.cancel_rounded;
  }
  return Icons.auto_awesome_rounded;
}

class OptionLabel extends StatelessWidget {
  const OptionLabel({
    super.key,
    required this.value,
    this.label,
    this.field,
    this.icon,
  });

  final String value;
  final String? label;
  final String? field;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon ?? optionIcon(value, field: field), size: 20),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          label ?? value,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
