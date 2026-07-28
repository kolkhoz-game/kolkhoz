import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:kolkhoz_app/src/app/views/shared/chrome_button.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_assets.dart';

const fieldPlanLightPaperTexture =
    'assets/art/field_plan/shared/textures/paper-light.png';
const _fieldPlanNineSlice = ChromeNineSliceConfig(
  left: 32,
  top: 32,
  right: 32,
  bottom: 32,
  tileSampleSize: 64,
);

enum PrintedUnderlayTone { neutral, primary, disabled }

class PrintedUnderlay extends StatelessWidget {
  const PrintedUnderlay({
    required this.child,
    this.tone = PrintedUnderlayTone.neutral,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.focused = false,
    this.tokens,
    super.key,
  });

  final Widget child;
  final PrintedUnderlayTone tone;
  final EdgeInsetsGeometry padding;
  final bool focused;
  final DesignTokens? tokens;

  @override
  Widget build(BuildContext context) {
    final primary = tone == PrintedUnderlayTone.primary;
    final dark = tokens != null && !tokens!.usesLightAppearance;
    Widget underlay = dark && !primary
        ? _DarkPrintedUnderlayBackground(tokens: tokens!)
        : _PrintedUnderlayBackground(
            asset: primary
                ? fieldPlanNavigationActiveFramePath
                : fieldPlanNavigationInactiveFramePath,
          );
    if (tone == PrintedUnderlayTone.disabled) {
      underlay = Opacity(opacity: 0.46, child: underlay);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        underlay,
        if (focused)
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.fromBorderSide(
                  BorderSide(
                    color: tokens?.colors.red ?? const Color(0xffa33a28),
                    width: 3,
                  ),
                ),
              ),
            ),
          ),
        Padding(padding: padding, child: child),
      ],
    );
  }
}

class _DarkPrintedUnderlayBackground extends StatelessWidget {
  const _DarkPrintedUnderlayBackground({required this.tokens});

  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: tokens.colors.iron),
        Opacity(
          opacity: 0.08,
          child: Image.asset(
            fieldPlanLightPaperTexture,
            alignment: Alignment.topLeft,
            fit: BoxFit.none,
            repeat: ImageRepeat.repeat,
            filterQuality: FilterQuality.low,
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: tokens.colors.gold.withValues(alpha: 0.72),
              width: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrintedUnderlayBackground extends StatelessWidget {
  const _PrintedUnderlayBackground({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.Image>(
      future: ChromeImageCache.load(context, asset),
      builder: (context, snapshot) {
        final image = snapshot.data;
        if (image == null) {
          return const SizedBox.expand();
        }
        return CustomPaint(
          painter: ChromeNineSlicePainter(
            image: image,
            config: _fieldPlanNineSlice,
            maxScale: 1,
          ),
        );
      },
    );
  }
}

class PrintedPaperSurface extends StatelessWidget {
  const PrintedPaperSurface({
    required this.child,
    this.tokens,
    this.color,
    this.textureOpacity,
    super.key,
  });

  final Widget child;
  final DesignTokens? tokens;
  final Color? color;
  final double? textureOpacity;

  @override
  Widget build(BuildContext context) {
    final dark = tokens != null && !tokens!.usesLightAppearance;
    final resolvedColor =
        color ?? tokens?.colors.panel ?? const Color(0xffe7d4a5);
    final resolvedTextureOpacity = textureOpacity ?? (dark ? 0.1 : 0.32);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: resolvedColor),
        IgnorePointer(
          child: Opacity(
            opacity: resolvedTextureOpacity,
            child: Image.asset(
              fieldPlanLightPaperTexture,
              alignment: Alignment.topLeft,
              fit: BoxFit.none,
              repeat: ImageRepeat.repeat,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => const SizedBox.expand(),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class PrintedSelectionStamp extends StatelessWidget {
  const PrintedSelectionStamp({
    this.size = 30,
    this.color = const Color(0xffa33a28),
    super.key,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SelectionStampPainter(color)),
    );
  }
}

class _SelectionStampPainter extends CustomPainter {
  const _SelectionStampPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.09
      ..strokeCap = StrokeCap.square;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.shortestSide * 0.43,
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.24, size.height * 0.52)
        ..lineTo(size.width * 0.43, size.height * 0.7)
        ..lineTo(size.width * 0.77, size.height * 0.3),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SelectionStampPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}
