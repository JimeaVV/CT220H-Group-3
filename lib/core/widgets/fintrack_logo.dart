import 'package:flutter/material.dart';

class FinTrackLogo extends StatelessWidget {
  const FinTrackLogo({super.key, this.size = 64, this.showName = false});

  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? Colors.black : Colors.white;
    final background = isDark ? Colors.white : Colors.black;

    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'F',
            style: TextStyle(
              color: foreground,
              fontSize: size * 0.48,
              fontWeight: FontWeight.w900,
              letterSpacing: -2,
            ),
          ),
          Positioned(
            right: size * 0.14,
            top: size * 0.14,
            child: Icon(Icons.trending_up_rounded, color: foreground, size: size * 0.28),
          ),
        ],
      ),
    );

    if (!showName) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 12),
        Text(
          'FinTrack',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
        ),
      ],
    );
  }
}
