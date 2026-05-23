import 'package:flutter/material.dart';

import '../theme/orbit_todo_theme.dart';

final class EditorialSection extends StatelessWidget {
  const EditorialSection({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.symmetric(vertical: 22),
    this.backgroundColor,
    this.leadingAccentColor,
    this.borderColor,
    this.showTopBorder = true,
    this.showBottomBorder = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? leadingAccentColor;
  final Color? borderColor;
  final bool showTopBorder;
  final bool showBottomBorder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dividerColor =
        borderColor ?? colorScheme.outlineVariant.withAlphaFraction(0.86);
    final content = Padding(padding: padding, child: child);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: showTopBorder
              ? BorderSide(color: dividerColor)
              : BorderSide.none,
          bottom: showBottomBorder
              ? BorderSide(color: dividerColor)
              : BorderSide.none,
        ),
      ),
      child: leadingAccentColor == null
          ? content
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(color: leadingAccentColor),
                    child: const SizedBox(width: 3),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: content),
                ],
              ),
            ),
    );
  }
}
