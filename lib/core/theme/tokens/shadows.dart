import 'package:flutter/painting.dart';
import 'colors.dart';

/// Primitives; widgets read `context.shadows`. Each color is [GPColorTokens.shadowWarm] at low alpha: black on the ivory ground reads as dirt.
abstract final class GPShadowTokens {
  static const List<BoxShadow> small = <BoxShadow>[
    BoxShadow(color: Color(0x0A3D3A32), blurRadius: 2.0, offset: Offset(0.0, 1.0)),
  ];

  static const List<BoxShadow> medium = <BoxShadow>[
    BoxShadow(color: Color(0x0F3D3A32), blurRadius: 8.0, offset: Offset(0.0, 2.0)),
    BoxShadow(color: Color(0x0A3D3A32), blurRadius: 2.0, offset: Offset(0.0, 1.0)),
  ];

  static const List<BoxShadow> large = <BoxShadow>[
    BoxShadow(color: Color(0x143D3A32), blurRadius: 20.0, offset: Offset(0.0, 8.0)),
    BoxShadow(color: Color(0x0A3D3A32), blurRadius: 6.0, offset: Offset(0.0, 2.0)),
  ];

  static const List<BoxShadow> extraLarge = <BoxShadow>[
    BoxShadow(color: Color(0x1F3D3A32), blurRadius: 32.0, offset: Offset(0.0, 12.0)),
    BoxShadow(color: Color(0x0F3D3A32), blurRadius: 8.0, offset: Offset(0.0, 4.0)),
  ];

  static const List<BoxShadow> none = <BoxShadow>[];
}
