import 'dart:math' as math;
import 'dart:ui' show clampDouble;

import 'package:flutter/material.dart';

import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/board_widgets.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/display/table_display.dart';
import 'package:kolkhoz_app/src/app/views/game/views/plots/plots_view.dart';
import 'package:kolkhoz_app/src/app/views/shared/chrome_button.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_assets.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_typography.dart';
import 'package:kolkhoz_app/src/app/views/shared/pixel_text.dart';

class GameOverPlotPanel extends StatelessWidget {
  const GameOverPlotPanel({
    required this.model,
    required this.tokens,
    required this.language,
    this.onNewGame,
    this.onReturnToLobby,
    this.onCopyGameResult,
    this.onSaveGameLog,
    this.returnsToLobby = false,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final VoidCallback? onNewGame;
  final VoidCallback? onReturnToLobby;
  final VoidCallback? onCopyGameResult;
  final VoidCallback? onSaveGameLog;
  final bool returnsToLobby;

  @override
  Widget build(BuildContext context) {
    final scores = model.table.gameResult?.scores ?? model.table.scoreboard;
    final winnerID =
        model.table.gameResult?.winnerSeatID ?? inferredWinnerID(scores);
    final sortedSeats = model.table.seats.toList(growable: false)
      ..sort((left, right) {
        final scoreComparison = finalScoreForSeat(
          scores,
          right.id,
        ).compareTo(finalScoreForSeat(scores, left.id));
        return scoreComparison != 0
            ? scoreComparison
            : left.id.compareTo(right.id);
      });

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < gameOverCompactWidth ||
            constraints.maxHeight < gameOverCompactHeight;
        return Stack(
          key: const Key('game-over-poster'),
          fit: StackFit.expand,
          children: [
            Image.asset(
              fieldPlanStaticHeroBrigadeBackgroundPath,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
            ),
            ColoredBox(color: tokens.colors.black.withValues(alpha: 0.16)),
            SafeArea(
              minimum: EdgeInsets.all(compact ? 7 : 18),
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: compact ? 0.86 : 0.82,
                  heightFactor: compact ? 0.92 : 0.9,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: gameOverPosterMaxWidth,
                      maxHeight: gameOverPosterMaxHeight,
                    ),
                    child: Container(
                      key: const Key('game-over-poster-sheet'),
                      padding: EdgeInsets.all(compact ? 4 : 7),
                      decoration: BoxDecoration(
                        color: const Color(0xffd7c08a),
                        border: Border.all(
                          color: const Color(0xff322f25),
                          width: compact ? 2 : 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: tokens.colors.black.withValues(alpha: 0.46),
                            blurRadius: compact ? 8 : 18,
                            offset: Offset(compact ? 5 : 10, compact ? 5 : 10),
                          ),
                        ],
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xffefe0b4),
                          border: Border.all(
                            color: const Color(0xff403b2d),
                            width: compact ? 1.5 : 2,
                          ),
                          image: const DecorationImage(
                            image: AssetImage(
                              'assets/art/field_plan/shared/textures/paper-light.png',
                            ),
                            fit: BoxFit.cover,
                            opacity: 0.2,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            compact ? 9 : 22,
                            compact ? 7 : 16,
                            compact ? 9 : 22,
                            compact ? 7 : 14,
                          ),
                          child: Column(
                            children: [
                              GameOverPlanRibbon(
                                year: model.table.year,
                                compact: compact,
                              ),
                              SizedBox(height: compact ? 4 : 8),
                              Expanded(
                                child: GameOverFinalScoreStrip(
                                  seats: sortedSeats,
                                  scores: scores,
                                  winnerID: winnerID,
                                  tokens: tokens,
                                  trump: model.table.trump,
                                  compact: compact,
                                ),
                              ),
                              SizedBox(height: compact ? 4 : 8),
                              GameOverPosterActions(
                                tokens: tokens,
                                language: language,
                                compact: compact,
                                returnsToLobby: returnsToLobby,
                                onCopyGameResult: onCopyGameResult,
                                onSaveGameLog: onSaveGameLog,
                                onPrimaryAction: returnsToLobby
                                    ? onReturnToLobby
                                    : onNewGame,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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

class GameOverPlanRibbon extends StatelessWidget {
  const GameOverPlanRibbon({
    required this.year,
    required this.compact,
    super.key,
  });

  final int year;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = '$year YEAR PLAN COMPLETE';
    return Container(
      key: const Key('game-over-plan-ribbon'),
      height: compact ? 38 : 58,
      margin: EdgeInsets.symmetric(horizontal: compact ? 14 : 28),
      padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 34),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xffaa2e1f),
        border: Border.all(
          color: const Color(0xfff0d599),
          width: compact ? 1.5 : 2,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x66322b22), offset: Offset(4, 4)),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          style: fieldPlanDisplayTextStyle.copyWith(
            color: const Color(0xffffe1a3),
            fontSize: compact ? 28 : 42,
            letterSpacing: compact ? 1.6 : 2.4,
          ),
        ),
      ),
    );
  }
}

class GameOverFinalScoreStrip extends StatelessWidget {
  const GameOverFinalScoreStrip({
    required this.seats,
    required this.scores,
    required this.winnerID,
    required this.tokens,
    required this.trump,
    this.compact = false,
    super.key,
  });

  final List<Seat> seats;
  final List<Score> scores;
  final int winnerID;
  final DesignTokens tokens;
  final String? trump;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: compact ? 4 : 8,
      children: [
        for (var row = 0; row < 2; row += 1)
          Expanded(
            child: Row(
              spacing: compact ? 4 : 8,
              children: [
                for (
                  var index = row * 2;
                  index < math.min(row * 2 + 2, seats.length);
                  index += 1
                )
                  Expanded(
                    child: GameOverFinalScorePill(
                      rank: index + 1,
                      seat: seats[index],
                      score: finalScoreForSeat(scores, seats[index].id),
                      winner: seats[index].id == winnerID,
                      tokens: tokens,
                      trump: trump,
                      compact: compact,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class GameOverFinalScorePill extends StatelessWidget {
  const GameOverFinalScorePill({
    required this.rank,
    required this.seat,
    required this.score,
    required this.winner,
    required this.tokens,
    required this.trump,
    this.compact = false,
    super.key,
  });

  final int rank;
  final Seat seat;
  final int score;
  final bool winner;
  final DesignTokens tokens;
  final String? trump;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = winner ? const Color(0xffaa2d20) : const Color(0xff312e26);
    final cellarCards = [
      ...seat.plot.hidden,
      for (final stack in seat.plot.stacks) ...stack.hidden,
    ];
    final plotCards = [
      ...seat.plot.revealed,
      for (final stack in seat.plot.stacks) ...stack.revealed,
    ];
    return Container(
      key: Key('game-over-score-${seat.id}'),
      padding: EdgeInsets.all(compact ? 4 : 7),
      decoration: BoxDecoration(
        color: winner ? const Color(0x14aa2d20) : const Color(0x0d312e26),
        border: Border.all(
          color: winner ? const Color(0xffaa2d20) : const Color(0x773d392d),
          width: winner ? (compact ? 1.5 : 2) : 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dense = compact || constraints.maxWidth < 360;
          Widget headerStat({
            required Key key,
            required String iconAsset,
            required int value,
          }) => SizedBox(
            key: key,
            child: Row(
              children: [
                Text(
                  '$value',
                  style: fieldPlanDisplayTextStyle.copyWith(
                    color: color,
                    fontSize: dense ? 14 : 20,
                  ),
                ),
                SizedBox(width: dense ? 2 : 3),
                Image.asset(
                  iconAsset,
                  width: dense ? 12 : 17,
                  height: dense ? 12 : 17,
                  filterQuality: FilterQuality.high,
                  isAntiAlias: true,
                ),
              ],
            ),
          );

          return Column(
            children: [
              SizedBox(
                height: dense ? 24 : 35,
                child: LayoutBuilder(
                  builder: (context, headerConstraints) {
                    final zoneGap = dense ? 4.0 : 7.0;
                    final tabWidth = dense ? 43.0 : 61.0;
                    final zoneWidth =
                        (headerConstraints.maxWidth - zoneGap) / 2;
                    final outsideWidth = math.max(0.0, zoneWidth - tabWidth);

                    return Row(
                      children: [
                        SizedBox(
                          width: outsideWidth,
                          child: Row(
                            children: [
                              SizedBox(
                                width: dense ? 11 : 20,
                                child: Text(
                                  '$rank',
                                  style: fieldPlanDisplayTextStyle.copyWith(
                                    color: color,
                                    fontSize: dense ? 16 : 23,
                                  ),
                                ),
                              ),
                              PortraitFrame(
                                seat: seat,
                                tokens: tokens,
                                width: dense ? 17 : 27,
                                height: dense ? 19 : 30,
                              ),
                              SizedBox(width: dense ? 2 : 5),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    seat.name.toUpperCase(),
                                    maxLines: 1,
                                    style: fieldPlanBodyStrongTextStyle
                                        .copyWith(
                                          color: color,
                                          fontSize: dense ? 11 : 17,
                                          letterSpacing: dense ? 0.2 : 0.7,
                                        ),
                                  ),
                                ),
                              ),
                              SizedBox(width: dense ? 2 : 4),
                              headerStat(
                                key: Key('game-over-medals-${seat.id}'),
                                iconAsset: fieldPlanMedalIconPath,
                                value: seat.totalMedals,
                              ),
                              SizedBox(width: dense ? 2 : 4),
                            ],
                          ),
                        ),
                        SizedBox(width: tabWidth),
                        SizedBox(width: zoneGap),
                        SizedBox(width: tabWidth),
                        SizedBox(
                          width: outsideWidth,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '$score',
                              style: fieldPlanDisplayTextStyle.copyWith(
                                color: color,
                                fontSize: dense ? 20 : 29,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(height: dense ? 2 : 4),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, zoneConstraints) {
                    final tabHeight = dense ? 26.0 : 39.0;
                    return OverflowBox(
                      alignment: Alignment.bottomCenter,
                      minHeight: zoneConstraints.maxHeight + tabHeight,
                      maxHeight: zoneConstraints.maxHeight + tabHeight,
                      child: SizedBox(
                        height: zoneConstraints.maxHeight + tabHeight,
                        child: Row(
                          children: [
                            Expanded(
                              child: GameOverScoreZone(
                                key: Key('game-over-cellar-box-${seat.id}'),
                                statKey: Key(
                                  'game-over-cellar-total-${seat.id}',
                                ),
                                sectionKey: Key('game-over-cellar-${seat.id}'),
                                iconAsset: fieldPlanCellarIconPath,
                                value: plotCardsValue(cellarCards),
                                cards: cellarCards,
                                trump: trump,
                                tokens: tokens,
                                compact: dense,
                                borderColor: const Color(0xffb9966c),
                                tabOnLeft: false,
                              ),
                            ),
                            SizedBox(width: dense ? 4 : 7),
                            Expanded(
                              child: GameOverScoreZone(
                                key: Key('game-over-plot-box-${seat.id}'),
                                statKey: Key('game-over-plot-total-${seat.id}'),
                                sectionKey: Key('game-over-plot-${seat.id}'),
                                iconAsset: fieldPlanPlotIconPath,
                                value: plotCardsValue(plotCards),
                                cards: plotCards,
                                trump: trump,
                                tokens: tokens,
                                compact: dense,
                                borderColor: const Color(0xff91ad79),
                                tabOnLeft: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class GameOverScoreZone extends StatelessWidget {
  const GameOverScoreZone({
    required this.statKey,
    required this.sectionKey,
    required this.iconAsset,
    required this.value,
    required this.cards,
    required this.trump,
    required this.tokens,
    required this.compact,
    required this.borderColor,
    required this.tabOnLeft,
    super.key,
  });

  final Key statKey;
  final Key sectionKey;
  final String iconAsset;
  final int value;
  final List<TableCard> cards;
  final String? trump;
  final DesignTokens tokens;
  final bool compact;
  final Color borderColor;
  final bool tabOnLeft;

  @override
  Widget build(BuildContext context) {
    final tabHeight = compact ? 26.0 : 39.0;
    return CustomPaint(
      painter: GameOverScoreZonePainter(
        borderColor: borderColor,
        tabHeight: tabHeight,
        tabWidth: compact ? 43 : 61,
        strokeWidth: compact ? 1.25 : 1.75,
        tabOnLeft: tabOnLeft,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            key: statKey,
            top: 0,
            left: tabOnLeft ? (compact ? 4 : 6) : null,
            right: tabOnLeft ? null : (compact ? 4 : 6),
            height: tabHeight - (compact ? 2 : 4),
            child: Row(
              children: [
                Text(
                  '$value',
                  style: fieldPlanDisplayTextStyle.copyWith(
                    color: const Color(0xff3b382d),
                    fontSize: compact ? 13 : 18,
                  ),
                ),
                SizedBox(width: compact ? 2 : 3),
                Image.asset(
                  iconAsset,
                  width: compact ? 12 : 17,
                  height: compact ? 12 : 17,
                  filterQuality: FilterQuality.high,
                  isAntiAlias: true,
                ),
              ],
            ),
          ),
          Positioned(
            left: compact ? 3 : 5,
            top: tabHeight + (compact ? 2 : 3),
            right: compact ? 3 : 5,
            bottom: compact ? 3 : 5,
            child: GameOverScoreCardSection(
              key: sectionKey,
              cards: cards,
              trump: trump,
              tokens: tokens,
              compact: compact,
            ),
          ),
        ],
      ),
    );
  }
}

class GameOverScoreZonePainter extends CustomPainter {
  const GameOverScoreZonePainter({
    required this.borderColor,
    required this.tabHeight,
    required this.tabWidth,
    required this.strokeWidth,
    required this.tabOnLeft,
  });

  final Color borderColor;
  final double tabHeight;
  final double tabWidth;
  final double strokeWidth;
  final bool tabOnLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final tabEdge = math.min(size.width, tabWidth);
    final tabLeft = math.max(0.0, size.width - tabWidth);
    final path = tabOnLeft
        ? (Path()
            ..moveTo(0, 0)
            ..lineTo(tabEdge, 0)
            ..lineTo(tabEdge, tabHeight)
            ..lineTo(size.width, tabHeight)
            ..lineTo(size.width, size.height)
            ..lineTo(0, size.height)
            ..close())
        : (Path()
            ..moveTo(0, tabHeight)
            ..lineTo(tabLeft, tabHeight)
            ..lineTo(tabLeft, 0)
            ..lineTo(size.width, 0)
            ..lineTo(size.width, size.height)
            ..lineTo(0, size.height)
            ..close());
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = borderColor.withValues(alpha: 0.08)
          ..style = PaintingStyle.fill,
      )
      ..drawPath(
        path,
        Paint()
          ..color = borderColor.withValues(alpha: 0.86)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
  }

  @override
  bool shouldRepaint(GameOverScoreZonePainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.tabHeight != tabHeight ||
        oldDelegate.tabWidth != tabWidth ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.tabOnLeft != tabOnLeft;
  }
}

class GameOverScoreCardSection extends StatelessWidget {
  const GameOverScoreCardSection({
    required this.cards,
    required this.trump,
    required this.tokens,
    required this.compact,
    super.key,
  });

  final List<TableCard> cards;
  final String? trump;
  final DesignTokens tokens;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (cards.isEmpty) {
          return Center(
            child: Text(
              '—',
              style: fieldPlanBodyStrongTextStyle.copyWith(
                color: const Color(0x993d392d),
                fontSize: compact ? 12 : 18,
              ),
            ),
          );
        }
        final cardHeight = math.max(
          20.0,
          math.min(
            constraints.maxHeight - (compact ? 2 : 4),
            compact ? 68 : 96,
          ),
        );
        final scale = cardHeight / tokens.card.small.height;
        final cardSize = scaledPlotCardSize(tokens.card.small, scale);
        final availableWidth = math.max(1.0, constraints.maxWidth - 2);
        final step = cards.length <= 1
            ? cardSize.width
            : clampDouble(
                (availableWidth - cardSize.width) / (cards.length - 1),
                cardSize.width * 0.18,
                cardSize.width,
              );

        return ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            child: OverlappedCardRow(
              itemWidth: cardSize.width,
              itemHeight: cardSize.height,
              spacing: step - cardSize.width,
              children: [
                for (final card in cards)
                  GameCard(
                    card: card,
                    tokens: tokens,
                    trump: trump,
                    sizeOverride: cardSize,
                    motionTracked: false,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class GameOverPosterActions extends StatelessWidget {
  const GameOverPosterActions({
    required this.tokens,
    required this.language,
    required this.compact,
    required this.returnsToLobby,
    this.onCopyGameResult,
    this.onSaveGameLog,
    this.onPrimaryAction,
    super.key,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final bool compact;
  final bool returnsToLobby;
  final VoidCallback? onCopyGameResult;
  final VoidCallback? onSaveGameLog;
  final VoidCallback? onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 38.0 : 51.0;
    Widget button({
      required String label,
      required Key key,
      required bool prominent,
      required VoidCallback? onPressed,
      String? iconAsset,
    }) {
      return Expanded(
        child: ChromeAssetButton.command(
          label: label,
          tokens: tokens,
          prominent: prominent,
          onPressed: onPressed,
          iconAsset: iconAsset,
          iconSize: compact ? 16 : 21,
          width: double.infinity,
          height: height,
          padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 12),
          textSize: compact ? PixelTextSize.caption2 : PixelTextSize.caption,
          spacing: compact ? 4 : 7,
          surfaceKey: key,
        ),
      );
    }

    return SizedBox(
      height: height,
      child: Row(
        spacing: compact ? 6 : 12,
        children: [
          button(
            label: language.strings.kolkhozappCopyResult,
            key: const Key('game-over-copy-result-button'),
            prominent: true,
            onPressed: onCopyGameResult,
            iconAsset: 'assets/ui/Icons/icon-copy.png',
          ),
          button(
            label: language == KolkhozLanguage.en
                ? 'Save Log'
                : 'Сохранить журнал',
            key: const Key('game-over-save-log-button'),
            prominent: false,
            onPressed: onSaveGameLog,
            iconAsset: fieldPlanSaveFavorite.fieldPlanPath,
          ),
          button(
            label: returnsToLobby
                ? language.strings.kolkhozappMainMenu2
                : language.strings.kolkhozappNewGame2,
            key: Key(
              returnsToLobby
                  ? 'game-over-main-menu-button'
                  : 'game-over-new-game-button',
            ),
            prominent: false,
            onPressed: onPrimaryAction,
            iconAsset: fieldPlanNavigationMenuPath,
          ),
        ],
      ),
    );
  }
}

const gameOverCompactWidth = 760.0;
const gameOverCompactHeight = 440.0;
const gameOverPosterMaxWidth = 1050.0;
const gameOverPosterMaxHeight = 650.0;
