import 'dart:ui' show Color;

/// Primitives: nothing outside `core/theme/` reads them; widgets ask `context.colors` for a role (ADR-0005).
abstract final class GPColorTokens {
  static const Color white = Color(0xFFFFFFFF);
  static const Color ivory50 = Color(0xFFFAF9F5);
  static const Color ivory100 = Color(0xFFF5F4EF);
  static const Color ivory200 = Color(0xFFF0EEE6);
  static const Color warmGrey200 = Color(0xFFE8E6DC);
  static const Color warmGrey300 = Color(0xFFDEDCD1);
  static const Color warmGrey400 = Color(0xFFB8B5AC);
  static const Color warmGrey500 = Color(0xFF828179);
  static const Color warmGrey600 = Color(0xFF6B6862);
  static const Color warmGrey700 = Color(0xFF43423E);
  static const Color warmGrey750 = Color(0xFF3A3937);
  static const Color warmGrey800 = Color(0xFF30302E);
  static const Color warmGrey900 = Color(0xFF262624);
  static const Color warmGrey950 = Color(0xFF1F1E1D);
  static const Color ink = Color(0xFF141413);
  static const Color paper = Color(0xFFF5F4EF);

  static const Color clay100 = Color(0xFFF6E5DC);
  static const Color clay400 = Color(0xFFE0906F);

  /// The accent, not the action color: white on it is 3.1:1, below AA (ADR-0005).
  static const Color clay500 = Color(0xFFD97757);

  static const Color clay600 = Color(0xFFC15F3C);

  /// The accent as text or an icon: [clay500] is 2.96:1 on [ivory50], short of even the 3:1 non-text UI needs.
  static const Color clay700 = Color(0xFFA84F2E);

  static const Color clay800 = Color(0xFF7A3A22);
  static const Color clay900 = Color(0xFF4A2D22);

  static const Color green400 = Color(0xFF5FA681);

  /// Darker than it looks like it should be, so light text clears 4.5:1 on it.
  static const Color green600 = Color(0xFF2F6E4E);

  static const Color green700 = Color(0xFF23593E);
  static const Color amber400 = Color(0xFFD9A445);

  /// Takes dark content: no amber that still reads as amber clears 4.5:1 against white.
  static const Color amber500 = Color(0xFFB8821F);

  static const Color amber700 = Color(0xFF7A5512);

  /// Lighter than it looks like it needs to be: an expense amount is body-sized text and owes 4.5:1 on [warmGrey900].
  static const Color red400 = Color(0xFFE27A70);

  /// Redder than the terracotta on purpose, so a destructive action cannot pass for an accent one.
  static const Color red500 = Color(0xFFA8332A);

  static const Color red700 = Color(0xFF6E211B);

  static const Color transparent = Color(0x00000000);
  static const Color shadowWarm = Color(0xFF3D3A32);
}
