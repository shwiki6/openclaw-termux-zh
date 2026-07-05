import 'package:flutter/material.dart';

class ResponsiveLayout {
  const ResponsiveLayout._();

  static const double compactWidth = 360;
  static const double compactHeight = 620;
  static const double wideWidth = 720;
  static const double maxContentWidth = 980;
  static const double maxTextScale = 1.25;

  static bool isCompact(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width < compactWidth || size.height < compactHeight;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= wideWidth) {
      return const EdgeInsets.all(24);
    }
    if (width <= compactWidth) {
      return const EdgeInsets.fromLTRB(14, 12, 14, 12);
    }
    return const EdgeInsets.all(16);
  }

  static Widget constrainContent({
    required Widget child,
    double maxWidth = maxContentWidth,
  }) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }

  static Widget scrollableCenter({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(24),
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }

  static MediaQueryData clampedMediaQuery(MediaQueryData data) {
    final scale = data.textScaler
        .scale(1)
        .clamp(1.0, maxTextScale)
        .toDouble();
    return data.copyWith(textScaler: TextScaler.linear(scale));
  }
}
