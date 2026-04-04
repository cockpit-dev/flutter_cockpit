import 'package:flutter/material.dart';

import '../theme/orbit_todo_theme.dart';

final class CollectionOverviewCard extends StatelessWidget {
  const CollectionOverviewCard({
    required this.eyebrow,
    required this.headline,
    required this.message,
    required this.metrics,
    required this.trailing,
    this.statusBanner,
    this.dense = false,
    super.key,
  });

  final String eyebrow;
  final String headline;
  final String message;
  final List<CollectionMetricData> metrics;
  final Widget trailing;
  final String? statusBanner;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 620;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.editorialSurfaceColor,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withAlphaFraction(0.92),
          ),
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withAlphaFraction(0.92),
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(0, dense ? 18 : 26, 0, dense ? 18 : 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (compact)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _OverviewCopy(
                    eyebrow: eyebrow,
                    headline: headline,
                    message: message,
                    statusBanner: statusBanner,
                  ),
                  const SizedBox(height: 18),
                  trailing,
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    flex: 5,
                    child: _OverviewCopy(
                      eyebrow: eyebrow,
                      headline: headline,
                      message: message,
                      statusBanner: statusBanner,
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(child: trailing),
                ],
              ),
            const SizedBox(height: 24),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withAlphaFraction(0.82),
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: metrics
                      .map(
                        (metric) => SizedBox(
                          width: compact ? double.infinity : 196,
                          child: _CollectionMetric(metric: metric),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class CollectionMetricData {
  const CollectionMetricData({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
}

final class _OverviewCopy extends StatelessWidget {
  const _OverviewCopy({
    required this.eyebrow,
    required this.headline,
    required this.message,
    required this.statusBanner,
  });

  final String eyebrow;
  final String headline;
  final String message;
  final String? statusBanner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(
                eyebrow.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.35,
                ),
              ),
            ),
            _InlineStatus(label: statusBanner ?? 'Ready'),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          headline,
          style: theme.textTheme.displayMedium?.copyWith(
            height: 0.86,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}

final class _InlineStatus extends StatelessWidget {
  const _InlineStatus({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(width: 10, height: 1, color: colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
      ],
    );
  }
}

final class _CollectionMetric extends StatelessWidget {
  const _CollectionMetric({required this.metric});

  final CollectionMetricData metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: colorScheme.outlineVariant.withAlphaFraction(0.82),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              metric.label.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              metric.value,
              style: theme.textTheme.displaySmall?.copyWith(
                fontFamily: 'SpaceGrotesk',
                fontWeight: FontWeight.w700,
                height: 0.9,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              metric.caption,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class OverviewBadge extends StatelessWidget {
  const OverviewBadge({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: colorScheme.primary.withAlphaFraction(0.4),
            width: 2,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 2, 0, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'MODE',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
