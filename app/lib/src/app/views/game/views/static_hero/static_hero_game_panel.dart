import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/settings/game_motion.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/assignment_projection.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/controller_projection.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/views/brigade/brigade_view.dart'
    show HeroMedalPulse;
import 'package:kolkhoz_app/src/app/views/game/views/brigade/planning_phase_view.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/board_widgets.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/display/plot_display.dart';
import 'package:kolkhoz_app/src/app/views/game/views/fields/fields_view.dart';
import 'package:kolkhoz_app/src/app/views/game/views/plots/plots_view.dart';
import 'package:kolkhoz_app/src/app/views/shared/chrome_button.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_assets.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_typography.dart';

enum StaticHeroGamePanelKind { brigade, fields, north }

const _brigadePosterLayoutHeight = 410.0;
const _staticHeroCompactHeaderClearance = 54.0;

const _fieldJobHorizontalInset = 0.02;
const _fieldJobColumnGap = 0.02;
const _fieldJobColumnWidth =
    (1 - _fieldJobHorizontalInset * 2 - _fieldJobColumnGap) / 2;
const _fieldJobRightColumnLeft =
    _fieldJobHorizontalInset + _fieldJobColumnWidth + _fieldJobColumnGap;
const _fieldJobTop = 0.20;
const _fieldJobTopRowHeight = 0.31;
const _fieldJobRowGap = 0.035;
const _fieldJobBottom = 0.035;
const _fieldJobBottomRowTop =
    _fieldJobTop + _fieldJobTopRowHeight + _fieldJobRowGap;
const _fieldJobBottomRowHeight = 1 - _fieldJobBottomRowTop - _fieldJobBottom;
// A suit pictogram and two-digit progress value fit without truncation.
const _fieldJobCounterBaseWidth = 64.0;
const _fieldJobCounterBaseHeight = 18.0;
const _fieldJobRewardBaseWidth = 64.0;

const staticHeroJobRects = {
  'wheat': Rect.fromLTWH(
    _fieldJobHorizontalInset,
    _fieldJobTop,
    _fieldJobColumnWidth,
    _fieldJobTopRowHeight,
  ),
  'beet': Rect.fromLTWH(
    _fieldJobRightColumnLeft,
    _fieldJobTop,
    _fieldJobColumnWidth,
    _fieldJobTopRowHeight,
  ),
  'sunflower': Rect.fromLTWH(
    _fieldJobHorizontalInset,
    _fieldJobBottomRowTop,
    _fieldJobColumnWidth,
    _fieldJobBottomRowHeight,
  ),
  'potato': Rect.fromLTWH(
    _fieldJobRightColumnLeft,
    _fieldJobBottomRowTop,
    _fieldJobColumnWidth,
    _fieldJobBottomRowHeight,
  ),
};

class StaticHeroJobMotionTargets extends StatelessWidget {
  const StaticHeroJobMotionTargets({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Stack(
          children: [
            for (final entry in staticHeroJobRects.entries)
              Positioned.fromRect(
                rect: Rect.fromLTWH(
                  size.width * entry.value.left,
                  size.height * entry.value.top,
                  size.width * entry.value.width,
                  size.height * entry.value.height,
                ),
                child: MotionTrackedRegion(
                  motionKey: jobFieldMotionTargetKey(entry.key),
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        );
      },
    );
  }
}

extension on StaticHeroGamePanelKind {
  String get asset =>
      'assets/art/field_plan/game/backgrounds/'
      'static-hero-$name-underlay-v1.png';
}

class StaticHeroGamePanel extends StatelessWidget {
  const StaticHeroGamePanel({
    required this.kind,
    required this.model,
    required this.tokens,
    required this.language,
    this.compact = false,
    this.heroOfSovietUnion = true,
    this.showPlanningPanel = true,
    this.planningTrumpFocusedSuit,
    this.onPlanningTrumpActionSelected,
    this.onAction,
    this.onPlotCardTap,
    super.key,
  });

  final StaticHeroGamePanelKind kind;
  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final bool compact;
  final bool heroOfSovietUnion;
  final bool showPlanningPanel;
  final String? planningTrumpFocusedSuit;
  final ValueChanged<LegalAction>? onPlanningTrumpActionSelected;
  final ValueChanged<LegalAction>? onAction;
  final void Function(String cardID, String zone)? onPlotCardTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final posterCompact =
            compact ||
            constraints.maxWidth < 820 ||
            constraints.maxHeight < 440;
        return ClipRect(
          child: Stack(
            key: Key('production-static-hero-${kind.name}'),
            fit: StackFit.expand,
            children: [
              Image.asset(
                kind.asset,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(color: const Color(0x0d6f5a37)),
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: MotionTrackedRegion(
                    motionKey: northCardMotionTargetKey,
                    child: SizedBox(width: 48, height: 28),
                  ),
                ),
              ),
              switch (kind) {
                StaticHeroGamePanelKind.brigade => Padding(
                  padding: EdgeInsets.only(
                    top: posterCompact ? _staticHeroCompactHeaderClearance : 0,
                  ),
                  child: Align(
                    alignment: const Alignment(0, 0.3),
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: math.min(
                        math.max(
                          0,
                          constraints.maxHeight -
                              (posterCompact
                                  ? _staticHeroCompactHeaderClearance
                                  : 0),
                        ),
                        _brigadePosterLayoutHeight,
                      ),
                      child: _BrigadePosterContent(
                        model: model,
                        tokens: tokens,
                        language: language,
                        compact: posterCompact,
                        heroOfSovietUnion: heroOfSovietUnion,
                        showPlanningPanel: showPlanningPanel,
                        planningTrumpFocusedSuit: planningTrumpFocusedSuit,
                        onPlanningTrumpActionSelected:
                            onPlanningTrumpActionSelected,
                        onPlotCardTap: onPlotCardTap,
                      ),
                    ),
                  ),
                ),
                StaticHeroGamePanelKind.fields => _FieldsPosterContent(
                  model: model,
                  tokens: tokens,
                  onAction: onAction,
                ),
                StaticHeroGamePanelKind.north => _NorthPosterContent(
                  model: model,
                  tokens: tokens,
                ),
              },
            ],
          ),
        );
      },
    );
  }
}

