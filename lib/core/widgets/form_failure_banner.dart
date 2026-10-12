import 'package:flutter/material.dart';
import 'package:ghpockit/core/theme/theme_context.dart';

/// A save that was refused, above the submit button. Announced as it appears, since focus stays on the button.
class GPFormFailureBanner extends StatelessWidget {
  const GPFormFailureBanner({required this.message, super.key});

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
            children: <Widget>[
              Icon(Icons.error_outline, size: 20, color: colors.onDanger),
              SizedBox(width: spacing.smd),
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
