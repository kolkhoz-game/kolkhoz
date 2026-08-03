import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:kolkhoz_app/src/app/settings/animation_speed.dart';
import 'package:kolkhoz_app/src/app/settings/game_motion.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:simple_animations/simple_animations.dart';
import 'board_widgets.dart'
    show GameCard, cardViewCornerRadius, cardViewStrokeWidth;
import 'card_motion_plan.dart';

/// Renders one immutable flight instruction.
class FlyingCard extends StatelessWidget {
  const FlyingCard({
    required this.flight,
    required this.tokens,
    required this.duration,
    required this.onDone,
    this.trump,
    this.visible = true,
    this.winningTrick = false,
    super.key,
  });

  final CardFlight flight;
  final DesignTokens tokens;
  final Duration duration;
  final VoidCallback onDone;
  final String? trump;
  final bool visible;
  final bool winningTrick;

  @override
  Widget build(BuildContext context) {
    final motion = GameMotion.of(context);
    final flightDuration = scaledGameAnimationDuration(
      duration,
      flight.durationScale,
    );
    final flipDuration = flight.revealBeforeFlight
        ? motion.rewardFlip
        : Duration.zero;
    final totalDuration = flipDuration + flightDuration;
    final flipFraction = totalDuration == Duration.zero
        ? 0.0
        : flipDuration.inMicroseconds / totalDuration.inMicroseconds;
    return PlayAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: totalDuration,
      curve: Curves.linear,
      onCompleted: onDone,
      builder: (context, value, _) {
        final flipProgress = flipFraction == 0
            ? 1.0
            : (value / flipFraction).clamp(0.0, 1.0);
        final rawFlightProgress = flipFraction >= 1
            ? 1.0
            : ((value - flipFraction) / (1 - flipFraction)).clamp(0.0, 1.0);
        final flightProgress = GameMotion.cardFlightCurve.transform(
          rawFlightProgress,
        );
        final entersJobGauge = isJobGaugeInsertionFlight(flight);
        final rect = entersJobGauge
            ? jobGaugeFlightRectAt(flight, rawFlightProgress)
            : flight.rewardExchange
            ? managedRewardExchangeRectAt(
                flight.from,
                flight.to,
                flightProgress,
              )
            : cardFlightRectAt(flight.from, flight.to, flightProgress);
        final card = _flyingCardFace(
          faceDown:
              flight.faceDown ||
              (flight.revealBeforeFlight && flipProgress < 0.5),
        );
        final flipTransform = flight.revealBeforeFlight && flipProgress < 1
            ? (Matrix4.identity()
                ..setEntry(3, 2, 0.002)
                ..rotateY(
                  math.pi * GameMotion.rewardFlipCurve.transform(flipProgress),
                ))
            : null;
        Widget presentedCard = flipTransform == null
            ? card
            : Transform(
                alignment: Alignment.center,
                transform: flipTransform,
                child: flipProgress >= 0.5
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(math.pi),
                        child: card,
                      )
                    : card,
              );
        final insertionProgress = entersJobGauge
            ? jobGaugeInsertionProgress(rawFlightProgress)
            : 0.0;
        if (entersJobGauge) {
          presentedCard = ClipRect(
            key: ValueKey('job-gauge-insertion-card-${flight.card.id}'),
            clipper: _JobGaugeInsertionClipper(insertionProgress),
            child: Transform.rotate(
              angle: jobGaugeEntryAngle(flight, rawFlightProgress),
              alignment: Alignment.center,
              child: presentedCard,
            ),
          );
        }
        if (flight.rewardExchange) {
          final emphasis = math.sin(math.pi * rawFlightProgress);
          final direction =
              flight.destinationZone.kind == MotionZoneKind.rewardReveal
              ? 1.0
              : -1.0;
          presentedCard = Transform.rotate(
            angle: direction * 0.09 * emphasis,
            child: Transform.scale(
              scale: 1 + 0.12 * emphasis,
              child: presentedCard,
            ),
          );
        }
        final routeOpacity = entersJobGauge
            ? jobGaugeEntryOpacity(rawFlightProgress)
            : 1.0;
        return Positioned.fromRect(
          rect: rect,
          child: Opacity(
            opacity: visible ? routeOpacity : 0,
            child: presentedCard,
          ),
        );
      },
    );
  }

  Widget _flyingCardFace({required bool faceDown}) {
    final size = cardFlightRenderSize(flight.from, flight.to, tokens);
    final card = FittedBox(
      fit: BoxFit.fill,
      child: faceDown
          ? _FlyingCardBack(
              key: ValueKey('flying-card-back-${flight.card.id}'),
              tokens: tokens,
              size: size,
            )
          : GameCard(
              key: ValueKey('flying-card-face-${flight.card.id}'),
              card: flight.card,
              tokens: tokens,
              trump: trump,
              sizeOverride: size,
              motionTracked: false,
              winningTrick: winningTrick,
            ),
    );
    if (!flight.requisitioned) {
      return card;
    }
    return Container(
      key: ValueKey('requisition-card-frame-${flight.card.id}'),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardViewCornerRadius),
        border: Border.all(color: tokens.colors.redBright, width: 3),
      ),
      child: card,
    );
  }
}

bool isJobGaugeInsertionFlight(CardFlight flight) =>
    flight.destinationZone.kind == MotionZoneKind.job &&
    flight.audiencePanel == panelBrigade;

