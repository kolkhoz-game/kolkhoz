import 'dart:math' as math;
import 'dart:ui' show clampDouble;

import 'package:flutter/material.dart';

import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_assets.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/shared/display_text.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/display/plot_display.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/display/table_display.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/board_widgets.dart';

class PlotPanel extends StatelessWidget {
  const PlotPanel({
    required this.model,
    required this.tokens,
    this.onPlotCardTap,
    this.onSwapCardDrop,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final void Function(String cardID, String zone)? onPlotCardTap;
  final SwapCardDropCallback? onSwapCardDrop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = PlotPanelMetrics.fromSize(constraints.biggest, tokens);
        return CommandPanelSurface(
          tokens: tokens,
          padding: EdgeInsets.all(metrics.padding),
          child: PlotOverviewView(
            model: model,
            metrics: metrics,
            tokens: tokens,
            onPlotCardTap: onPlotCardTap,
            onSwapCardDrop: onSwapCardDrop,
          ),
        );
      },
    );
  }
}

class PlotOverviewView extends StatelessWidget {
  const PlotOverviewView({
    required this.model,
    required this.metrics,
    required this.tokens,
    this.onPlotCardTap,
    this.onSwapCardDrop,
    super.key,
  });

  final TableViewModel model;
  final PlotPanelMetrics metrics;
  final DesignTokens tokens;
  final void Function(String cardID, String zone)? onPlotCardTap;
  final SwapCardDropCallback? onSwapCardDrop;

