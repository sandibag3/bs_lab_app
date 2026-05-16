import 'dart:math' as math;

import 'package:flutter/material.dart';

class ResponsivePageContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double breakpoint;

  const ResponsivePageContainer({
    super.key,
    required this.child,
    this.maxWidth = 1180,
    this.breakpoint = 700,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= breakpoint) {
          return child;
        }

        final sideMargin = constraints.maxWidth > 1000 ? 32.0 : 24.0;
        final availableWidth = math.max(
          0.0,
          constraints.maxWidth - (sideMargin * 2),
        );
        final contentWidth = math.min(maxWidth, availableWidth);

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: contentWidth,
            height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
            child: child,
          ),
        );
      },
    );
  }
}