double jobGaugeInsertionProgress(double rawFlightProgress) {
  if (rawFlightProgress >= 1) {
    return 1;
  }
  final normalized = ((rawFlightProgress - 0.72) / 0.28).clamp(0.0, 1.0);
  return Curves.easeInOutCubic.transform(normalized);
}

double jobGaugeEntryAngle(CardFlight flight, double rawFlightProgress) {
  final horizontalDirection =
      (flight.to.center.dx - flight.from.center.dx).sign;
  final resolvedDirection = horizontalDirection == 0
      ? 1.0
      : horizontalDirection;
  final turnProgress = Curves.easeInOutCubic.transform(
    ((rawFlightProgress - 0.18) / 0.54).clamp(0.0, 1.0),
  );
  return -resolvedDirection * 0.16 * turnProgress;
}

double jobGaugeEntryOpacity(double rawFlightProgress) =>
    rawFlightProgress >= 1 ? 0 : 1;

Rect jobGaugeFlightRectAt(CardFlight flight, double rawFlightProgress) {
  const approachEnd = 0.72;
  const insertionScale = 0.82;
  final raw = rawFlightProgress.clamp(0.0, 1.0);
  final approachProgress = GameMotion.cardFlightCurve.transform(
    (raw / approachEnd).clamp(0.0, 1.0),
  );
  final insertionSize = Size(
    math.max(flight.to.width, flight.from.width * insertionScale),
    math.max(flight.to.height, flight.from.height * insertionScale),
  );
  final size = Size(
    lerpDouble(flight.from.width, insertionSize.width, approachProgress)!,
    lerpDouble(flight.from.height, insertionSize.height, approachProgress)!,
  );
  final slot = flight.to.center;
  if (raw >= approachEnd) {
    final insertion = jobGaugeInsertionProgress(raw);
    return Rect.fromCenter(
      center: slot.translate(0, insertionSize.height * (0.5 - insertion)),
      width: insertionSize.width,
      height: insertionSize.height,
    );
  }
  final approachCenter = slot.translate(0, insertionSize.height / 2);
  final linearCenter = Offset.lerp(
    flight.from.center,
    approachCenter,
    approachProgress,
  )!;
  final distance = (approachCenter - flight.from.center).distance;
  final arcHeight = math.min(64.0, distance * 0.11);
  final arcOffset = -4 * arcHeight * approachProgress * (1 - approachProgress);
  return Rect.fromCenter(
    center: linearCenter.translate(0, arcOffset),
    width: size.width,
    height: size.height,
  );
}

class _JobGaugeInsertionClipper extends CustomClipper<Rect> {
  const _JobGaugeInsertionClipper(this.progress);

  final double progress;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
    0,
    size.height * progress.clamp(0.0, 1.0),
    size.width,
    size.height,
  );

  @override
  bool shouldReclip(_JobGaugeInsertionClipper oldClipper) =>
      oldClipper.progress != progress;
}

Rect cardFlightRectAt(Rect from, Rect to, double progress) {
  final clamped = progress.clamp(0.0, 1.0);
  final width = lerpDouble(from.width, to.width, clamped)!;
  final height = lerpDouble(from.height, to.height, clamped)!;
  final linearCenter = Offset.lerp(from.center, to.center, clamped)!;
  final distance = (to.center - from.center).distance;
  final arcHeight = math.min(76.0, distance * 0.14);
  final arcOffset = -4 * arcHeight * clamped * (1 - clamped);
  return Rect.fromCenter(
    center: linearCenter.translate(0, arcOffset),
    width: width,
    height: height,
  );
}

Rect managedRewardExchangeRectAt(Rect from, Rect to, double progress) {
  final clamped = progress.clamp(0.0, 1.0);
  final width = lerpDouble(from.width, to.width, clamped)!;
  final height = lerpDouble(from.height, to.height, clamped)!;
  final linearCenter = Offset.lerp(from.center, to.center, clamped)!;
  final delta = to.center - from.center;
  final distance = delta.distance;
  if (distance == 0) {
    return Rect.fromCenter(center: linearCenter, width: width, height: height);
  }
  final normal = Offset(-delta.dy / distance, delta.dx / distance);
  final arcHeight = math.min(120.0, distance * 0.3);
  final arc = 4 * arcHeight * clamped * (1 - clamped);
  return Rect.fromCenter(
    center: linearCenter + normal * arc,
    width: width,
    height: height,
  );
}

class _FlyingCardBack extends StatelessWidget {
  const _FlyingCardBack({required this.tokens, required this.size, super.key});

  final DesignTokens tokens;
  final TokenCardSize size;

  @override
  Widget build(BuildContext context) {
    final cardBack = KolkhozCardBackScope.of(context);
    return Container(
      width: size.width,
      height: size.height,
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardViewCornerRadius),
        border: Border.all(
          color: tokens.colors.black.withValues(
            alpha: tokens.colors.cardStrokeOpacity,
          ),
          width: cardViewStrokeWidth,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cardViewCornerRadius),
        child: Image.asset(
          cardBack.displayedAssetPathFor(dark: !tokens.usesLightAppearance),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => ColoredBox(color: tokens.colors.iron),
        ),
      ),
    );
  }
}

TokenCardSize cardFlightRenderSize(Rect from, Rect to, DesignTokens tokens) {
  final height = math.max(from.height, to.height);
  if (height <= tokens.card.small.height + 8) {
    return tokens.card.small;
  }
  if (height <= tokens.card.medium.height + 8) {
    return tokens.card.medium;
  }
  return tokens.card.large;
}

Duration scaledDuration(Duration duration, double scale) =>
    scaledGameAnimationDuration(duration, scale);
