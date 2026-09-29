import 'dart:math';

import 'package:dartnative/dartnative.dart';

/// The way back to the hero from the Dice and Showcase screens: a small
/// chevron disc at the top-left, inside the safe area. Returns a
/// [Positioned] for the screen's root `Stack`.
Widget backChevron(BuildContext context, VoidCallback onPressed) {
  final size = MediaQuery.of(context).size;
  final padding = MediaQuery.of(context).padding;
  final landscape = size.width >= size.height;
  // DartNative quirk (A142, landscape): the side display-cutout inset
  // arrives in `padding.top`, not `padding.left` — take the larger, as
  // the hero's wordmark does.
  final double left =
      16 + (landscape ? max(padding.left, padding.top) : padding.left);
  return Positioned(
    left: left,
    top: padding.top + 8,
    child: Button(
      onPressed: onPressed,
      shape: const CircleBorder(),
      color: const Color(0x66101014),
      foregroundColor: const Color(0xEEFFFFFF),
      padding: const EdgeInsets.all(12),
      child: const Icon(CupertinoIcons.chevron_left, size: 18),
    ),
  );
}
