import 'package:flutter/material.dart';

import '../../../../core/theme/theme_context.dart';

/// A card that stands in for one Home section, empty or failed, while the others keep showing: smaller than `GPEmptyState`, which owns a screen.
final class HomeSectionMessageWidget extends StatelessWidget {
  const HomeSectionMessageWidget({super.key, required this.icon, required this.message, required this.title});

  final IconData icon;
  final String message;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface, borderRadius: context.radii.borderLg, boxShadow: context.shadows.small),
      child: Padding(
        padding: EdgeInsets.all(spacing.md + spacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: spacing.smd,
          children: [
            SizedBox.square(
              dimension: 40.0,
              child: DecoratedBox(
                decoration: BoxDecoration(color: colors.surfaceVariant, shape: BoxShape.circle),
                child: Icon(icon, size: 20.0, color: colors.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: spacing.xs,
                children: [
                  Text(
                    title,
                    style: context.text.titleMedium.copyWith(fontWeight: FontWeight.w600, color: colors.onSurface),
                  ),
                  Text(message, style: context.text.bodyMedium.copyWith(color: colors.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
