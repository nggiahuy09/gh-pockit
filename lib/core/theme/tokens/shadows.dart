import 'package:flutter/painting.dart';
import 'package:ghpockit/core/theme/tokens/colors.dart';

/// Raw elevation values.
///
/// Primitives; widgets read `context.shadows` instead (see `GPShadows`).
///
/// Every shadow here is built from [GPColorTokens.shadowWarm] at a low opacity rather than from black. On the ivory ground a neutral black shadow
/// goes grey and the card looks soiled; a warm one reads as the paper lifting. This is the single largest visual difference between this theme and
/// a stock Material one, and it costs nothing.
///
/// The ramp is short on purpose — Claude's surfaces are separated by border and background, with elevation used sparingly. A widget reaching for a
/// fifth shadow step is usually a widget that should have used a border.
///
/// Focus rings deliberately do **not** live here. A ring is not elevation: it has to be legible against the ground it is drawn over (WCAG 1.4.11
/// wants 3:1), which means its color has to come from the active palette rather than from a fixed hex. A widget builds one from `context.colors`.
abstract final class GPShadowTokens {
  /// Barely there. A list item that needs to lift off the ground without becoming a card.
  static const List<BoxShadow> small = <BoxShadow>[
    BoxShadow(color: Color(0x0A3D3A32), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// The default card.
  static const List<BoxShadow> medium = <BoxShadow>[
    BoxShadow(color: Color(0x0F3D3A32), blurRadius: 8, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x0A3D3A32), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// Menus, popovers, the FAB.
  static const List<BoxShadow> large = <BoxShadow>[
    BoxShadow(color: Color(0x143D3A32), blurRadius: 20, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0A3D3A32), blurRadius: 6, offset: Offset(0, 2)),
  ];

  /// Bottom sheets and dialogs.
  static const List<BoxShadow> extraLarge = <BoxShadow>[
    BoxShadow(color: Color(0x1F3D3A32), blurRadius: 32, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x0F3D3A32), blurRadius: 8, offset: Offset(0, 4)),
  ];

  /// No shadow. A named value so a `switch` can return it without building an empty list literal at every call site.
  static const List<BoxShadow> none = <BoxShadow>[];
}
