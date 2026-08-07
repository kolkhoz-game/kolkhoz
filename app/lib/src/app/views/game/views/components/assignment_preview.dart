import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';

@immutable
class AssignmentPreviewRoute {
  const AssignmentPreviewRoute({
    required this.cardID,
    required this.suit,
    required this.source,
    required this.target,
  });

  final String cardID;
  final String suit;
  final Rect source;
  final Rect target;

  @override
  bool operator ==(Object other) =>
      other is AssignmentPreviewRoute &&
      cardID == other.cardID &&
      suit == other.suit &&
      source == other.source &&
      target == other.target;

  @override
  int get hashCode => Object.hash(cardID, suit, source, target);
}

class AssignmentPreviewOverlay extends StatelessWidget {
  const AssignmentPreviewOverlay({
    required this.routes,
    required this.tokens,
    super.key,
  });

  final List<AssignmentPreviewRoute> routes;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: const ValueKey('assignment-preview-arrows'),
      painter: AssignmentPreviewPainter(
        routes: routes,
        arrowColor: tokens.colors.gold,
        outlineColor: tokens.colors.black.withValues(alpha: 0.72),
      ),
    );
  }
}

class AssignmentPreviewPainter extends CustomPainter {
  const AssignmentPreviewPainter({
    required this.routes,
    required this.arrowColor,
    required this.outlineColor,
  });

  final List<AssignmentPreviewRoute> routes;
  final Color arrowColor;
  final Color outlineColor;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (index, route) in routes.indexed) {
      _paintRoute(canvas, route, index);
    }
  }

  void _paintRoute(Canvas canvas, AssignmentPreviewRoute route, int index) {
    final sourceCenter = route.source.center;
    final targetCenter = route.target.center;
    final start = rectEdgePoint(route.source, targetCenter);
    final end = rectEdgePoint(route.target, sourceCenter);
    final delta = end - start;
    final distance = delta.distance;
    if (distance < 8) {
      return;
    }

    final normal = Offset(-delta.dy / distance, delta.dx / distance);
    final bendDirection = index.isEven ? 1.0 : -1.0;
    final bend = math.min(34.0, distance * 0.14) * bendDirection;
    final control = Offset.lerp(start, end, 0.5)! + normal * bend;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

    canvas.drawPath(
      path,
      Paint()
        ..color = outlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = arrowColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    final tangent = end - control;
    final angle = math.atan2(tangent.dy, tangent.dx);
    const headLength = 13.0;
    const headSpread = 0.58;
    final arrowHead = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - headLength * math.cos(angle - headSpread),
        end.dy - headLength * math.sin(angle - headSpread),
      )
      ..lineTo(
        end.dx - headLength * math.cos(angle + headSpread),
        end.dy - headLength * math.sin(angle + headSpread),
      )
      ..close();
    canvas.drawPath(
      arrowHead,
      Paint()
        ..color = outlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      arrowHead,
      Paint()
        ..color = arrowColor
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(start, 5, Paint()..color = outlineColor);
    canvas.drawCircle(start, 2.75, Paint()..color = arrowColor);
  }

  @override
  bool shouldRepaint(AssignmentPreviewPainter oldDelegate) =>
      oldDelegate.routes != routes ||
      oldDelegate.arrowColor != arrowColor ||
      oldDelegate.outlineColor != outlineColor;
}

Offset rectEdgePoint(Rect rect, Offset toward) {
  final center = rect.center;
  final delta = toward - center;
  if (delta == Offset.zero) {
    return center;
  }
  final xScale = delta.dx == 0
      ? double.infinity
      : rect.width / 2 / delta.dx.abs();
  final yScale = delta.dy == 0
      ? double.infinity
      : rect.height / 2 / delta.dy.abs();
  return center + delta * math.min(xScale, yScale);
}
