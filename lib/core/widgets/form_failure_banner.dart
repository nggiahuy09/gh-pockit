import 'package:flutter/material.dart';

import '../theme/theme_context.dart';

/// A save that was refused, above the submit button. Announced as it appears, since focus stays on the button.
final class GPFormFailureBanner extends StatelessWidget {
  const GPFormFailureBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.danger, borderRadius: context.radii.borderMd),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.smd),
          child: Row(
            spacing: spacing.smd,
            children: [
              Icon(Icons.error_outline, size: 20.0, color: colors.onDanger),
              Expanded(
                child: Text(message, style: context.text.bodyMedium.copyWith(color: colors.onDanger)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