  @override
  Widget build(BuildContext context) {
    final hiddenExiledCardIDs = hiddenExiledPlotCardIDs(model);
    final exiledCardIDs = requisitionExiledCardIDs(model);
    final viewer = localSeat(model);
    final provisionalRequisitionCardID = model.table.phase == phaseRequisition
        ? model.selection.plotCardID
        : null;
    final otherSeats = model.table.seats
        .where((seat) => seat.id != viewer.id)
        .toList(growable: false);
    final viewerHiddenCards = visiblePlotCards(
      viewer.plot.hidden,
      hiddenExiledCardIDs,
    ).where((card) => card.id != provisionalRequisitionCardID).toList();
    final viewerRevealedCards = visiblePlotCards(
      viewer.plot.revealed,
      hiddenExiledCardIDs,
    ).where((card) => card.id != provisionalRequisitionCardID).toList();
    final viewerStacks = visiblePlotStacks(
      viewer.plot.stacks,
      hiddenExiledCardIDs,
    );
    final selectable =
        model.table.phase == phaseSwap ||
        model.legalActions.any(
          (action) => action.kind == actionSelectRequisitionCard,
        );
    const revealViewerCellar = true;
    final revealOpponentCellars = model.table.phase == phaseGameOver;
    return LayoutBuilder(
      builder: (context, constraints) {
        final opponentCount = otherSeats.length;
        final plotRowsHeight = math.max(
          0.0,
          constraints.maxHeight - (otherSeats.isEmpty ? 0 : metrics.spacing),
        );
        final opponentHeight = opponentCount == 0
            ? 0.0
            : plotRowsHeight * tokens.layout.plot.opponentHeightFraction;
        final localHeight = math.max(0.0, plotRowsHeight - opponentHeight);
        final opponentPanelWidth = opponentCount == 0
            ? 0.0
            : math.max(
                0.0,
                (constraints.maxWidth - metrics.spacing * (opponentCount - 1)) /
                    opponentCount,
              );
        final opponentCardFrameHeight = math.min(
          opponentHeight * plotOpponentCardHeightFraction,
          opponentPanelWidth *
              plotOpponentCardWidthFraction *
              tokens.card.aspectRatio,
        );
        final opponentMetrics = metrics.copyWith(
          opponentHeight: opponentHeight,
          opponentCardScale: opponentCardFrameHeight / tokens.card.small.height,
          opponentCardFrameWidth:
              opponentCardFrameHeight / tokens.card.aspectRatio,
          opponentCardFrameHeight: opponentCardFrameHeight,
          portraitSize: math.min(
            opponentHeight * plotOpponentPortraitHeightFraction,
            opponentPanelWidth * plotOpponentPortraitWidthFraction,
          ),
        );

        return Column(
          spacing: metrics.spacing,
          children: [
            if (otherSeats.isNotEmpty)
              SizedBox(
                height: opponentHeight,
                child: Row(
                  spacing: metrics.spacing,
                  children: [
                    for (final seat in otherSeats)
                      Expanded(
                        child: OpponentPlotPanel(
                          seat: seat,
                          metrics: opponentMetrics,
                          tokens: tokens,
                          exiledCardIDs: exiledCardIDs,
                          hiddenExiledCardIDs: hiddenExiledCardIDs,
                          revealCellarCards: revealOpponentCellars,
                        ),
                      ),
                  ],
                ),
              ),
            MotionTrackedRegion(
              motionKey: plotCardMotionSourceKey(viewer.id),
              child: MotionImpactSurface(
                impactKey: 'plot-overview-${viewer.id}',
                style: MotionImpactStyle.stack,
                glowColor: tokens.colors.gold,
                matches: (impact) =>
                    impact.destination.isPlot &&
                    impact.destination.seatID == viewer.id,
                child: SizedBox(
                  height: localHeight,
                  child: Row(
                    spacing: metrics.spacing,
                    children: [
                      Expanded(
                        child: LocalPlotColumn(
                          title: 'Cellar',
                          iconPath: fieldPlanCellarIconPath,
                          cards: viewerHiddenCards,
                          value: viewerHiddenCards.length,
                          hidden: true,
                          revealHiddenCards: revealViewerCellar,
                          splitHiddenCardFront:
                              model.table.phase != phaseGameOver,
                          selectable: selectable,
                          selectedCardID: model.selection.plotCardID,
                          exiledCardIDs: exiledCardIDs,
                          metrics: metrics,
                          tokens: tokens,
                          onSwapCardDrop: onSwapCardDrop,
                          onCardTap: (cardID) =>
                              onPlotCardTap?.call(cardID, plotZoneHidden),
                        ),
                      ),
                      Expanded(
                        child: LocalPlotColumn(
                          title: 'Plot',
                          iconPath: fieldPlanPlotIconPath,
                          cards: viewerRevealedCards,
                          stacks: viewerStacks,
                          value: plotSectionValue(
                            viewerRevealedCards,
                            viewerStacks,
                          ),
                          hidden: false,
                          selectable: selectable,
                          selectedCardID: model.selection.plotCardID,
                          exiledCardIDs: exiledCardIDs,
                          metrics: metrics,
                          tokens: tokens,
                          onSwapCardDrop: onSwapCardDrop,
                          onCardTap: (cardID) =>
                              onPlotCardTap?.call(cardID, plotZoneRevealed),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

List<Widget> plotOverviewCardItems({
  required List<TableCard> cards,
  required List<PlotStackState> stacks,
  required bool hiddenCards,
  required TokenCardSize cardSize,
  required String? selectedCardID,
  required bool selectable,
  bool revealHiddenCards = false,
  bool splitHiddenCardFront = false,
  required String zone,
  required Set<String> exiledCardIDs,
  required DesignTokens tokens,
  required void Function(String cardID, String zone)? onPlotCardTap,
  SwapCardDropCallback? onSwapCardDrop,
}) {
  return [
    for (final card in cards)
      Builder(
        builder: (context) {
          final cardControl = PlotCardExileFrame(
            exiled: exiledCardIDs.contains(card.id),
            tokens: tokens,
            radius: tokens.radius.card,
            child: SwapSelectedCardFrame(
              cardID: card.id,
              selected: card.id == selectedCardID,
              tokens: tokens,
              child: TactileCardSurface(
                tokens: tokens,
                size: cardSize,
                pressEnabled: selectable,
                child: hiddenCards
                    ? InteractiveCardFlip(
                        key: ValueKey('cellar-card-${card.id}'),
                        concealedLabel: 'Cellar card. Tap to reveal.',
                        revealedLabel:
                            '${card.rank} of ${card.suit}. Tap to conceal.',
                        frontKey: ValueKey('cellar-face-${card.id}'),
                        backKey: ValueKey('cellar-back-${card.id}'),
                        forceShowFront: revealHiddenCards,
                        onTap: selectable
                            ? () => onPlotCardTap?.call(card.id, zone)
                            : null,
                        front: splitHiddenCardFront
                            ? CellarCardSplitPreview(
                                cardID: card.id,
                                size: cardSize,
                                tokens: tokens,
                                front: GameCard(
                                  card: selectedPlotCard(card, selectedCardID),
                                  tokens: tokens,
                                  sizeOverride: cardSize,
                                  motionTracked: false,
                                ),
                                back: ScaledHighlightableCardBack(
                                  card: selectedPlotCard(card, selectedCardID),
                                  tokens: tokens,
                                  size: cardSize,
                                ),
                              )
                            : GameCard(
                                card: selectedPlotCard(card, selectedCardID),
                                tokens: tokens,
                                sizeOverride: cardSize,
                                motionTracked: false,
                              ),
                        back: ScaledHighlightableCardBack(
                          card: selectedPlotCard(card, selectedCardID),
                          tokens: tokens,
                          size: cardSize,
                        ),
                      )
                    : GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: selectable
                            ? () => onPlotCardTap?.call(card.id, zone)
                            : null,
                        child: GameCard(
                          card: selectedPlotCard(card, selectedCardID),
                          tokens: tokens,
                          sizeOverride: cardSize,
                        ),
                      ),
              ),
            ),
          );
          if (!selectable || onPlotCardTap == null) {
            return TetheredCardSurface(
              key: ValueKey('viewer-plot-fidget-${card.id}'),
              child: cardControl,
            );
          }
          final draggableCard = DraggableCardSurface(
            data: CardDragData(
              cardID: card.id,
              kind: CardDragKind.plot,
              phase: phaseSwap,
              plotZone: zone,
              onSwapWith: onSwapCardDrop == null
                  ? null
                  : (handCardID, _) =>
                        onSwapCardDrop(handCardID, card.id, zone),
              onAccepted: () => onPlotCardTap(card.id, zone),
            ),
            feedback: GameCard(
              card: selectedPlotCard(card, selectedCardID),
              tokens: tokens,
              sizeOverride: cardSize,
              motionTracked: false,
            ),
            child: cardControl,
          );
          return CardDropTarget(
            highlightColor: tokens.colors.green,
            borderRadius: tokens.radius.card,
            dragFeedbackSize: Size(cardSize.width, cardSize.height),
            accepts: (data) =>
                data.canDrop &&
                data.kind == CardDragKind.hand &&
                data.phase == phaseSwap,
            onAccepted: (data) {
              final commitSwap = data.onSwapWith;
              if (commitSwap != null) {
                commitSwap(card.id, zone);
                return;
              }
              data.onAccepted();
              onPlotCardTap(card.id, zone);
            },
            child: draggableCard,
          );
        },
      ),
    for (final stack in stacks) ...[
      for (final card in stack.revealed.take(2))
        GameOverPlotCard(
          card: card,
          size: cardSize,
          exiled: exiledCardIDs.contains(card.id),
          tokens: tokens,
        ),
      if (stack.hidden.isNotEmpty)
        GameOverPlotHiddenStackBack(
          hiddenCount: stack.hidden.length,
          size: cardSize,
          tokens: tokens,
        ),
    ],
  ];
}

class SwapSelectedCardFrame extends StatelessWidget {
  const SwapSelectedCardFrame({
    required this.cardID,
    required this.selected,
    required this.tokens,
    required this.child,
    super.key,
  });

  final String cardID;
  final bool selected;
  final DesignTokens tokens;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!selected) {
      return child;
    }
    return Container(
      key: ValueKey('swap-selected-plot-card-$cardID'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardViewCornerRadius),
        boxShadow: [
          BoxShadow(
            color: tokens.colors.green.withValues(alpha: 0.72),
            blurRadius: 9,
            spreadRadius: 2,
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardViewCornerRadius),
        border: Border.all(
          color: tokens.colors.green,
          width: math.max(3, tokens.stroke.active),
        ),
      ),
      child: child,
    );
  }
}

class GameOverPlotCard extends StatelessWidget {
  const GameOverPlotCard({
    required this.card,
    required this.size,
    required this.exiled,
    required this.tokens,
    super.key,
  });

  final TableCard card;
  final TokenCardSize size;
  final bool exiled;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return PlotCardExileFrame(
      exiled: exiled,
      tokens: tokens,
      radius: tokens.radius.card,
      child: GameCard(
        card: card,
        tokens: tokens,
        sizeOverride: size,
        motionTracked: false,
      ),
    );
  }
}

class GameOverPlotHiddenStackBack extends StatelessWidget {
  const GameOverPlotHiddenStackBack({
    required this.hiddenCount,
    required this.size,
    required this.tokens,
    super.key,
  });

  final int hiddenCount;
  final TokenCardSize size;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ScaledCardBack(tokens: tokens, size: size),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: tokens.colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(tokens.radius.xs),
          ),
          child: DisplayText(
            '$hiddenCount',
            size: DisplayTextSize.title,
            variant: DisplayTextWeight.bold,
            color: tokens.colors.gold,
          ),
        ),
      ],
    );
  }
}

class ScaledCardBack extends StatelessWidget {
  const ScaledCardBack({required this.tokens, required this.size, super.key});

  final DesignTokens tokens;
  final TokenCardSize size;

  @override
  Widget build(BuildContext context) {
    final scale = size.width / tokens.card.small.width;
    return NaturalSizeViewport(
      width: size.width,
      height: size.height,
      naturalWidth: tokens.card.small.width,
      naturalHeight: tokens.card.small.height,
      child: Transform.scale(
        alignment: Alignment.topLeft,
        scale: scale,
        child: CardBackMini(tokens: tokens),
      ),
    );
  }
}

class ScaledHighlightableCardBack extends StatelessWidget {
  const ScaledHighlightableCardBack({
    required this.card,
    required this.tokens,
    required this.size,
    super.key,
  });

  final TableCard card;
  final DesignTokens tokens;
  final TokenCardSize size;

  @override
  Widget build(BuildContext context) {
    final scale = size.width / tokens.card.small.width;
    return NaturalSizeViewport(
      width: size.width,
      height: size.height,
      naturalWidth: tokens.card.small.width,
      naturalHeight: tokens.card.small.height,
      child: Transform.scale(
        alignment: Alignment.topLeft,
        scale: scale,
        child: HighlightableCardBack(card: card, tokens: tokens),
      ),
    );
  }
}

/// Shows a cellar-origin swap target as mostly face-up with a card-back wedge.
///
/// The upper-left face area preserves the card's rank and suit information. The
/// lower-right back wedge indicates that the replacement card will occupy a
/// face-down cellar slot after the swap.
class CellarCardSplitPreview extends StatelessWidget {
  const CellarCardSplitPreview({
    required this.cardID,
    required this.size,
    required this.tokens,
    required this.front,
    required this.back,
    super.key,
  });

  final String cardID;
  final TokenCardSize size;
  final DesignTokens tokens;
  final Widget front;
  final Widget back;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cellar card, shown with its face-down status',
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(cardViewCornerRadius),
          child: Stack(
            key: ValueKey('cellar-split-preview-$cardID'),
            fit: StackFit.expand,
            children: [
              front,
              ClipPath(
                key: ValueKey('cellar-back-wedge-$cardID'),
                clipper: const _CellarBackWedgeClipper(),
                child: back,
              ),
              IgnorePointer(
                child: CustomPaint(
                  painter: _CellarSplitSeamPainter(tokens: tokens),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CellarBackWedgeClipper extends CustomClipper<Path> {
  const _CellarBackWedgeClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, size.height * 0.35)
    ..lineTo(0, size.height)
    ..lineTo(size.width * 0.9, size.height)
    ..close();

  @override
  bool shouldReclip(_CellarBackWedgeClipper oldClipper) => false;
}

class _CellarSplitSeamPainter extends CustomPainter {
  const _CellarSplitSeamPainter({required this.tokens});

  final DesignTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(0, size.height * 0.35);
    final end = Offset(size.width * 0.9, size.height);
    canvas
      ..drawLine(
        start,
        end,
        Paint()
          ..color = tokens.colors.black.withValues(alpha: 0.72)
          ..strokeWidth = 2.4,
      )
      ..drawLine(
        start,
        end,
        Paint()
          ..color = tokens.colors.gold.withValues(alpha: 0.82)
          ..strokeWidth = 0.9,
      );
  }

  @override
  bool shouldRepaint(_CellarSplitSeamPainter oldDelegate) =>
      oldDelegate.tokens != tokens;
}

TokenCardSize plotOverviewCardSize(
  TokenCardSize base,
  Size available,
  int itemCount,
) {
  final availableWidth = available.width.isFinite
      ? available.width
      : plotOverviewFallbackWidth;
  final rawAvailableHeight = available.height.isFinite
      ? available.height
      : plotOverviewFallbackHeight;
  final availableHeight = math.min(rawAvailableHeight, plotOverviewHeightCap);
  final maxByHeight =
      (availableHeight * plotOverviewCardHeightFill) / base.height;
  final overlappedWidthUnits =
      1 + (itemCount - 1) * (1 - plotOverviewCardOverlapFraction);
  final maxByWidth =
      (availableWidth * 0.86) / (base.width * overlappedWidthUnits);
  final heightAwareMinScale = math.min(plotOverviewCardScaleMin, maxByHeight);
  final scale = clampDouble(
    math.min(maxByHeight, maxByWidth),
    heightAwareMinScale,
    plotOverviewCardScaleMax,
  );
  return scaledPlotCardSize(base, scale);
}

int plotOverviewItemCount(List<TableCard> cards, List<PlotStackState> stacks) {
  final stackCards = stacks.fold<int>(0, (count, stack) {
    final revealedCount = stack.revealed.length > 2 ? 2 : stack.revealed.length;
    return count + revealedCount + (stack.hidden.isEmpty ? 0 : 1);
  });
  return math.max(1, cards.length + stackCards);
}

TokenCardSize scaledPlotCardSize(TokenCardSize base, double scale) {
  return TokenCardSize(
    width: base.width * scale,
    height: base.height * scale,
    faceInset: base.faceInset * scale,
    cornerWidth: base.cornerWidth * scale,
    cornerHeight: base.cornerHeight * scale,
    cornerRankFontSize: base.cornerRankFontSize * scale,
    cornerSuitSize: base.cornerSuitSize * scale,
    topCornerRankSuitSpacing: base.topCornerRankSuitSpacing * scale,
    bottomCornerRankSuitSpacing: base.bottomCornerRankSuitSpacing * scale,
    topCornerSuitXOffset: base.topCornerSuitXOffset * scale,
    bottomCornerSuitXOffset: base.bottomCornerSuitXOffset * scale,
    pipSize: base.pipSize * scale,
  );
}

double plotOverviewCardOverlap(double cardWidth) {
  return -clampDouble(
    cardWidth * plotOverviewCardOverlapFraction,
    plotOverviewCardOverlapMin,
    plotOverviewCardOverlapMax,
  );
}

const plotOverviewCardScaleMin = 0.88;
const plotOverviewCardScaleMax = 1.45;
const plotOverviewCardHeightFill = 0.74;
const plotOverviewCardOverlapFraction = 0.18;
const plotOverviewCardOverlapMin = 18.0;
const plotOverviewCardOverlapMax = 36.0;
const plotOverviewFallbackWidth = 420.0;
const plotOverviewFallbackHeight = 128.0;
const plotOverviewHeightCap = 150.0;
const plotOpponentCardHeightFraction = 0.48;
const plotOpponentCardWidthFraction = 0.22;
const plotOpponentPortraitHeightFraction = 0.42;
const plotOpponentPortraitWidthFraction = 0.18;

class PlotPanelMetrics {
  const PlotPanelMetrics({
    required this.spacing,
    required this.padding,
    required this.opponentHeight,
    required this.opponentCardScale,
    required this.opponentCardFrameWidth,
    required this.opponentCardFrameHeight,
    required this.portraitSize,
    required this.panelPadding,
    required this.headerIconSize,
    required this.columnCardSpacing,
    required this.columnTrailingPadding,
  });

  factory PlotPanelMetrics.fromSize(Size size, DesignTokens tokens) {
    final shorter = size.shortestSide;
    final plot = tokens.layout.plot;
    final spacing = clampDouble(shorter * 0.02, 7, 10);
    final opponentHeight = size.height * plot.opponentHeightFraction;
    final panelPadding = clampDouble(shorter * 0.018, 7, 8);
    final estimatedOpponentPanelWidth = size.width / 3;
    final opponentCardFrameHeight = math.min(
      opponentHeight * plotOpponentCardHeightFraction,
      estimatedOpponentPanelWidth *
          plotOpponentCardWidthFraction *
          tokens.card.aspectRatio,
    );
    final opponentCardScale =
        opponentCardFrameHeight / tokens.card.small.height;
    return PlotPanelMetrics(
      spacing: spacing,
      padding: clampDouble(shorter * 0.025, 8, 12),
      opponentHeight: opponentHeight,
      opponentCardScale: opponentCardScale,
      opponentCardFrameWidth: opponentCardFrameHeight / tokens.card.aspectRatio,
      opponentCardFrameHeight: opponentCardFrameHeight,
      portraitSize: math.min(
        opponentHeight * plotOpponentPortraitHeightFraction,
        estimatedOpponentPanelWidth * plotOpponentPortraitWidthFraction,
      ),
      panelPadding: panelPadding,
      headerIconSize: clampDouble(size.width * 0.026, 17, 20),
      columnCardSpacing: clampDouble(-size.width * 0.04, -30, -24),
      columnTrailingPadding: clampDouble(size.width * 0.035, 20, 28),
    );
  }

  final double spacing;
  final double padding;
  final double opponentHeight;
  final double opponentCardScale;
  final double opponentCardFrameWidth;
  final double opponentCardFrameHeight;
  final double portraitSize;
  final double panelPadding;
  final double headerIconSize;
  final double columnCardSpacing;
  final double columnTrailingPadding;

  PlotPanelMetrics copyWith({
    double? spacing,
    double? padding,
    double? opponentHeight,
    double? opponentCardScale,
    double? opponentCardFrameWidth,
    double? opponentCardFrameHeight,
    double? portraitSize,
    double? panelPadding,
    double? headerIconSize,
    double? columnCardSpacing,
    double? columnTrailingPadding,
  }) {
    return PlotPanelMetrics(
      spacing: spacing ?? this.spacing,
      padding: padding ?? this.padding,
      opponentHeight: opponentHeight ?? this.opponentHeight,
      opponentCardScale: opponentCardScale ?? this.opponentCardScale,
      opponentCardFrameWidth:
          opponentCardFrameWidth ?? this.opponentCardFrameWidth,
      opponentCardFrameHeight:
          opponentCardFrameHeight ?? this.opponentCardFrameHeight,
      portraitSize: portraitSize ?? this.portraitSize,
      panelPadding: panelPadding ?? this.panelPadding,
      headerIconSize: headerIconSize ?? this.headerIconSize,
      columnCardSpacing: columnCardSpacing ?? this.columnCardSpacing,
      columnTrailingPadding:
          columnTrailingPadding ?? this.columnTrailingPadding,
    );
  }
}

class OpponentPlotPanel extends StatelessWidget {
  const OpponentPlotPanel({
    required this.seat,
    required this.metrics,
    required this.tokens,
    required this.exiledCardIDs,
    required this.hiddenExiledCardIDs,
    this.revealCellarCards = false,
    super.key,
  });

  final Seat seat;
  final PlotPanelMetrics metrics;
  final DesignTokens tokens;
  final Set<String> exiledCardIDs;
  final Set<String> hiddenExiledCardIDs;
  final bool revealCellarCards;

  @override
  Widget build(BuildContext context) {
    final visibleHiddenCards = visiblePlotCards(
      seat.plot.hidden,
      hiddenExiledCardIDs,
    );
    final visibleRevealedCards = visiblePlotCards(
      seat.plot.revealed,
      hiddenExiledCardIDs,
    );
    final stackedRevealedCards = [
      for (final stack in seat.plot.stacks)
        ...visiblePlotCards(stack.revealed, hiddenExiledCardIDs),
    ];
    final stackedHiddenCards = [
      for (final stack in seat.plot.stacks)
        ...visiblePlotCards(stack.hidden, hiddenExiledCardIDs),
    ];
    final cellarCardCount =
        seat.plot.effectiveHiddenCardCount +
        seat.plot.stacks.fold<int>(
          0,
          (count, stack) => count + stack.effectiveHiddenCardCount,
        );
    final vulnerable = hasExiledPlotCard;
    return MotionTrackedRegion(
      motionKey: plotCardMotionSourceKey(seat.id),
      child: MotionImpactSurface(
        impactKey: 'opponent-plot-${seat.id}',
        style: MotionImpactStyle.stack,
        glowColor: tokens.colors.gold,
        matches: (impact) =>
            impact.destination.isPlot && impact.destination.seatID == seat.id,
        child: Container(
          padding: EdgeInsets.all(metrics.panelPadding),
          decoration: BoxDecoration(
            color: tokens.colors.black.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(tokens.radius.sm),
            border: Border.all(
              color: tokens.colors.steel.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: metrics.spacing * 0.75,
            children: [
              SizedBox(
                width: metrics.portraitSize + 12,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 3,
                  children: [
                    SizedBox(
                      width: metrics.portraitSize,
                      height: metrics.portraitSize,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          PortraitFrame(
                            seat: seat,
                            tokens: tokens,
                            width: metrics.portraitSize,
                            height: metrics.portraitSize,
                          ),
                          if (vulnerable)
                            Positioned(
                              top: -3,
                              right: -4,
                              child: Image.asset(
                                'assets/art/field_plan/shared/pictograms/'
                                'status-vulnerable.png',
                                width: 14,
                                height: 14,
                                filterQuality: FilterQuality.high,
                                isAntiAlias: true,
                              ),
                            ),
                        ],
                      ),
                    ),
                    DisplayText(
                      seat.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      size: DisplayTextSize.caption2,
                      variant: DisplayTextWeight.bold,
                      color: tokens.colors.cream,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: metrics.spacing * 0.5,
                  children: [
                    Expanded(
                      child: OpponentPlotMiniSection(
                        iconPath: fieldPlanCellarIconPath,
                        value: revealCellarCards
                            ? '${plotCardsValue([...visibleHiddenCards, ...stackedHiddenCards])}'
                            : '$cellarCardCount',
                        cards: [...visibleHiddenCards, ...stackedHiddenCards],
                        cardCount: cellarCardCount,
                        hidden: !revealCellarCards,
                        metrics: metrics,
                        tokens: tokens,
                        exiledCardIDs: exiledCardIDs,
                      ),
                    ),
                    Expanded(
                      child: OpponentPlotMiniSection(
                        iconPath: fieldPlanPlotIconPath,
                        value: '${visiblePlotScore(seat, hiddenExiledCardIDs)}',
                        cards: [
                          ...visibleRevealedCards,
                          ...stackedRevealedCards,
                        ],
                        hidden: false,
                        metrics: metrics,
                        tokens: tokens,
                        exiledCardIDs: exiledCardIDs,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get hasExiledPlotCard {
    return visiblePlotCards(
          seat.plot.hidden,
          hiddenExiledCardIDs,
        ).any((card) => exiledCardIDs.contains(card.id)) ||
        visiblePlotCards(
          seat.plot.revealed,
          hiddenExiledCardIDs,
        ).any((card) => exiledCardIDs.contains(card.id));
  }
}

class OpponentPlotMiniSection extends StatelessWidget {
  const OpponentPlotMiniSection({
    required this.iconPath,
    required this.value,
    required this.cards,
    this.cardCount,
    required this.hidden,
    required this.metrics,
    required this.tokens,
    required this.exiledCardIDs,
    super.key,
  });

  final String iconPath;
  final String value;
  final List<TableCard> cards;
  final int? cardCount;
  final bool hidden;
  final PlotPanelMetrics metrics;
  final DesignTokens tokens;
  final Set<String> exiledCardIDs;

  @override
  Widget build(BuildContext context) {
    const visibleCardLimit = 2;
    final displayCardCount = cardCount ?? cards.length;
    final cardWidgets = <Widget>[
      for (final card in cards.take(visibleCardLimit))
        NaturalSizeViewport(
          width: metrics.opponentCardFrameWidth,
          height: metrics.opponentCardFrameHeight,
          naturalWidth: tokens.card.small.width,
          naturalHeight: tokens.card.small.height,
          child: Transform.scale(
            alignment: Alignment.topLeft,
            scale:
                metrics.opponentCardScale *
                (exiledCardIDs.contains(card.id) ? 1.08 : 1),
            child: PlotCardExileFrame(
              exiled: exiledCardIDs.contains(card.id),
              radius: opponentPlotMiniExileRadius,
              tokens: tokens,
              child: TetheredCardSurface(
                key: ValueKey('opponent-mini-fidget-${card.id}'),
                child: hidden
                    ? MotionTrackedCard(
                        card: card,
                        child: CardBackMini(tokens: tokens),
                      )
                    : GameCard(card: card, tokens: tokens, small: true),
              ),
            ),
          ),
        ),
      for (
        var index = cards.length;
        index < math.min(displayCardCount, visibleCardLimit);
        index += 1
      )
        NaturalSizeViewport(
          key: ValueKey('opponent-hidden-card-$index'),
          width: metrics.opponentCardFrameWidth,
          height: metrics.opponentCardFrameHeight,
          naturalWidth: tokens.card.small.width,
          naturalHeight: tokens.card.small.height,
          child: Transform.scale(
            alignment: Alignment.topLeft,
            scale: metrics.opponentCardScale,
            child: TetheredCardSurface(
              key: ValueKey('opponent-mini-fidget-redacted-$index'),
              child: CardBackMini(tokens: tokens),
            ),
          ),
        ),
      if (displayCardCount == 0)
        SizedBox(
          width: metrics.opponentCardFrameWidth,
          height: metrics.opponentCardFrameHeight,
          child: Center(
            child: DisplayText(
              '-',
              size: DisplayTextSize.caption,
              variant: DisplayTextWeight.bold,
              color: tokens.colors.smoke.withValues(alpha: 0.72),
            ),
          ),
        ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(opponentPlotMiniSectionRadius),
      ),
      child: Row(
        spacing: 3,
        children: [
          SizedBox(
            width: metrics.headerIconSize + 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 1,
              children: [
                Image.asset(
                  iconPath,
                  width: metrics.headerIconSize,
                  height: metrics.headerIconSize,
                  filterQuality: FilterQuality.high,
                  isAntiAlias: true,
                ),
                DisplayText(
                  value,
                  size: DisplayTextSize.caption2,
                  variant: DisplayTextWeight.bold,
                  color: tokens.colors.gold,
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRect(
              child: OverlappedCardRow(
                itemWidth: metrics.opponentCardFrameWidth,
                itemHeight: metrics.opponentCardFrameHeight,
                spacing: metrics.columnCardSpacing * 0.56,
                children: cardWidgets,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LocalPlotColumn extends StatelessWidget {
  const LocalPlotColumn({
    required this.title,
    required this.iconPath,
    required this.cards,
    this.stacks = const [],
    required this.value,
    required this.hidden,
    bool? hiddenCards,
    this.revealHiddenCards = false,
    this.splitHiddenCardFront = false,
    required this.selectable,
    required this.selectedCardID,
    required this.exiledCardIDs,
    required this.metrics,
    required this.tokens,
    this.onCardTap,
    this.onSwapCardDrop,
    super.key,
  }) : hiddenCards = hiddenCards ?? hidden;

  final String title;
  final String iconPath;
  final List<TableCard> cards;
  final List<PlotStackState> stacks;
  final int value;
  final bool hidden;
  final bool hiddenCards;
  final bool revealHiddenCards;
  final bool splitHiddenCardFront;
  final bool selectable;
  final String? selectedCardID;
  final Set<String> exiledCardIDs;
  final PlotPanelMetrics metrics;
  final DesignTokens tokens;
  final ValueChanged<String>? onCardTap;
  final SwapCardDropCallback? onSwapCardDrop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(metrics.padding),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(tokens.radius.sm),
        border: Border.all(
          color: selectable
              ? tokens.colors.gold.withValues(alpha: 0.58)
              : tokens.colors.steel.withValues(alpha: 0.5),
          width: selectable ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: metrics.spacing * 0.75,
        children: [
          Row(
            spacing: 5,
            children: [
              Image.asset(
                iconPath,
                width: metrics.headerIconSize,
                height: metrics.headerIconSize,
                filterQuality: FilterQuality.high,
                isAntiAlias: true,
              ),
              DisplayText(
                title.toUpperCase(),
                size: DisplayTextSize.caption,
                variant: DisplayTextWeight.bold,
                color: tokens.colors.gold,
              ),
              const Spacer(),
              DisplayText(
                '$value',
                size: DisplayTextSize.caption2,
                color: tokens.colors.smoke,
              ),
            ],
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemCount = plotOverviewItemCount(cards, stacks);
                final cardSize = plotOverviewCardSize(
                  tokens.card.large,
                  constraints.biggest,
                  itemCount,
                );
                final cardWidgets = plotOverviewCardItems(
                  cards: cards,
                  stacks: stacks,
                  hiddenCards: hiddenCards,
                  revealHiddenCards: revealHiddenCards,
                  splitHiddenCardFront: splitHiddenCardFront,
                  cardSize: cardSize,
                  selectedCardID: selectedCardID,
                  selectable: selectable,
                  zone: hidden ? plotZoneHidden : plotZoneRevealed,
                  exiledCardIDs: exiledCardIDs,
                  tokens: tokens,
                  onSwapCardDrop: onSwapCardDrop,
                  onPlotCardTap: (cardID, _) => onCardTap?.call(cardID),
                );
                final children = cardWidgets.isEmpty
                    ? [
                        SizedBox(
                          width: cardSize.width,
                          height: cardSize.height,
                          child: Center(
                            child: DisplayText(
                              '-',
                              size: DisplayTextSize.title,
                              variant: DisplayTextWeight.bold,
                              color: tokens.colors.smoke.withValues(
                                alpha: 0.72,
                              ),
                            ),
                          ),
                        ),
                      ]
                    : cardWidgets;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: 2,
                      bottom: 2,
                      right: metrics.columnTrailingPadding,
                    ),
                    child: OverlappedCardRow(
                      itemWidth: cardSize.width,
                      itemHeight: cardSize.height,
                      spacing: plotOverviewCardOverlap(cardSize.width),
                      children: children,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

int plotSectionValue(List<TableCard> cards, List<PlotStackState> stacks) {
  return plotCardsValue(cards) +
      stacks.fold<int>(
        0,
        (sum, stack) =>
            sum + plotCardsValue(stack.revealed) + plotCardsValue(stack.hidden),
      );
}

int plotCardsValue(Iterable<TableCard> cards) {
  return cards.fold<int>(0, (sum, card) => sum + card.value);
}

class PlotStackMini extends StatelessWidget {
  const PlotStackMini({
    required this.stack,
    required this.index,
    required this.metrics,
    required this.tokens,
    super.key,
  });

  final PlotStackState stack;
  final int index;
  final PlotPanelMetrics metrics;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final revealed = stack.revealed;
    final hidden = stack.hidden;
    return Container(
      key: ValueKey('plot-stack-mini-$index'),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.colors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(tokens.radius.sm),
        border: Border.all(color: tokens.colors.gold.withValues(alpha: 0.32)),
      ),
      child: Row(
        spacing: 4,
        children: [
          for (final card in revealed.take(2))
            GameCard(card: card, tokens: tokens, small: true),
          if (hidden.isNotEmpty)
            Stack(
              alignment: Alignment.center,
              children: [
                CardBackMini(tokens: tokens),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(tokens.radius.xs),
                  ),
                  child: DisplayText(
                    '${hidden.length}',
                    size: DisplayTextSize.caption2,
                    variant: DisplayTextWeight.bold,
                    color: tokens.colors.gold,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class PlotCardExileFrame extends StatelessWidget {
  const PlotCardExileFrame({
    required this.exiled,
    required this.tokens,
    required this.child,
    this.radius = cardViewCornerRadius,
    super.key,
  });

  final bool exiled;
  final DesignTokens tokens;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (!exiled) {
      return child;
    }
    return Container(
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: tokens.colors.redBright, width: 3),
      ),
      child: child,
    );
  }
}

class OverlappedCardRow extends StatelessWidget {
  const OverlappedCardRow({
    required this.children,
    required this.itemWidth,
    required this.itemHeight,
    required this.spacing,
    super.key,
  });

  final List<Widget> children;
  final double itemWidth;
  final double itemHeight;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final step = itemWidth + spacing > 1 ? itemWidth + spacing : 1.0;
    final width = children.isEmpty
        ? 0.0
        : itemWidth + step * (children.length - 1);
    return SizedBox(
      width: width,
      height: itemHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (index, child) in children.indexed)
            Positioned(left: index * step, top: 0, child: child),
        ],
      ),
    );
  }
}

class HighlightableCardBack extends StatelessWidget {
  const HighlightableCardBack({
    required this.card,
    required this.tokens,
    super.key,
  });

  final TableCard card;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final border = card.selected
        ? tokens.colors.green
        : card.highlighted
        ? tokens.colors.gold
        : Colors.transparent;
    return MotionTrackedCard(
      card: card,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cardViewCornerRadius),
          border: Border.all(
            color: border,
            width: card.selected || card.highlighted ? tokens.stroke.active : 0,
          ),
        ),
        child: CardBackMini(tokens: tokens),
      ),
    );
  }
}

class CardBackMini extends StatelessWidget {
  const CardBackMini({required this.tokens, super.key});

  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final cardBack = KolkhozCardBackScope.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardViewCornerRadius),
        boxShadow: [
          BoxShadow(
            color: tokens.colors.black.withValues(
              alpha: tokens.colors.cardStrokeOpacity,
            ),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        width: tokens.card.small.width,
        height: tokens.card.small.height,
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
      ),
    );
  }
}
