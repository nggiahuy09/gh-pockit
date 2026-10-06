import 'package:flutter/painting.dart';
import 'package:ghpockit/core/theme/tokens/colors.dart';

/// Primitives; widgets read `context.shadows`. Each color is [GPColorTokens.shadowWarm] at low alpha: black on the ivory ground reads as dirt.
abstract final class GPShadowTokens {
  static const List<BoxShadow> small = <BoxShadow>[
    BoxShadow(color: Color(0x0A3D3A32), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> medium = <BoxShadow>[
    BoxShadow(color: Color(0x0F3D3A32), blurRadius: 8, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x0A3D3A32), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> large = <BoxShadow>[
    BoxShadow(color: Color(0x143D3A32), blurRadius: 20, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0A3D3A32), blurRadius: 6, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> extraLarge = <BoxShadow>[
    BoxShadow(color: Color(0x1F3D3A32), blurRadius: 32, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x0F3D3A32), blurRadius: 8, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> none = <BoxShadow>[];
}