class _BrigadePosterContent extends StatefulWidget {
  const _BrigadePosterContent({
    required this.model,
    required this.tokens,
    required this.language,
    required this.compact,
    required this.heroOfSovietUnion,
    required this.showPlanningPanel,
    this.planningTrumpFocusedSuit,
    this.onPlanningTrumpActionSelected,
    this.onPlotCardTap,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final bool compact;
  final bool heroOfSovietUnion;
  final bool showPlanningPanel;
  final String? planningTrumpFocusedSuit;
  final ValueChanged<LegalAction>? onPlanningTrumpActionSelected;
  final void Function(String cardID, String zone)? onPlotCardTap;

  @override
  State<_BrigadePosterContent> createState() => _BrigadePosterContentState();
}

class _BrigadePosterContentState extends State<_BrigadePosterContent> {
  int? inspectedSeatID;

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final seats = _brigadeSeatsAroundViewer(model);
    final seatPositionByID = {
      for (final (index, seat) in seats.indexed) seat.id: index,
    };
    final trick = model.table.phase == phaseAssignment
        ? visibleAssignmentTrick(model)
        : model.table.trick;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final contentScale = _posterContentScale(size.height);
        final profileBaseWidth = _sharedTrickProfileWidth(
          seats,
          maxTricks: model.table.maxTricks,
          textScaler: MediaQuery.textScalerOf(context),
        );
        final profileWidth = profileBaseWidth * contentScale;
        return Stack(
          children: [
            for (final (index, seat) in seats.indexed)
              Builder(
                builder: (context) {
                  final isLeftColumn = _trickColumn(index) == 0;
                  final isTopRow = _trickRow(index) == 0;
                  final profileRect = _trickProfileRect(
                    boardSize: size,
                    seatPosition: index,
                    profileWidth: profileWidth,
                    contentScale: contentScale,
                  );
                  final plotWidth = size.width * 0.46;
                  const plotProfileGap = 2.0;
                  final plotHeight = math.max(
                    0.0,
                    isTopRow
                        ? profileRect.top - plotProfileGap * 2
                        : size.height - profileRect.bottom - plotProfileGap * 2,
                  );
                  return _BrigadePlotZone(
                    seat: seat,
                    rect: Rect.fromLTWH(
                      isLeftColumn
                          ? profileRect.right - plotWidth
                          : profileRect.left,
                      isTopRow
                          ? profileRect.top - plotProfileGap - plotHeight
                          : profileRect.bottom + plotProfileGap,
                      plotWidth,
                      plotHeight,
                    ),
                    isLeftColumn: isLeftColumn,
                    isTopRow: isTopRow,
                    contentScale: contentScale,
                    model: model,
                    tokens: widget.tokens,
                    inspecting: inspectedSeatID == seat.id,
                    onPlotCardTap: widget.onPlotCardTap,
                  );
                },
              ),
            if (widget.showPlanningPanel && model.table.phase == phasePlanning)
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: widget.compact ? 190 : 250,
                    maxHeight: widget.compact ? 128 : 180,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: PlanningPhasePanel(
                      model: model,
                      tokens: widget.tokens,
                      language: widget.language,
                      focusedSuit: widget.planningTrumpFocusedSuit,
                      onAction: widget.onPlanningTrumpActionSelected,
                    ),
                  ),
                ),
              )
            else ...[
              Positioned(
                left: size.width * _trickGridRect.left,
                top: size.height * _trickGridRect.top,
                width: size.width * _trickGridRect.width,
                height: size.height * _trickGridRect.height,
                child: _PosterTrickGrid(
                  plays: trick.plays,
                  winnerSeatID: trick.winnerSeatID,
                  tokens: widget.tokens,
                  trump: model.table.trump,
                  seats: seats,
                  profileWidth: profileWidth,
                  profileBaseWidth: profileBaseWidth,
                  contentScale: contentScale,
                  maxTricks: model.table.maxTricks,
                  heroOfSovietUnion: widget.heroOfSovietUnion,
                  phase: model.table.phase,
                  seatPositionByID: seatPositionByID,
                  onInspectSeat: (seatID) => setState(() {
                    inspectedSeatID = inspectedSeatID == seatID ? null : seatID;
                  }),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

List<Seat> _brigadeSeatsAroundViewer(TableViewModel model) {
  final seats = [...model.table.seats]..sort((a, b) => a.id.compareTo(b.id));
  if (seats.length != 4) {
    return seats;
  }

  var viewerIndex = seats.indexWhere((seat) => seat.isViewer);
  final fallbackViewerSeatID = model.viewer.seatID;
  if (viewerIndex < 0 && fallbackViewerSeatID != null) {
    viewerIndex = seats.indexWhere((seat) => seat.id == fallbackViewerSeatID);
  }
  if (viewerIndex < 0) {
    viewerIndex = 0;
  }

  return [
    seats[(viewerIndex + 2) % seats.length],
    seats[(viewerIndex + 3) % seats.length],
    seats[(viewerIndex + 1) % seats.length],
    seats[viewerIndex],
  ];
}

class _PosterTrickGrid extends StatelessWidget {
  const _PosterTrickGrid({
    required this.plays,
    required this.winnerSeatID,
    required this.tokens,
    required this.trump,
    required this.seats,
    required this.profileWidth,
    required this.profileBaseWidth,
    required this.contentScale,
    required this.maxTricks,
    required this.heroOfSovietUnion,
    required this.phase,
    required this.seatPositionByID,
    required this.onInspectSeat,
  });

  final List<TrickPlay> plays;
  final int? winnerSeatID;
  final DesignTokens tokens;
  final String? trump;
  final List<Seat> seats;
  final double profileWidth;
  final double profileBaseWidth;
  final double contentScale;
  final int maxTricks;
  final bool heroOfSovietUnion;
  final String phase;
  final Map<int, int> seatPositionByID;
  final ValueChanged<int> onInspectSeat;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final slotWidth = constraints.maxWidth / 2;
        final slotHeight = constraints.maxHeight / 2;
        final clusterVerticalShift = _trickClusterVerticalShift(contentScale);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final entry in seatPositionByID.entries)
              Builder(
                builder: (context) {
                  final play = plays
                      .where((play) => play.seatID == entry.key)
                      .firstOrNull;
                  final seat = seats.firstWhere((seat) => seat.id == entry.key);
                  final isLeftColumn = _trickColumn(entry.value) == 0;
                  final isTopRow = _trickRow(entry.value) == 0;
                  final profileRect = _trickProfileRectWithinGrid(
                    gridSize: constraints.biggest,
                    seatPosition: entry.value,
                    profileWidth: profileWidth,
                    contentScale: contentScale,
                  );
                  return Positioned(
                    left: _trickColumn(entry.value) * slotWidth,
                    top: _trickRow(entry.value) * slotHeight,
                    width: slotWidth,
                    height: slotHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: Transform.translate(
                            offset: Offset(
                              isLeftColumn
                                  ? slotWidth *
                                        staticHeroTrickCardHorizontalInsetFactor
                                  : -slotWidth *
                                        staticHeroTrickCardHorizontalInsetFactor,
                              isTopRow
                                  ? -slotHeight *
                                            staticHeroTrickCardVerticalOutsetFactor -
                                        clusterVerticalShift
                                  : slotHeight *
                                            staticHeroTrickCardVerticalOutsetFactor -
                                        clusterVerticalShift,
                            ),
                            child: Transform.scale(
                              scale: staticHeroTrickCardScale,
                              child: MotionTrackedRegion(
                                motionKey: trickCardMotionTargetKey(entry.key),
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    3 * contentScale,
                                    _staticHeroTrickCardTopPadding *
                                        contentScale,
                                    3 * contentScale,
                                    _staticHeroTrickCardBottomPadding *
                                        contentScale,
                                  ),
                                  child: play == null
                                      ? const SizedBox.expand()
                                      : SizedBox(
                                          key: Key(
                                            'static-hero-trick-card-${play.card.id}',
                                          ),
                                          child: _SinglePosterCard(
                                            card: play.card,
                                            tokens: tokens,
                                            trump: trump,
                                            winningTrick:
                                                play.seatID == winnerSeatID,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left:
                              profileRect.left -
                              _trickColumn(entry.value) * slotWidth,
                          top:
                              profileRect.top -
                              _trickRow(entry.value) * slotHeight,
                          width: profileWidth,
                          height: _trickProfileHeight * contentScale,
                          child: FittedBox(
                            fit: BoxFit.fill,
                            child: SizedBox(
                              width: profileBaseWidth,
                              height: _trickProfileHeight,
                              child: MotionTrackedRegion(
                                motionKey: playerCardMotionSourceKey(seat.id),
                                child: GestureDetector(
                                  key: Key(
                                    'player-portrait-${seat.id}-inspect',
                                  ),
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => onInspectSeat(seat.id),
                                  child: _TrickPlayerProfile(
                                    seat: seat,
                                    tokens: tokens,
                                    maxTricks: maxTricks,
                                    winning: winnerSeatID == seat.id,
                                    portraitOnRight: isLeftColumn,
                                    heroWithinReach:
                                        heroOfSovietUnion &&
                                        seat.medals == maxTricks - 1 &&
                                        (phase == phaseTrick ||
                                            phase == phaseAssignment),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

int _trickColumn(int seatPosition) => seatPosition.isOdd ? 1 : 0;

int _trickRow(int seatPosition) => seatPosition < 2 ? 0 : 1;

const _trickGridRect = Rect.fromLTWH(0.31, 0.20, 0.38, 0.60);
const _trickProfileHeight = 72.0;
const _trickProfileCenterInset = 8.0;
const staticHeroTrickCardGrowth = 1.5;
const staticHeroTrickCardScale = 1.46 * staticHeroTrickCardGrowth;
const _staticHeroTrickCardInwardShiftFactor = 0.03;
const staticHeroTrickCardHorizontalInsetFactor =
    0.5 -
    (0.5 - 0.25) * staticHeroTrickCardGrowth +
    _staticHeroTrickCardInwardShiftFactor;
const staticHeroTrickPairHorizontalOutsetFactor =
    (0.5 - 0.25) * (staticHeroTrickCardGrowth - 1) + 0.055;
const staticHeroTrickPairVerticalOutsetFactor =
    0.5 * (staticHeroTrickCardGrowth - 1);
const staticHeroTrickCardVerticalOutsetFactor =
    staticHeroTrickPairVerticalOutsetFactor -
    _staticHeroTrickCardInwardShiftFactor;
const _staticHeroTrickCardTopPadding = 47.0;
const _staticHeroTrickCardBottomPadding = 3.0;
const _staticHeroPlotPadding = 4.0;
const _staticHeroProfileCardGapIncrease = 6.0;
const _staticHeroTrickProfileOutsetMax = 48.0;

double _posterContentScale(double height) =>
    (height / 410).clamp(0.45, 1).toDouble();

double _trickClusterVerticalShift(double contentScale) =>
    staticHeroTrickCardScale *
    (_staticHeroTrickCardTopPadding - _staticHeroTrickCardBottomPadding) /
    2 *
    contentScale;

Rect _trickProfileRect({
  required Size boardSize,
  required int seatPosition,
  required double profileWidth,
  required double contentScale,
}) {
  final gridSize = Size(
    boardSize.width * _trickGridRect.width,
    boardSize.height * _trickGridRect.height,
  );
  return _trickProfileRectWithinGrid(
    gridSize: gridSize,
    seatPosition: seatPosition,
    profileWidth: profileWidth,
    contentScale: contentScale,
  ).shift(
    Offset(
      boardSize.width * _trickGridRect.left,
      boardSize.height * _trickGridRect.top,
    ),
  );
}

Rect _trickProfileRectWithinGrid({
  required Size gridSize,
  required int seatPosition,
  required double profileWidth,
  required double contentScale,
}) {
  final slotWidth = gridSize.width / 2;
  final slotHeight = gridSize.height / 2;
  final isLeftColumn = _trickColumn(seatPosition) == 0;
  final isTopRow = _trickRow(seatPosition) == 0;
  final profileHeight = _trickProfileHeight * contentScale;
  final profileOutset =
      math.min(
        slotWidth * staticHeroTrickPairHorizontalOutsetFactor,
        _staticHeroTrickProfileOutsetMax * contentScale,
      ) +
      _staticHeroProfileCardGapIncrease * contentScale -
      slotWidth * _staticHeroTrickCardInwardShiftFactor;
  final rowOffset = _trickRow(seatPosition) * slotHeight;
  final cardTranslateY =
      (isTopRow ? -1 : 1) *
          slotHeight *
          staticHeroTrickCardVerticalOutsetFactor -
      _trickClusterVerticalShift(contentScale);
  final cardTop =
      rowOffset +
      slotHeight / 2 +
      staticHeroTrickCardScale *
          (_staticHeroTrickCardTopPadding * contentScale - slotHeight / 2) +
      cardTranslateY;
  final cardBottom =
      rowOffset +
      slotHeight / 2 +
      staticHeroTrickCardScale *
          (slotHeight -
              _staticHeroTrickCardBottomPadding * contentScale -
              slotHeight / 2) +
      cardTranslateY;
  return Rect.fromLTWH(
    _trickColumn(seatPosition) * slotWidth +
        (isLeftColumn
            ? slotWidth * 0.515 -
                  profileWidth -
                  _trickProfileCenterInset * contentScale -
                  profileOutset
            : slotWidth * 0.485 +
                  _trickProfileCenterInset * contentScale +
                  profileOutset),
    isTopRow ? cardBottom - profileHeight : cardTop,
    profileWidth,
    profileHeight,
  );
}

String _trickProfileName(Seat seat) {
  return RegExp(r'^bot \d+$', caseSensitive: false).hasMatch(seat.name.trim())
      ? botNameForPlayerID(seat.id)
      : seat.name;
}

int _trickProfileCellarCount(Seat seat) {
  return seat.plot.effectiveHiddenCardCount +
      seat.plot.stacks.fold<int>(
        0,
        (total, stack) => total + stack.effectiveHiddenCardCount,
      );
}

double _sharedTrickProfileWidth(
  List<Seat> seats, {
  required int maxTricks,
  required TextScaler textScaler,
}) {
  const nameStyle = TextStyle(
    fontFamily: fieldPlanDisplayFontFamily,
    fontSize: 20.5,
    height: 1,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );
  const statStyle = TextStyle(
    fontFamily: fieldPlanBodyFontFamily,
    fontSize: 17,
    height: 1,
    fontWeight: FontWeight.w700,
  );
  const portraitWidth = 68.0;
  const portraitGap = 6.0;
  const medalGap = 5.0;
  const medalIconSize = 24.0;
  const medalAdvance = 17.0;
  const statIconAndGap = 25.0;
  const statGap = 8.0;
  const panelInsets = 8.0;
  final medalWidth = medalIconSize + math.max(0, maxTricks - 1) * medalAdvance;
  var widestContent = 0.0;
  for (final seat in seats) {
    final nameWidth = _profileTextWidth(
      _trickProfileName(seat).toUpperCase(),
      nameStyle,
      textScaler,
    );
    final topRowWidth = nameWidth + medalGap + medalWidth;
    final plotWidth =
        statIconAndGap +
        _profileTextWidth('${seat.visibleScore}', statStyle, textScaler);
    final cellarWidth =
        statIconAndGap +
        _profileTextWidth(
          '${_trickProfileCellarCount(seat)}',
          statStyle,
          textScaler,
        );
    final bottomRowWidth = plotWidth + statGap + cellarWidth;
    widestContent = math.max(
      widestContent,
      math.max(topRowWidth, bottomRowWidth),
    );
  }
  return portraitWidth + portraitGap + widestContent + panelInsets;
}

double _profileTextWidth(String text, TextStyle style, TextScaler textScaler) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();
  return painter.width;
}

class _BrigadePlotZone extends StatelessWidget {
  const _BrigadePlotZone({
    required this.seat,
    required this.rect,
    required this.isLeftColumn,
    required this.isTopRow,
    required this.contentScale,
    required this.model,
    required this.tokens,
    required this.inspecting,
    this.onPlotCardTap,
  });

  final Seat seat;
  final Rect rect;
  final bool isLeftColumn;
  final bool isTopRow;
  final double contentScale;
  final TableViewModel model;
  final DesignTokens tokens;
  final bool inspecting;
  final void Function(String cardID, String zone)? onPlotCardTap;

  @override
  Widget build(BuildContext context) {
    final hiddenExiledCardIDs = hiddenExiledPlotCardIDs(model);
    final revealedEntries = <_PosterCardEntry>[
      for (final card in visiblePlotCards(
        seat.plot.revealed,
        hiddenExiledCardIDs,
      ))
        _PosterCardEntry(
          card: selectedPlotCard(card, model.selection.plotCardID),
          onTap: _plotTap(card, plotZoneRevealed),
        ),
      for (final stack in visiblePlotStacks(
        seat.plot.stacks,
        hiddenExiledCardIDs,
      ))
        for (final card in stack.revealed)
          _PosterCardEntry(
            card: selectedPlotCard(card, model.selection.plotCardID),
          ),
    ];
    final visibleCellarCards = [
      for (final card in visiblePlotCards(
        seat.plot.hidden,
        hiddenExiledCardIDs,
      ))
        card,
      for (final stack in visiblePlotStacks(
        seat.plot.stacks,
        hiddenExiledCardIDs,
      ))
        ...stack.hidden,
    ];
    final cellarCardCount = _trickProfileCellarCount(seat);
    final cellarEntries = <_PosterCardEntry>[
      for (final card in visibleCellarCards)
        _PosterCardEntry(
          card: selectedPlotCard(card, model.selection.plotCardID),
          hidden: true,
          revealable: seat.isViewer,
          forceReveal:
              seat.isViewer &&
              (model.table.phase == phasePlanning ||
                  model.table.phase == phaseRequisition ||
                  (model.table.phase == phaseSwap &&
                      model.table.currentPlayerID == seat.id)),
          onTap: _plotTap(card, plotZoneHidden),
        ),
      for (
        var index = visibleCellarCards.length;
        index < cellarCardCount;
        index += 1
      )
        _PosterCardEntry.redacted(id: 'seat-${seat.id}-cellar-$index'),
    ];
    final entries = isLeftColumn
        ? [...revealedEntries.reversed, ...cellarEntries]
        : [...cellarEntries, ...revealedEntries];
    return Positioned.fromRect(
      rect: rect,
      child: MotionTrackedRegion(
        key: Key('static-hero-plot-zone-${seat.id}'),
        motionKey: plotCardMotionSourceKey(seat.id),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(_staticHeroPlotPadding * contentScale),
                child: _PosterCardFan(
                  cards: entries,
                  tokens: tokens,
                  trump: model.table.trump,
                  maxPerRow: entries.length,
                  growToAvailableWidth: true,
                  maxScale: double.infinity,
                  reversePaintOrder: isLeftColumn,
                  alignment: Alignment(
                    isLeftColumn ? 1 : -1,
                    isTopRow ? 1 : -1,
                  ),
                ),
              ),
            ),
            if (inspecting)
              Positioned.fill(child: _PosterPlayerInfo(seat: seat)),
          ],
        ),
      ),
    );
  }

  VoidCallback? _plotTap(TableCard card, String zone) {
    if (!seat.isViewer || (!card.highlighted && !card.selected)) {
      return null;
    }
    final handler = onPlotCardTap;
    return handler == null ? null : () => handler(card.id, zone);
  }
}

class _FieldsPosterContent extends StatelessWidget {
  const _FieldsPosterContent({
    required this.model,
    required this.tokens,
    this.onAction,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final ValueChanged<LegalAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final jobs = jobsInDisplayOrder(model.table.jobs);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final contentScale = _posterContentScale(size.height);
        return Stack(
          children: [
            for (final job in jobs)
              _JobPosterZone(
                job: job,
                model: model,
                tokens: tokens,
                contentScale: contentScale,
                rect: Rect.fromLTWH(
                  size.width * staticHeroJobRects[job.suit]!.left,
                  size.height * staticHeroJobRects[job.suit]!.top,
                  size.width * staticHeroJobRects[job.suit]!.width,
                  size.height * staticHeroJobRects[job.suit]!.height,
                ),
                onAction: onAction,
              ),
          ],
        );
      },
    );
  }
}

class _JobPosterZone extends StatelessWidget {
  const _JobPosterZone({
    required this.job,
    required this.model,
    required this.tokens,
    required this.contentScale,
    required this.rect,
    this.onAction,
  });

  final Job job;
  final TableViewModel model;
  final DesignTokens tokens;
  final double contentScale;
  final Rect rect;
  final ValueChanged<LegalAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final action = assignmentActionForJob(model, job);
    final handler = action == null || onAction == null
        ? null
        : () => onAction!(action);
    final hours = displayedJobHours(job);
    final normalizedRect = staticHeroJobRects[job.suit]!;
    final isLeftColumn = normalizedRect.center.dx < 0.5;
    final isTopRow = normalizedRect.center.dy < 0.5;
    final markerHorizontalInset = 8 * contentScale;
    final markerVerticalInset = (isTopRow ? 18 : 0) * contentScale;
    final counterScale = contentScale * 1.5;
    final counterText = '$hours/${job.requiredHours}';
    final counterWidth = _fieldJobCounterBaseWidth * counterScale;
    final counterHeight = _fieldJobCounterBaseHeight * counterScale;
    final rewardWidth = _fieldJobRewardBaseWidth * counterScale;
    final assignmentMarkerClearance =
        counterWidth + markerHorizontalInset + 10 * contentScale;
    return Positioned.fromRect(
      rect: rect,
      child: Semantics(
        key: Key('static-hero-job-${job.suit}'),
        button: handler != null,
        label: '${job.suit}, $hours of ${job.requiredHours} hours',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: handler,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: isLeftColumn ? 0 : assignmentMarkerClearance,
                right: isLeftColumn ? assignmentMarkerClearance : 0,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  key: Key('static-hero-job-assignment-${job.suit}'),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: handler == null
                          ? Colors.transparent
                          : const Color(0xffffdc65),
                      width: handler == null ? 0 : 3 * contentScale,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(8 * contentScale),
                    child: _PosterCardFan(
                      cards: [
                        for (final card in job.assignedCards)
                          _PosterCardEntry(card: card),
                      ],
                      tokens: tokens,
                      trump: model.table.trump,
                      maxPerRow: 6,
                      maxScale: double.infinity,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: isLeftColumn ? null : markerHorizontalInset,
                right: isLeftColumn ? markerHorizontalInset : null,
                top: isTopRow ? null : markerVerticalInset,
                bottom: isTopRow ? markerVerticalInset : null,
                child: _FieldJobMarker(
                  suit: job.suit,
                  reward: job.reward,
                  rewardAbove: isTopRow,
                  gap: 6 * contentScale,
                  tokens: tokens,
                  trump: model.table.trump,
                  counterWidth: counterWidth,
                  counterHeight: counterHeight,
                  rewardWidth: rewardWidth,
                  counter: _PosterPlacard(
                    key: Key('static-hero-job-counter-${job.suit}'),
                    text: counterText,
                    iconAsset: fieldPlanGameCropIconPath(job.suit),
                    active: handler != null,
                    complete: hours >= job.requiredHours,
                    scale: counterScale,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldJobMarker extends StatelessWidget {
  const _FieldJobMarker({
    required this.suit,
    required this.reward,
    required this.rewardAbove,
    required this.gap,
    required this.tokens,
    required this.trump,
    required this.counterWidth,
    required this.counterHeight,
    required this.rewardWidth,
    required this.counter,
  });

  final String suit;
  final TableCard? reward;
  final bool rewardAbove;
  final double gap;
  final DesignTokens tokens;
  final String? trump;
  final double counterWidth;
  final double counterHeight;
  final double rewardWidth;
  final Widget counter;

  @override
  Widget build(BuildContext context) {
    final rewardCard = reward == null
        ? null
        : SizedBox(
            key: Key('static-hero-job-reward-$suit'),
            width: rewardWidth,
            height:
                rewardWidth *
                tokens.card.small.height /
                tokens.card.small.width,
            child: _SinglePosterCard(
              card: reward!,
              tokens: tokens,
              trump: trump,
            ),
          );
    return SizedBox(
      key: Key('static-hero-job-marker-$suit'),
      width: counterWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rewardAbove && rewardCard != null) rewardCard,
          if (rewardAbove && rewardCard != null) SizedBox(height: gap),
          SizedBox(width: counterWidth, height: counterHeight, child: counter),
          if (!rewardAbove && rewardCard != null) SizedBox(height: gap),
          if (!rewardAbove && rewardCard != null) rewardCard,
        ],
      ),
    );
  }
}

class _NorthPosterContent extends StatelessWidget {
  const _NorthPosterContent({required this.model, required this.tokens});

  final TableViewModel model;
  final DesignTokens tokens;

  static const roofY = [0.205, 0.335, 0.44, 0.585, 0.755];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Stack(
          children: [
            for (var year = 1; year <= finalGameYear; year++)
              _NorthYearPosterRow(
                year: year,
                cards: model.table.exiledByYear[year] ?? const [],
                centerY: roofY[year - 1],
                completed:
                    year < model.table.year ||
                    model.table.phase == phaseGameOver ||
                    (year == model.table.year &&
                        model.table.phase == phaseRequisition),
                tokens: tokens,
                size: size,
              ),
          ],
        );
      },
    );
  }
}

class _NorthYearPosterRow extends StatelessWidget {
  const _NorthYearPosterRow({
    required this.year,
    required this.cards,
    required this.centerY,
    required this.completed,
    required this.tokens,
    required this.size,
  });

  final int year;
  final List<TableCard> cards;
  final double centerY;
  final bool completed;
  final DesignTokens tokens;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final height = size.height * 0.13;
    return Positioned(
      key: Key('static-hero-north-year-$year'),
      left: size.width * 0.17,
      top: size.height * centerY - height / 2,
      width: size.width * 0.66,
      height: height,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 4,
            child: _PosterPlacard(text: 'YEAR $year'),
          ),
          Positioned(
            left: size.width * 0.20,
            right: 0,
            top: 0,
            bottom: 0,
            child: cards.isEmpty && completed
                ? const _EmptyYearStamp()
                : _PosterCardFan(
                    cards: [
                      for (final card in cards) _PosterCardEntry(card: card),
                    ],
                    tokens: tokens,
                    maxPerRow: 8,
                  ),
          ),
        ],
      ),
    );
  }
}

class _PosterPlayerInfo extends StatelessWidget {
  const _PosterPlayerInfo({required this.seat});

  final Seat seat;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('player-info-panel-${seat.id}'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xff20231f).withValues(alpha: 0.94),
        border: Border.all(color: const Color(0xffefe0b7), width: 2),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              seat.name.toUpperCase(),
              style: const TextStyle(
                fontFamily: fieldPlanDisplayFontFamily,
                color: Color(0xffffdc65),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'PLAYER  ·  SCORE ${seat.visibleScore}  ·  HAND ${seat.hand.length + seat.hiddenHandCount}',
              style: const TextStyle(
                fontFamily: fieldPlanDisplayFontFamily,
                color: Color(0xffffecc2),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PosterCardFan extends StatelessWidget {
  const _PosterCardFan({
    required this.cards,
    required this.tokens,
    required this.maxPerRow,
    this.trump,
    this.growToAvailableWidth = false,
    this.maxScale = 1.55,
    this.reversePaintOrder = false,
    this.alignment = Alignment.center,
  });

  final List<_PosterCardEntry> cards;
  final DesignTokens tokens;
  final int maxPerRow;
  final String? trump;
  final bool growToAvailableWidth;
  final double maxScale;
  final bool reversePaintOrder;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.expand();
    return LayoutBuilder(
      builder: (context, constraints) {
        final base = tokens.card.small;
        final availablePerRow = growToAvailableWidth
            ? _posterFanCardsThatFitOneRow(
                constraints: constraints,
                base: base,
                maxScale: maxScale,
              )
            : maxPerRow;
        final perRow = math.min(
          cards.length,
          math.min(maxPerRow, availablePerRow),
        );
        final rows = (cards.length / perRow).ceil();
        final widthUnits = 1 + math.max(0, perRow - 1) * 0.58;
        final heightUnits = 1 + math.max(0, rows - 1) * 0.44;
        final scale = math.min(
          maxScale,
          math.min(
            constraints.maxWidth / (base.width * widthUnits),
            constraints.maxHeight / (base.height * heightUnits),
          ),
        );
        final cardSize = _scaledCardSize(base, math.max(0.36, scale));
        final strideX = cardSize.width * 0.58;
        final strideY = cardSize.height * 0.44;
        final contentHeight = cardSize.height + (rows - 1) * strideY;
        final indexedCards = cards.indexed.toList();
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final (index, entry)
                in reversePaintOrder ? indexedCards.reversed : indexedCards)
              Builder(
                key: ValueKey('poster-fan-layer-${entry.id}'),
                builder: (context) {
                  final row = index ~/ perRow;
                  final column = index % perRow;
                  final rowCount = math.min(
                    perRow,
                    cards.length - row * perRow,
                  );
                  final rowWidth = cardSize.width + (rowCount - 1) * strideX;
                  final availableWidth = constraints.maxWidth - rowWidth;
                  return Positioned(
                    left:
                        availableWidth * ((alignment.x + 1) / 2) +
                        column * strideX,
                    top:
                        (constraints.maxHeight - contentHeight) *
                            ((alignment.y + 1) / 2) +
                        row * strideY,
                    width: cardSize.width,
                    height: cardSize.height,
                    child: entry.card == null
                        ? SizedBox.expand(
                            key: ValueKey('poster-fan-paint-${entry.id}'),
                            child: ScaledCardBack(
                              tokens: tokens,
                              size: cardSize,
                            ),
                          )
                        : _PosterFanCard(
                            entry: entry,
                            cardSize: cardSize,
                            tokens: tokens,
                            trump: trump,
                          ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _PosterFanCard extends StatelessWidget {
  const _PosterFanCard({
    required this.entry,
    required this.cardSize,
    required this.tokens,
    required this.trump,
  });

  final _PosterCardEntry entry;
  final TokenCardSize cardSize;
  final DesignTokens tokens;
  final String? trump;

  @override
  Widget build(BuildContext context) {
    final card = entry.card!;
    return SizedBox.expand(
      key: ValueKey('poster-fan-paint-${entry.id}'),
      child: SwapSelectedCardFrame(
        cardID: card.id,
        selected: card.selected,
        tokens: tokens,
        child: MotionTrackedCard(
          card: card,
          compositeWhenVisible: false,
          child: PendingAssignmentCardPulse(
            cardID: card.id,
            active: card.pending,
            tokens: tokens,
            child: entry.hidden && entry.revealable
                ? InteractiveCardFlip(
                    key: Key('static-hero-card-${card.id}'),
                    concealedLabel: 'Cellar card. Tap to reveal.',
                    revealedLabel:
                        '${card.rank} of ${card.suit}. Tap to conceal.',
                    frontKey: ValueKey('cellar-face-${card.id}'),
                    backKey: ValueKey('cellar-back-${card.id}'),
                    forceShowFront: entry.forceReveal,
                    onTap: entry.onTap,
                    front: GameCard(
                      card: card,
                      tokens: tokens,
                      trump: trump,
                      sizeOverride: cardSize,
                      motionTracked: false,
                    ),
                    back: ScaledHighlightableCardBack(
                      card: card,
                      tokens: tokens,
                      size: cardSize,
                    ),
                  )
                : GestureDetector(
                    key: Key('static-hero-card-${card.id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: entry.onTap,
                    child: entry.hidden
                        ? ScaledHighlightableCardBack(
                            card: card,
                            tokens: tokens,
                            size: cardSize,
                          )
                        : GameCard(
                            card: card,
                            tokens: tokens,
                            trump: trump,
                            sizeOverride: cardSize,
                            motionTracked: false,
                          ),
                  ),
          ),
        ),
      ),
    );
  }
}

int _posterFanCardsThatFitOneRow({
  required BoxConstraints constraints,
  required TokenCardSize base,
  required double maxScale,
}) {
  final scale = math.min(maxScale, constraints.maxHeight / base.height);
  if (!scale.isFinite || scale <= 0) {
    return 1;
  }
  final widthUnits = constraints.maxWidth / (base.width * scale);
  return math.max(1, 1 + ((widthUnits - 1) / 0.58).floor());
}

class _SinglePosterCard extends StatelessWidget {
  const _SinglePosterCard({
    required this.card,
    required this.tokens,
    this.trump,
    this.winningTrick = false,
  });

  final TableCard card;
  final DesignTokens tokens;
  final String? trump;
  final bool winningTrick;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final base = tokens.card.small;
        final scale = math.min(
          constraints.maxWidth / base.width,
          constraints.maxHeight / base.height,
        );
        final targetSize = _scaledCardSize(base, scale);
        final renderSize = tokens.card.large;
        final renderScale = targetSize.width / renderSize.width;
        return Center(
          child: MotionTrackedCard(
            card: card,
            compositeWhenVisible: false,
            child: SizedBox(
              width: targetSize.width,
              height: targetSize.height,
              child: OverflowBox(
                minWidth: renderSize.width,
                maxWidth: renderSize.width,
                minHeight: renderSize.height,
                maxHeight: renderSize.height,
                child: Transform.scale(
                  scale: renderScale,
                  filterQuality: FilterQuality.high,
                  child: RepaintBoundary(
                    child: GameCard(
                      card: card,
                      tokens: tokens,
                      trump: trump,
                      sizeOverride: renderSize,
                      motionTracked: false,
                      winningTrick: winningTrick,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrickPlayerProfile extends StatelessWidget {
  const _TrickPlayerProfile({
    required this.seat,
    required this.tokens,
    required this.maxTricks,
    required this.winning,
    required this.portraitOnRight,
    required this.heroWithinReach,
  });

  final Seat seat;
  final DesignTokens tokens;
  final int maxTricks;
  final bool winning;
  final bool portraitOnRight;
  final bool heroWithinReach;

  @override
  Widget build(BuildContext context) {
    final seatName = _trickProfileName(seat);
    final cellarCount = _trickProfileCellarCount(seat);
    return Container(
      key: winning ? const ValueKey('winning-trick-player-frame') : null,
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: const Color(0xffefe0b7),
        border: Border.all(
          color: winning ? tokens.colors.redBright : const Color(0xff20231f),
          width: winning ? 3 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x5521251f), offset: Offset(2, 2)),
        ],
      ),
      child: Row(
        textDirection: portraitOnRight ? TextDirection.rtl : TextDirection.ltr,
        children: [
          SizedBox(
            key: Key('player-profile-portrait-${seat.id}'),
            width: 68,
            height: 68,
            child: PlayerPortrait(
              seat: seat,
              tokens: tokens,
              width: 68,
              height: 68,
              badgeVisible: false,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  textDirection: portraitOnRight
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  children: [
                    Text(
                      seatName.toUpperCase(),
                      maxLines: 1,
                      textAlign: portraitOnRight
                          ? TextAlign.right
                          : TextAlign.left,
                      style: const TextStyle(
                        fontFamily: fieldPlanDisplayFontFamily,
                        color: Color(0xff20231f),
                        fontSize: 20.5,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 5),
                    _ProfileMedals(
                      key: Key('player-profile-medals-${seat.id}'),
                      seatID: seat.id,
                      medals: seat.medals,
                      maxTricks: maxTricks,
                      fillFromRight: portraitOnRight,
                      heroWithinReach: heroWithinReach,
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  textDirection: portraitOnRight
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  children: [
                    _ProfileStat(
                      key: Key('player-profile-plot-${seat.id}'),
                      asset: fieldPlanPlotIconPath,
                      value: '${seat.visibleScore}',
                    ),
                    const SizedBox(width: 8),
                    _ProfileStat(
                      key: Key('player-profile-cellar-${seat.id}'),
                      asset: fieldPlanCellarIconPath,
                      value: '$cellarCount',
                    ),
                    const Spacer(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMedals extends StatelessWidget {
  const _ProfileMedals({
    required this.seatID,
    required this.medals,
    required this.maxTricks,
    required this.fillFromRight,
    required this.heroWithinReach,
    super.key,
  });

  final int seatID;
  final int medals;
  final int maxTricks;
  final bool fillFromRight;
  final bool heroWithinReach;

  @override
  Widget build(BuildContext context) {
    const iconSize = 24.0;
    const iconAdvance = 17.0;
    final width = iconSize + math.max(0, maxTricks - 1) * iconAdvance;
    final medalStrip = SizedBox(
      width: width,
      height: iconSize,
      child: Stack(
        children: [
          for (var index = 0; index < maxTricks; index++)
            Positioned(
              left: fillFromRight
                  ? width - iconSize - index * iconAdvance
                  : index * iconAdvance,
              top: 0,
              child: KeyedSubtree(
                key: Key('player-profile-medal-$seatID-$index'),
                child: AnimatedSwitcher(
                  duration: GameMotion.of(context).medalAppear,
                  switchInCurve: GameMotion.medalInCurve,
                  switchOutCurve: GameMotion.medalOutCurve,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: SizedBox(
                    key: ValueKey(
                      '${index < medals ? 'earned' : 'empty'}-medal-'
                      '$seatID-$index',
                    ),
                    width: iconSize,
                    height: iconSize,
                    child: index < medals
                        ? Image.asset(
                            fieldPlanMedalIconPath,
                            filterQuality: FilterQuality.high,
                            isAntiAlias: true,
                          )
                        : Opacity(
                            opacity: 0.18,
                            child: ChromeAssetIcon(
                              asset: fieldPlanMedalIconPath,
                              width: iconSize,
                              height: iconSize,
                              muted: true,
                            ),
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return HeroMedalPulse(active: heroWithinReach, child: medalStrip);
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.asset, required this.value, super.key});

  final String asset;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          asset,
          width: 23,
          height: 23,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
        ),
        const SizedBox(width: 2),
        Text(
          value,
          style: const TextStyle(
            fontFamily: fieldPlanBodyFontFamily,
            color: Color(0xff20231f),
            fontSize: 17,
            height: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PosterPlacard extends StatelessWidget {
  const _PosterPlacard({
    required this.text,
    this.iconAsset,
    this.active = false,
    this.complete = false,
    this.scale = 1,
    super.key,
  });

  final String text;
  final String? iconAsset;
  final bool active;
  final bool complete;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? const Color(0xffb52b1d)
            : complete
            ? const Color(0xff52633f)
            : const Color(0xffefe0b7),
        border: Border.all(color: const Color(0xff20231f), width: 0.8 * scale),
        boxShadow: [
          BoxShadow(
            color: const Color(0x5521251f),
            offset: Offset(2 * scale, 2 * scale),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 7 * scale,
          vertical: (iconAsset == null ? 3 : 2) * scale,
        ),
        child: iconAsset == null
            ? _placardText(text)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    iconAsset!,
                    width: 13 * scale,
                    height: 13 * scale,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                  ),
                  SizedBox(width: 3 * scale),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _placardText(text),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _placardText(String text) {
    final label = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _posterPlacardTextStyle(
        scale,
        active || complete ? const Color(0xffffecc2) : const Color(0xff20231f),
      ),
    );
    return label;
  }
}

TextStyle _posterPlacardTextStyle(double scale, Color color) => TextStyle(
  fontFamily: fieldPlanDisplayFontFamily,
  color: color,
  fontSize: 10 * scale,
  height: 1,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.7 * scale,
);

class _EmptyYearStamp extends StatelessWidget {
  const _EmptyYearStamp();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.rotate(
        angle: -0.04,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xffefe0b7),
            border: Border.all(color: const Color(0xffb52b1d), width: 3),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(
              'CLEAR',
              style: TextStyle(
                fontFamily: fieldPlanDisplayFontFamily,
                color: Color(0xffb52b1d),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PosterCardEntry {
  const _PosterCardEntry({
    required this.card,
    this.hidden = false,
    this.revealable = false,
    this.forceReveal = false,
    this.onTap,
  }) : redactedID = null;

  const _PosterCardEntry.redacted({required String id})
    : card = null,
      hidden = true,
      revealable = false,
      forceReveal = false,
      onTap = null,
      redactedID = id;

  final TableCard? card;
  final bool hidden;
  final bool revealable;
  final bool forceReveal;
  final VoidCallback? onTap;
  final String? redactedID;

  String get id => card?.id ?? redactedID!;
}

TokenCardSize _scaledCardSize(TokenCardSize source, double scale) =>
    TokenCardSize(
      width: source.width * scale,
      height: source.height * scale,
      faceInset: source.faceInset * scale,
      cornerWidth: source.cornerWidth * scale,
      cornerHeight: source.cornerHeight * scale,
      cornerRankFontSize: source.cornerRankFontSize * scale,
      cornerSuitSize: source.cornerSuitSize * scale,
      topCornerRankSuitSpacing: source.topCornerRankSuitSpacing * scale,
      bottomCornerRankSuitSpacing: source.bottomCornerRankSuitSpacing * scale,
      topCornerSuitXOffset: source.topCornerSuitXOffset * scale,
      bottomCornerSuitXOffset: source.bottomCornerSuitXOffset * scale,
      pipSize: source.pipSize * scale,
    );
