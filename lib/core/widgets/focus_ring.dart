import 'package:flutter/painting.dart';

/// A solid 2px [ring] set 2px off the control, the gap filled with [gap] (the ground under it). Shadows, not a border, so focus never resizes the
/// control; later shadows paint on top, so the gap goes last.
List<BoxShadow> focusRingShadows({required Color gap, required Color ring}) => [BoxShadow(color: ring, spreadRadius: 4.0), BoxShadow(color: gap, spreadRadius: 2.0)];
