import 'dart:math' as math;
import 'dart:ui' show clampDouble;

import 'package:flutter/material.dart';

import 'package:kolkhoz_app/src/app/settings/game_motion.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/shared/app_text.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/assignment_projection.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/display/card_display.dart';
import 'package:kolkhoz_app/src/app/views/shared/chrome_button.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_assets.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/shared/display_text.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/display/table_display.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/board_widgets.dart';

const lowerBarActionKinds = {
  actionSwap,
  actionConfirmSwap,
  actionUndoSwap,
  actionSubmitAssignments,
  actionContinueAfterRequisition,
};

bool isProminentLowerBarAction(LegalAction action) {
  return action.kind == actionConfirmSwap ||
      action.kind == actionSubmitAssignments ||
      action.kind == actionContinueAfterRequisition;
}

int compareLowerBarActions(LegalAction lhs, LegalAction rhs) {
  final lhsRank = lowerBarActionRank(lhs.kind);
  final rhsRank = lowerBarActionRank(rhs.kind);
  if (lhsRank != rhsRank) {
    return lhsRank.compareTo(rhsRank);
  }
  final kindOrder = lhs.kind.compareTo(rhs.kind);
  if (kindOrder != 0) {
    return kindOrder;
  }
  return lowerBarActionSortKey(
    lhs.engineAction,
  ).compareTo(lowerBarActionSortKey(rhs.engineAction));
}

String lowerBarActionSortKey(EngineAction action) {
  return [
    action.kind,
    action.playerID.toString(),
    action.suit ?? '',
    action.card?.id ?? '',
    action.handCard?.id ?? '',
    action.plotCard?.id ?? '',
    action.plotZone ?? '',
    action.targetSuit ?? '',
  ].join('|');
}

int lowerBarActionRank(String kind) {
  return switch (kind) {
    actionSwap => 0,
    actionUndoSwap => 0,
    actionConfirmSwap => 1,
    actionSubmitAssignments => 1,
    actionContinueAfterRequisition => 1,
    _ => 2,
  };
}

String lowerBarActionLabel(
  LegalAction action, {
  required int tableYear,
  KolkhozLanguage? language,
}) {
  final resolvedLanguage = language ?? KolkhozLanguage.en;
  return switch (action.kind) {
    actionSwap => resolvedLanguage.strings.lowerbaractionsSwap,
    actionUndoSwap => resolvedLanguage.strings.lowerbaractionsUndo,
    actionConfirmSwap => resolvedLanguage.strings.lowerbaractionsConfirm,
    actionSubmitAssignments => resolvedLanguage.strings.lowerbaractionsConfirm,
    actionContinueAfterRequisition =>
      tableYear >= finalGameYear
          ? resolvedLanguage.strings.lowerbaractionsFinish
          : resolvedLanguage.strings.lowerbaractionsYearValue1(
              value1: tableYear + 1,
            ),
    _ => action.label,
  };
}

String lowerBarActionIconAsset(LegalAction action) {
  return switch (action.kind) {
    actionSwap => fieldPlanToolbarSwapIconPath,
    actionUndoSwap => fieldPlanToolbarUndoIconPath,
    actionConfirmSwap ||
    actionSubmitAssignments ||
    actionContinueAfterRequisition => fieldPlanToolbarConfirmIconPath,
    _ => fieldPlanToolbarConfirmIconPath,
  };
}

const handTrayOuterSpacing = 8.0;
const handTrayZoneHorizontalPadding = 6.0;
const handTrayCardSpacing = 10.0;
const handTrayCardYOffset = 8.0;
const handTrayCardMinimumExposedFraction = 0.42;
const handTrayCardMinimumExposedWidth = 28.0;
const handTrayCardSelectedLiftFraction = 0.07;
const handTrayNeighborSeparation = 7.0;
const handTrayDealStagger = Duration(milliseconds: 28);
const handTrayAssignmentDividerWidth = 2.0;
const handTrayAssignmentDividerSpacing = 10.0;
const handTrayAssignmentDividerTopMargin = 5.0;
const handTrayAssignmentCardOverlapFraction = 0.38;
const handTrayAssignmentBaselineCorrection = 1.0;
const handTrayActionButtonSize = 42.0;
const handTrayActionIconSize = 28.0;
const handTrayActionSpacing = 8.0;
const handTrayActionBarPadding = 6.0;
const handConsoleWidth = 106.0;
const handConsoleStatusHeight = 34.0;
const handConsoleCompactStatusHeight = 18.0;
const handConsoleRowSpacing = 4.0;
const handConsoleCompactHeightBreakpoint = 94.0;
const handConsoleMinimumButtonScale = 0.6;
const handTraySwapHighlightStrokeWidth = 2.0;
const handTraySwapHighlightCornerRadius = 7.0;
const handTrayCardHeightFillFactor = 1.0;
const handTrayCardMaxScale = 3.0;

bool passIconFlipsHorizontally(int year) => year.isEven;

bool handCardCanReceiveTap(TableViewModel model, TableCard card) {
  return switch (model.table.phase) {
    phasePlanning || phaseTrick || phaseSwap || phasePass => card.highlighted,
    _ => false,
  };
}

bool handCardCanShowInvalidHint(TableViewModel model, TableCard card) {
  return model.table.phase == phaseTrick &&
      model.table.currentPlayerID == localSeat(model).id &&
      !card.highlighted;
}

LegalAction? handCardPlayAction(TableViewModel model, TableCard card) {
  if (model.table.phase != phaseTrick) {
    return null;
  }
  for (final action in model.legalActions) {
    if (action.kind == actionPlayCard &&
        action.engineAction.card?.id == card.id) {
      return action;
    }
  }
  return null;
}

LegalAction? handCardPassAction(TableViewModel model, TableCard card) {
  if (model.table.phase != phasePass) return null;
  for (final action in model.legalActions) {
    if (action.kind == actionPassCard &&
        action.engineAction.card?.id == card.id) {
      return action;
    }
  }
  return null;
}

LegalAction? handCardRewardAction(TableViewModel model, TableCard card) {
  if (model.table.phase != phasePlanning) return null;
  for (final action in model.legalActions) {
    if (action.kind == actionAssignReward &&
        action.engineAction.card?.id == card.id) {
      return action;
    }
  }
  return null;
}

LegalAction? selectedHandCardPlayAction(TableViewModel model) {
  final selectedCardID = model.selection.handCardID;
  if (model.table.phase != phaseTrick || selectedCardID == null) {
    return null;
  }
  for (final action in model.legalActions) {
    if (action.kind == actionPlayCard &&
        action.engineAction.card?.id == selectedCardID) {
      return action;
    }
  }
  return null;
}

LegalAction? selectedHandCardPassAction(TableViewModel model) {
  final selectedCardID = model.selection.handCardID;
  if (model.table.phase != phasePass || selectedCardID == null) {
    return null;
  }
  for (final action in model.legalActions) {
    if (action.kind == actionPassCard &&
        action.engineAction.card?.id == selectedCardID) {
      return action;
    }
  }
  return null;
}

LegalAction? selectedHandCardRewardAction(TableViewModel model) {
  final selectedCardID = model.selection.handCardID;
  if (model.table.phase != phasePlanning || selectedCardID == null) {
    return null;
  }
  for (final action in model.legalActions) {
    if (action.kind == actionAssignReward &&
        action.engineAction.card?.id == selectedCardID) {
      return action;
    }
  }
  return null;
}

LegalAction? handConsoleLegalAction(TableViewModel model, Set<String> kinds) {
  for (final action in model.legalActions) {
    if (kinds.contains(action.kind)) {
      return action;
    }
  }
  return null;
}

LegalAction? handConsoleConfirmAction(TableViewModel model) {
  return switch (model.table.phase) {
    phasePlanning => selectedHandCardRewardAction(model),
    phaseTrick => selectedHandCardPlayAction(model),
    phaseSwap =>
      handConsoleLegalAction(model, {actionSwap}) == null
          ? handConsoleLegalAction(model, {actionConfirmSwap})
          : null,
    phasePass => selectedHandCardPassAction(model),
    phaseAssignment => handConsoleLegalAction(model, {actionSubmitAssignments}),
    phaseRequisition => handConsoleLegalAction(model, {
      actionContinueAfterRequisition,
    }),
    _ => null,
  };
}

LegalAction? handConsoleSecondaryAction(TableViewModel model) {
  if (model.table.phase != phaseSwap) {
    return null;
  }
  return handConsoleLegalAction(model, {actionUndoSwap}) ??
      handConsoleLegalAction(model, {actionSwap});
}

bool handConsoleSeatIsLocal(Seat? seat) {
  return seat != null && (seat.isViewer || isLocalHumanSeat(seat));
}

String handConsoleWaitingStatus(
  Seat? seat,
  KolkhozLanguage language, {
  required bool compact,
  required KolkhozText detailedKey,
}) {
  if (seat == null) {
    return language.strings.boardviewWait;
  }
  final name = seatDisplayName(seat, language: language);
  return language.t(
    compact ? KolkhozText.handConsoleWaitingForValue1 : detailedKey,
    {'value1': name},
  );
}

String handConsoleStatus(
  TableViewModel model,
  KolkhozLanguage language, {
  required bool compact,
}) {
  final currentSeat = seatByID(model, model.table.currentPlayerID);
  final english = language == KolkhozLanguage.en;
  return switch (model.table.phase) {
    phasePlanning => planningTrumpStatus(model, language),
    phasePass => () {
      final direction = model.table.year.isEven
          ? (english ? 'left' : 'влево')
          : (english ? 'right' : 'вправо');
      final canChoose = model.legalActions.any(
        (action) => action.kind == actionPassCard,
      );
      if (!canChoose) {
        return english
            ? 'Card locked · waiting for the others'
            : 'Карта выбрана · ждём остальных';
      }
      final revealed = model.table.finalYearTrumpCard;
      if (revealed != null && model.table.year == finalGameYear) {
        final result = revealed.suit == wreckerSuit
            ? (english ? 'no trump' : 'без козыря')
            : (english ? '${revealed.suit} trump' : 'козырь: ${revealed.suit}');
        return english
            ? 'Pass $direction · ${revealed.rank} revealed · $result'
            : 'Передайте $direction · открыта ${revealed.rank} · $result';
      }
      return english
          ? 'Choose one card to pass $direction'
          : 'Выберите карту для передачи $direction';
    }(),
    phaseSwap =>
      handConsoleSeatIsLocal(currentSeat)
          ? compact
                ? language.strings.boardviewYourTurn
                : language.strings.handConsoleChooseSwap
          : handConsoleWaitingStatus(
              currentSeat,
              language,
              compact: compact,
              detailedKey: KolkhozText.handConsoleWaitingForValue1ToSwap,
            ),
    phaseTrick =>
      handConsoleSeatIsLocal(currentSeat)
          ? compact
                ? language.strings.boardviewYourTurn
                : language.strings.handConsoleYourTurnToPlay
          : handConsoleWaitingStatus(
              currentSeat,
              language,
              compact: compact,
              detailedKey: KolkhozText.handConsoleWaitingForValue1ToPlay,
            ),
    phaseAssignment => () {
      final winnerID = model.table.lastTrick.winnerSeatID;
      final winner = winnerID == null ? null : seatByID(model, winnerID);
      return handConsoleSeatIsLocal(winner)
          ? language.strings.handConsoleAssignTrick
          : handConsoleWaitingStatus(
              winner,
              language,
              compact: compact,
              detailedKey: KolkhozText.handConsoleWaitingForValue1ToAssign,
            );
    }(),
    phaseRequisition => language.t(
      compact
          ? KolkhozText.phaseRequisition
          : KolkhozText.handConsoleReviewRequisition,
    ),
    _ => model.table.phasePrompt.title,
  };
}

double handConsoleButtonScale(double visibleTrayHeight) {
  if (visibleTrayHeight >= handConsoleCompactHeightBreakpoint) {
    return 1;
  }
  final availableButtonHeight =
      visibleTrayHeight -
      handConsoleCompactStatusHeight -
      handConsoleRowSpacing;
  return clampDouble(
    availableButtonHeight / handTrayActionButtonSize,
    handConsoleMinimumButtonScale,
    1,
  );
}

bool assignmentCommandBarVisible(TableViewModel model) {
  if (model.table.phase != phaseAssignment) {
    return false;
  }
  final winnerID = model.table.lastTrick.winnerSeatID;
  if (winnerID == null) {
    return false;
  }
  final winner = seatByID(model, winnerID);
  return winner != null && winner.isViewer && isHumanControlledSeat(winner);
}

bool handCardMatchesPlanningTrumpFocus(
  TableViewModel model,
  TableCard card,
  String? focusedSuit,
) {
  return model.table.phase == phasePlanning &&
      focusedSuit != null &&
      (card.suit == focusedSuit || card.suit == wreckerSuit);
}

TableCard handTrayCard(
  TableViewModel model,
  TableCard card, {
  String? planningTrumpFocusedSuit,
}) {
  final showHighlight = switch (model.table.phase) {
    phaseTrick || phaseSwap || phasePass => card.highlighted,
    phasePlanning =>
      card.highlighted ||
          handCardMatchesPlanningTrumpFocus(
            model,
            card,
            planningTrumpFocusedSuit,
          ),
    _ => false,
  };
  final selected = card.selected || card.id == model.selection.handCardID;
  if (showHighlight == card.highlighted && selected == card.selected) {
    return card;
  }
  return cardWithSelection(
    card,
    selected: selected,
    highlighted: showHighlight,
  );
}

Color? handTrayHighlightColor(
  TableViewModel model,
  TableCard card, {
  String? planningTrumpFocusedSuit,
  required Color swapHighlightColor,
  required Color playableHighlightColor,
}) {
  if (handCardMatchesPlanningTrumpFocus(
    model,
    card,
    planningTrumpFocusedSuit,
  )) {
    return playableHighlightColor;
  }
  if (model.table.phase == phasePlanning && card.highlighted) {
    return playableHighlightColor;
  }
  if (model.table.phase == phaseSwap && card.highlighted && !card.selected) {
    return swapHighlightColor;
  }
  if (model.table.phase == phaseTrick && card.highlighted) {
    return playableHighlightColor;
  }
  if (model.table.phase == phasePass && card.highlighted) {
    return playableHighlightColor;
  }
  return null;
}

double handTrayCardScale(double visibleTrayHeight, TokenCardSize cardSize) {
  return clampDouble(
    (visibleTrayHeight * handTrayCardHeightFillFactor - handTrayCardYOffset) /
        cardSize.height,
    1,
    handTrayCardMaxScale,
  );
}

TokenCardSize scaledHandTrayCardSize(
  TokenCardSize cardSize,
  double visibleTrayHeight,
) {
  final scale = handTrayCardScale(visibleTrayHeight, cardSize);
  return scaledHandTrayCardSizeForScale(cardSize, scale);
}

double handTrayCardStride(
  double availableWidth,
  double cardWidth,
  int cardCount,
) {
  if (cardCount <= 1) {
    return cardWidth;
  }
  final fullySpacedStride = cardWidth + handTrayCardSpacing;
  final fittedStride = (availableWidth - cardWidth) / (cardCount - 1);
  final minimumStride = math.max(
    handTrayCardMinimumExposedWidth,
    cardWidth * handTrayCardMinimumExposedFraction,
  );
  return clampDouble(fittedStride, minimumStride, fullySpacedStride);
}

double handTrayCardRailWidth(double cardWidth, double stride, int cardCount) {
  if (cardCount <= 0) {
    return 0;
  }
  return cardWidth + math.max(0, cardCount - 1) * stride;
}

double handTrayAssignmentCardStride(double cardWidth) {
  return cardWidth * (1 - handTrayAssignmentCardOverlapFraction);
}

double handTrayAssignmentRailWidth(double cardWidth, int cardCount) {
  if (cardCount <= 0) {
    return 0;
  }
  return cardWidth +
      math.max(0, cardCount - 1) * handTrayAssignmentCardStride(cardWidth);
}

double handTrayAssignmentBarWidth(double cardWidth, int cardCount) {
  return handTrayAssignmentDividerWidth +
      handTrayAssignmentDividerSpacing +
      handTrayAssignmentRailWidth(cardWidth, cardCount);
}

String handCardAccessibilityLabel(
  TableCard card,
  KolkhozLanguage language, {
  required bool playable,
  required bool selected,
  required bool unavailable,
}) {
  final suit = card.suit == wreckerSuit
      ? language == KolkhozLanguage.en
            ? 'Wrecker'
            : 'Вредитель'
      : language.suitName(card.suit);
  final state = selected
      ? language == KolkhozLanguage.en
            ? ', selected'
            : ', выбрана'
      : playable
      ? language == KolkhozLanguage.en
            ? ', playable'
            : ', можно сыграть'
      : unavailable
      ? language == KolkhozLanguage.en
            ? ', unavailable'
            : ', нельзя сыграть'
      : '';
  return language == KolkhozLanguage.en
      ? '${card.rank} of $suit$state'
      : '${card.rank} $suit$state';
}

TokenCardSize scaledHandTrayCardSizeForScale(
  TokenCardSize cardSize,
  double scale,
) {
  return TokenCardSize(
    width: cardSize.width * scale,
    height: cardSize.height * scale,
    faceInset: cardSize.faceInset * scale,
    cornerWidth: cardSize.cornerWidth * scale,
    cornerHeight: cardSize.cornerHeight * scale,
    cornerRankFontSize: cardSize.cornerRankFontSize * scale,
    cornerSuitSize: cardSize.cornerSuitSize * scale,
    topCornerRankSuitSpacing: cardSize.topCornerRankSuitSpacing * scale,
    bottomCornerRankSuitSpacing: cardSize.bottomCornerRankSuitSpacing * scale,
    topCornerSuitXOffset: cardSize.topCornerSuitXOffset * scale,
    bottomCornerSuitXOffset: cardSize.bottomCornerSuitXOffset * scale,
    pipSize: cardSize.pipSize * scale,
  );
}

class HandTray extends StatelessWidget {
  const HandTray({
    required this.model,
    required this.tokens,
    required this.language,
    required this.visibleTrayHeight,
    this.actionsEnabled = true,
    this.leadingInset = 0,
    this.onAction,
    this.onSwapHandCardTap,
    this.onSwapCardDrop,
    this.onHandCardTap,
    this.onAssignmentCardTap,
    this.onInvalidHandCardTap,
    this.onPanelSelected,
    this.canUndo = false,
    this.onUndo,
    this.planningTrumpFocusedSuit,
    this.confirmActionOverride,
    this.contentOverride,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final double visibleTrayHeight;
  final bool actionsEnabled;
  final double leadingInset;
  final ValueChanged<LegalAction>? onAction;
  final ValueChanged<String>? onSwapHandCardTap;
  final SwapCardDropCallback? onSwapCardDrop;
  final ValueChanged<String>? onHandCardTap;
  final ValueChanged<String>? onAssignmentCardTap;
  final VoidCallback? onInvalidHandCardTap;
  final ValueChanged<String>? onPanelSelected;
  final bool canUndo;
  final VoidCallback? onUndo;
  final String? planningTrumpFocusedSuit;
  final LegalAction? confirmActionOverride;
  final Widget? contentOverride;

  @override
  Widget build(BuildContext context) {
    final localPlayer = localSeat(model);
    final provisionallyPlayedCardID = model.table.phase == phaseTrick
        ? model.selection.handCardID
        : null;
    final trickSelectionLocked = provisionallyPlayedCardID != null;
    final hand =
        localPlayer.hand
            .where((card) => card.id != provisionallyPlayedCardID)
            .toList(growable: false)
          ..sort(compareCardsForHand);
    final assignmentCards = assignmentControlCards(model);
    final selectedPlayAction = selectedHandCardPlayAction(model);
    final consoleActionsEnabled = contentOverride == null && actionsEnabled;
    final showAssignmentCommandBar =
        contentOverride == null &&
        actionsEnabled &&
        assignmentCards.isNotEmpty &&
        assignmentCommandBarVisible(model);
    final confirmAction =
        confirmActionOverride ?? handConsoleConfirmAction(model);
    final primaryLabel = model.table.phase == phaseRequisition
        ? language.t(
            model.table.year >= finalGameYear
                ? KolkhozText.lowerbaractionsFinish
                : KolkhozText.handConsoleContinue,
          )
        : language.strings.lowerbaractionsConfirm;
    final primaryCommand = HandTrayCommand(
      label: primaryLabel,
      iconAsset: fieldPlanToolbarConfirmIconPath,
      prominent: true,
      onPressed:
          !consoleActionsEnabled || confirmAction == null || onAction == null
          ? null
          : () => onAction!(confirmAction),
    );
    final swapSecondaryAction = handConsoleSecondaryAction(model);
    final secondaryCommand = switch (model.table.phase) {
      phaseTrick => HandTrayCommand(
        label: language.strings.boardHandtrayUndo,
        iconAsset: fieldPlanToolbarUndoIconPath,
        prominent: false,
        onPressed:
            !consoleActionsEnabled ||
                selectedPlayAction == null ||
                onHandCardTap == null
            ? null
            : () => onHandCardTap!(model.selection.handCardID!),
      ),
      phaseSwap => HandTrayCommand(
        label: swapSecondaryAction == null
            ? language.strings.lowerbaractionsSwap
            : lowerBarActionLabel(
                swapSecondaryAction,
                tableYear: model.table.year,
                language: language,
              ),
        iconAsset: swapSecondaryAction == null
            ? fieldPlanToolbarSwapIconPath
            : lowerBarActionIconAsset(swapSecondaryAction),
        prominent: false,
        onPressed:
            !consoleActionsEnabled ||
                swapSecondaryAction == null ||
                onAction == null
            ? null
            : () => onAction!(swapSecondaryAction),
      ),
      phasePass => HandTrayCommand(
        label: model.table.year.isEven
            ? (language == KolkhozLanguage.en ? 'Pass left' : 'Передать влево')
            : (language == KolkhozLanguage.en
                  ? 'Pass right'
                  : 'Передать вправо'),
        iconAsset: fieldPlanVariantPassCards.fieldPlanPath,
        flipHorizontally: passIconFlipsHorizontally(model.table.year),
        prominent: false,
      ),
      phaseAssignment => HandTrayCommand(
        label: language.strings.boardHandtrayUndo,
        iconAsset: fieldPlanToolbarUndoIconPath,
        prominent: false,
        onPressed: consoleActionsEnabled && canUndo ? onUndo : null,
      ),
      phaseRequisition => HandTrayCommand(
        label: language.strings.boardBoardrailTheNorth,
        iconAsset: fieldPlanNavigationNorthPath,
        prominent: false,
        motionKey: northConsoleCardMotionTargetKey,
        onPressed: !consoleActionsEnabled || onPanelSelected == null
            ? null
            : () => onPanelSelected!(panelNorth),
      ),
      _ => HandTrayCommand(
        label: language.strings.boardHandtrayUndo,
        iconAsset: fieldPlanToolbarUndoIconPath,
        prominent: false,
      ),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: handTrayOuterSpacing,
      children: [
        Expanded(
          child: CardDropTarget(
            highlightColor: tokens.colors.green,
            borderRadius: tokens.radius.sm,
            accepts: (data) =>
                trickSelectionLocked &&
                data.kind == CardDragKind.provisionalTrick &&
                data.cardID == provisionallyPlayedCardID,
            labelBuilder: (_) => language == KolkhozLanguage.en
                ? 'Return to Hand'
                : 'ВЕРНУТЬ В РУКУ',
            onAccepted: (data) => data.onAccepted(),
            child: contentOverride == null
                ? Container(
                    height: visibleTrayHeight,
                    padding: EdgeInsets.only(
                      left: handTrayZoneHorizontalPadding + leadingInset,
                      right: handTrayZoneHorizontalPadding,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(tokens.radius.sm),
                      border: Border.all(
                        color: tokens.colors.steel.withValues(alpha: 0.32),
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final largeCardSize = scaledHandTrayCardSize(
                          tokens.card.large,
                          visibleTrayHeight,
                        );
                        final cardStride = handTrayCardStride(
                          constraints.maxWidth,
                          largeCardSize.width,
                          hand.length,
                        );
                        final railWidth = handTrayCardRailWidth(
                          largeCardSize.width,
                          cardStride,
                          hand.length,
                        );
                        return KolkhozScrollbar(
                          tokens: tokens,
                          orientation: ScrollbarOrientation.bottom,
                          thumbVisibility: false,
                          trackVisibility: false,
                          childBuilder: (context, scrollController) => SingleChildScrollView(
                            controller: scrollController,
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            child: SizedBox(
                              width: math.max(constraints.maxWidth, railWidth),
                              height: visibleTrayHeight,
                              child: _TactileHandCardRail(
                                cards: hand,
                                cardStride: cardStride,
                                duration: GameMotion.of(context).cardReflow,
                                cardBuilder: (context, index, card, onEmphasisChanged) => Builder(
                                  builder: (context) {
                                    final playAction = handCardPlayAction(
                                      model,
                                      card,
                                    );
                                    final passAction = handCardPassAction(
                                      model,
                                      card,
                                    );
                                    final rewardAction = handCardRewardAction(
                                      model,
                                      card,
                                    );
                                    final onTap =
                                        !actionsEnabled || trickSelectionLocked
                                        ? null
                                        : switch (model.table.phase) {
                                            phasePlanning =>
                                              rewardAction == null ||
                                                      onHandCardTap == null
                                                  ? null
                                                  : () =>
                                                        onHandCardTap!(card.id),
                                            phaseTrick =>
                                              playAction != null &&
                                                      onHandCardTap != null
                                                  ? () =>
                                                        onHandCardTap!(card.id)
                                                  : handCardCanShowInvalidHint(
                                                      model,
                                                      card,
                                                    )
                                                  ? onInvalidHandCardTap
                                                  : null,
                                            phaseSwap =>
                                              onSwapHandCardTap == null
                                                  ? null
                                                  : () => onSwapHandCardTap!(
                                                      card.id,
                                                    ),
                                            phasePass =>
                                              passAction == null ||
                                                      onHandCardTap == null
                                                  ? null
                                                  : () =>
                                                        onHandCardTap!(card.id),
                                            _ => null,
                                          };
                                    final displayCard = handTrayCard(
                                      model,
                                      card,
                                      planningTrumpFocusedSuit:
                                          planningTrumpFocusedSuit,
                                    );
                                    final presentedCard = trickSelectionLocked
                                        ? cardWithSelection(
                                            displayCard,
                                            highlighted: false,
                                          )
                                        : displayCard;
                                    final playable =
                                        actionsEnabled &&
                                        (switch (model.table.phase) {
                                          phasePlanning => rewardAction != null,
                                          phaseTrick =>
                                            !trickSelectionLocked &&
                                                playAction != null,
                                          phaseSwap => card.highlighted,
                                          phasePass => passAction != null,
                                          _ => displayCard.highlighted,
                                        });
                                    final invalid =
                                        actionsEnabled &&
                                        playAction == null &&
                                        handCardCanShowInvalidHint(model, card);
                                    final actionable =
                                        actionsEnabled &&
                                        (switch (model.table.phase) {
                                          phasePlanning => rewardAction != null,
                                          phaseTrick =>
                                            playAction != null || invalid,
                                          phaseSwap => card.highlighted,
                                          phasePass => passAction != null,
                                          _ => false,
                                        });
                                    final trumpPreviewed =
                                        handCardMatchesPlanningTrumpFocus(
                                          model,
                                          card,
                                          planningTrumpFocusedSuit,
                                        );
                                    final dragEligible =
                                        actionsEnabled &&
                                        onTap != null &&
                                        switch (model.table.phase) {
                                          phasePlanning => rewardAction != null,
                                          phaseTrick => playAction != null,
                                          phaseSwap => card.highlighted,
                                          phasePass => passAction != null,
                                          _ => false,
                                        };
                                    final dragData = CardDragData(
                                      cardID: card.id,
                                      kind: CardDragKind.hand,
                                      phase: model.table.phase,
                                      canDrop: dragEligible,
                                      actionLabel:
                                          model.table.phase == phaseTrick &&
                                              playAction != null
                                          ? (language == KolkhozLanguage.en
                                                ? '${playAction.label} Card'
                                                : 'СЫГРАТЬ КАРТУ')
                                          : null,
                                      onSwapWith:
                                          model.table.phase == phaseSwap &&
                                              onSwapCardDrop != null
                                          ? (plotCardID, plotZone) =>
                                                onSwapCardDrop!(
                                                  card.id,
                                                  plotCardID,
                                                  plotZone,
                                                )
                                          : null,
                                      onAccepted: onTap ?? () {},
                                    );
                                    final handCardControl = NaturalSizeViewport(
                                      width: largeCardSize.width,
                                      height: visibleTrayHeight,
                                      naturalWidth: largeCardSize.width,
                                      naturalHeight: largeCardSize.height,
                                      clipBehavior: Clip.none,
                                      child: Transform.translate(
                                        offset: const Offset(
                                          0,
                                          handTrayCardYOffset,
                                        ),
                                        child: HandCardControl(
                                          key: ValueKey(
                                            'hand-card-control-${card.id}',
                                          ),
                                          card: presentedCard,
                                          tokens: tokens,
                                          language: language,
                                          trump: trumpPreviewed
                                              ? planningTrumpFocusedSuit
                                              : model.table.trump,
                                          size: largeCardSize,
                                          playable: playable,
                                          unavailable: invalid,
                                          lifted: trumpPreviewed,
                                          dragData: dragData,
                                          dealIndex: index,
                                          onEmphasisChanged: onEmphasisChanged,
                                          onTap: actionable ? onTap : null,
                                          highlightColor: trickSelectionLocked
                                              ? null
                                              : handTrayHighlightColor(
                                                  model,
                                                  card,
                                                  planningTrumpFocusedSuit:
                                                      planningTrumpFocusedSuit,
                                                  swapHighlightColor:
                                                      tokens.colors.red,
                                                  playableHighlightColor:
                                                      tokens.colors.green,
                                                ),
                                          highlightGlowEnabled:
                                              model.table.phase != phaseSwap,
                                          highlightedStrokeWidth:
                                              model.table.phase == phaseSwap
                                              ? handTraySwapHighlightStrokeWidth
                                              : null,
                                          highlightedBorderRadius:
                                              model.table.phase == phaseSwap
                                              ? handTraySwapHighlightCornerRadius
                                              : null,
                                        ),
                                      ),
                                    );
                                    if (model.table.phase != phaseSwap ||
                                        !card.highlighted ||
                                        onSwapHandCardTap == null) {
                                      return handCardControl;
                                    }
                                    return CardDropTarget(
                                      highlightColor: tokens.colors.green,
                                      borderRadius: tokens.radius.card,
                                      dragFeedbackSize: Size(
                                        largeCardSize.width,
                                        largeCardSize.height,
                                      ),
                                      accepts: (data) =>
                                          data.canDrop &&
                                          data.kind == CardDragKind.plot &&
                                          data.phase == phaseSwap,
                                      onAccepted: (data) {
                                        final commitSwap = data.onSwapWith;
                                        final plotZone = data.plotZone;
                                        if (commitSwap != null &&
                                            plotZone != null) {
                                          commitSwap(card.id, plotZone);
                                          return;
                                        }
                                        data.onAccepted();
                                        onSwapHandCardTap!(card.id);
                                      },
                                      child: handCardControl,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.only(left: leadingInset),
                    child: contentOverride,
                  ),
          ),
        ),
        if (showAssignmentCommandBar)
          AssignmentCommandBar(
            cards: assignmentCards,
            selectedCardID: model.selection.assignmentCardID,
            trump: model.table.trump,
            tokens: tokens,
            language: language,
            visibleTrayHeight: visibleTrayHeight,
            onCardTap: onAssignmentCardTap,
          ),
        HandConsole(
          status: handConsoleStatus(
            model,
            language,
            compact: visibleTrayHeight < handConsoleCompactHeightBreakpoint,
          ),
          primary: primaryCommand,
          secondary: secondaryCommand,
          tokens: tokens,
          visibleTrayHeight: visibleTrayHeight,
        ),
      ],
    );
  }
}

typedef _HandRailCardBuilder =
    Widget Function(
      BuildContext context,
      int index,
      TableCard card,
      ValueChanged<bool> onEmphasisChanged,
    );

class _TactileHandCardRail extends StatefulWidget {
  const _TactileHandCardRail({
    required this.cards,
    required this.cardStride,
    required this.duration,
    required this.cardBuilder,
  });

  final List<TableCard> cards;
  final double cardStride;
  final Duration duration;
  final _HandRailCardBuilder cardBuilder;

  @override
  State<_TactileHandCardRail> createState() => _TactileHandCardRailState();
}

class _TactileHandCardRailState extends State<_TactileHandCardRail> {
  String? emphasizedCardID;

  @override
  void didUpdateWidget(_TactileHandCardRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (emphasizedCardID != null &&
        !widget.cards.any((card) => card.id == emphasizedCardID)) {
      emphasizedCardID = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final emphasizedIndex = widget.cards.indexWhere(
      (card) => card.id == emphasizedCardID,
    );
    final entries = widget.cards.indexed.toList();
    if (emphasizedIndex >= 0) {
      final emphasizedEntry = entries.removeAt(emphasizedIndex);
      entries.add(emphasizedEntry);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final (index, card) in entries)
          AnimatedPositioned(
            key: ValueKey('hand-card-position-${card.id}'),
            left:
                index * widget.cardStride +
                _neighborOffset(index, emphasizedIndex),
            top: 0,
            duration: widget.duration,
            curve: GameMotion.cardReflowCurve,
            child: widget.cardBuilder(context, index, card, (emphasized) {
              if (emphasized) {
                if (emphasizedCardID != card.id) {
                  setState(() => emphasizedCardID = card.id);
                }
              } else if (emphasizedCardID == card.id) {
                setState(() => emphasizedCardID = null);
              }
            }),
          ),
      ],
    );
  }

  double _neighborOffset(int index, int emphasizedIndex) {
    if (emphasizedIndex < 0 || index == emphasizedIndex) {
      return 0;
    }
    return index < emphasizedIndex
        ? -handTrayNeighborSeparation
        : handTrayNeighborSeparation;
  }
}

class HandCardControl extends StatefulWidget {
  const HandCardControl({
    required this.card,
    required this.tokens,
    required this.language,
    required this.size,
    required this.playable,
    required this.unavailable,
    this.trump,
    this.highlightColor,
    this.highlightGlowEnabled = true,
    this.highlightedStrokeWidth,
    this.highlightedBorderRadius,
    this.dealIndex = 0,
    this.lifted = false,
    this.dragData,
    this.onEmphasisChanged,
    this.onTap,
    super.key,
  });

  final TableCard card;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final TokenCardSize size;
  final bool playable;
  final bool unavailable;
  final String? trump;
  final Color? highlightColor;
  final bool highlightGlowEnabled;
  final double? highlightedStrokeWidth;
  final double? highlightedBorderRadius;
  final int dealIndex;
  final bool lifted;
  final CardDragData? dragData;
  final ValueChanged<bool>? onEmphasisChanged;
  final VoidCallback? onTap;

  @override
  State<HandCardControl> createState() => _HandCardControlState();
}

class _HandCardControlState extends State<HandCardControl>
    with SingleTickerProviderStateMixin {
  bool focused = false;
  late final AnimationController invalidController;

  @override
  void initState() {
    super.initState();
    invalidController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  void _handleTap() {
    if (widget.unavailable && GameMotion.of(context).enabled) {
      invalidController
        ..duration = GameMotion.of(context).invalidShake
        ..forward(from: 0);
    }
    widget.onTap?.call();
  }

  @override
  void dispose() {
    invalidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = GameMotion.of(context);
    final actionable = widget.onTap != null;
    final label = handCardAccessibilityLabel(
      widget.card,
      widget.language,
      playable: widget.playable,
      selected: widget.card.selected,
      unavailable: widget.unavailable,
    );
    final card = AnimatedBuilder(
      animation: invalidController,
      builder: (context, child) {
        final progress = invalidController.value;
        return Transform.translate(
          key: ValueKey('hand-card-invalid-shake-${widget.card.id}'),
          offset: Offset(
            math.sin(progress * math.pi * 6) * (1 - progress) * 7,
            0,
          ),
          child: child,
        );
      },
      child: AnimatedSlide(
        key: ValueKey('hand-card-selection-slide-${widget.card.id}'),
        offset: widget.card.selected
            ? const Offset(0, -handTrayCardSelectedLiftFraction)
            : Offset.zero,
        duration: motion.handInteraction,
        curve: GameMotion.handInteractionCurve,
        child: TactileCardSurface(
          tokens: widget.tokens,
          size: widget.size,
          pressEnabled: actionable || widget.dragData != null,
          focused: focused || widget.lifted,
          onHoverChanged: widget.onEmphasisChanged,
          child: AnimatedOpacity(
            opacity: widget.unavailable ? 0.58 : 1,
            duration: motion.handInteraction,
            child: GameCard(
              card: widget.card,
              tokens: widget.tokens,
              trump: widget.trump,
              sizeOverride: widget.size,
              highlightColorOverride: widget.card.selected
                  ? widget.tokens.colors.goldBright
                  : widget.highlightColor,
              highlightGlowEnabled: widget.highlightGlowEnabled,
              highlightedStrokeWidthOverride: widget.highlightedStrokeWidth,
              highlightedBorderRadiusOverride: widget.highlightedBorderRadius,
              selectedColorOverride: widget.tokens.colors.goldBright,
              selectedStrokeWidthOverride: widget.tokens.stroke.active,
            ),
          ),
        ),
      ),
    );
    final dealDelay = handTrayDealStagger * widget.dealIndex;
    final dealDuration = motion.cardDeal + dealDelay;
    final dealCurve = dealDuration == Duration.zero
        ? Curves.linear
        : Interval(
            dealDelay.inMicroseconds / dealDuration.inMicroseconds,
            1,
            curve: GameMotion.cardTactileCurve,
          );
    final interactiveCard = Tooltip(
      message: label,
      child: Semantics(
        key: Key('hand-card-${widget.card.id}'),
        container: true,
        button: actionable,
        enabled: actionable,
        selected: widget.card.selected,
        label: label,
        onTap: actionable ? _handleTap : null,
        child: ExcludeSemantics(
          child: FocusableActionDetector(
            enabled: actionable,
            mouseCursor: actionable
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            onShowFocusHighlight: (value) => setState(() => focused = value),
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  _handleTap();
                  return null;
                },
              ),
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: actionable ? _handleTap : null,
              child: TweenAnimationBuilder<double>(
                key: ValueKey('hand-card-deal-${widget.card.id}'),
                tween: Tween(begin: 0, end: 1),
                duration: dealDuration,
                curve: dealCurve,
                builder: (context, value, child) => Opacity(
                  opacity: value.clamp(0, 1),
                  child: Transform.translate(
                    offset: Offset(0, (1 - value) * widget.size.height * 0.12),
                    child: Transform.scale(
                      scale: 0.94 + value * 0.06,
                      child: child,
                    ),
                  ),
                ),
                child: card,
              ),
            ),
          ),
        ),
      ),
    );
    final dragData = widget.dragData;
    if (dragData == null) {
      return interactiveCard;
    }
    return DraggableCardSurface(
      data: dragData,
      feedback: GameCard(
        card: widget.card,
        tokens: widget.tokens,
        trump: widget.trump,
        sizeOverride: widget.size,
        highlightColorOverride: widget.highlightColor,
      ),
      child: interactiveCard,
    );
  }
}

class HandConsole extends StatelessWidget {
  const HandConsole({
    required this.status,
    required this.primary,
    required this.secondary,
    required this.tokens,
    required this.visibleTrayHeight,
    super.key,
  });

  final String status;
  final HandTrayCommand primary;
  final HandTrayCommand secondary;
  final DesignTokens tokens;
  final double visibleTrayHeight;

  @override
  Widget build(BuildContext context) {
    final compact = visibleTrayHeight < handConsoleCompactHeightBreakpoint;
    final motion = GameMotion.of(context);
    final ready = primary.onPressed != null;
    final buttonScale = handConsoleButtonScale(visibleTrayHeight);
    final statusHeight = compact
        ? handConsoleCompactStatusHeight
        : handConsoleStatusHeight;
    return AnimatedSlide(
      offset: ready ? const Offset(0, -0.015) : Offset.zero,
      duration: motion.turnTransition,
      curve: Curves.easeOutBack,
      child: AnimatedScale(
        scale: ready ? 1.015 : 1,
        duration: motion.turnTransition,
        curve: Curves.easeOutBack,
        child: SizedBox(
          key: const Key('hand-console'),
          width: handConsoleWidth,
          height: visibleTrayHeight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: handConsoleRowSpacing,
            children: [
              Semantics(
                liveRegion: true,
                label: status,
                child: ExcludeSemantics(
                  child: Container(
                    key: const Key('hand-console-status'),
                    width: double.infinity,
                    height: statusHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(tokens.radius.xs),
                      border: Border.all(
                        color: tokens.colors.gold.withValues(alpha: 0.54),
                      ),
                    ),
                    child: MechanicalPanelSwitcher(
                      panelKey: status,
                      duration: const Duration(milliseconds: 220),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: DisplayText(
                            status,
                            size: compact
                                ? DisplayTextSize.caption2
                                : DisplayTextSize.caption,
                            variant: DisplayTextWeight.bold,
                            color: tokens.colors.cream,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: handTrayActionSpacing,
                children: [
                  ActionIconButton(
                    key: const Key('hand-console-primary'),
                    label: primary.label,
                    iconAsset: primary.iconAsset,
                    tokens: tokens,
                    prominent: primary.prominent,
                    flipHorizontally: primary.flipHorizontally,
                    scale: buttonScale,
                    onPressed: primary.onPressed,
                  ),
                  if (secondary.motionKey case final motionKey?)
                    MotionTrackedRegion(
                      motionKey: motionKey,
                      child: ActionIconButton(
                        key: const Key('hand-console-secondary'),
                        label: secondary.label,
                        iconAsset: secondary.iconAsset,
                        tokens: tokens,
                        prominent: secondary.prominent,
                        flipHorizontally: secondary.flipHorizontally,
                        scale: buttonScale,
                        onPressed: secondary.onPressed,
                      ),
                    )
                  else
                    ActionIconButton(
                      key: const Key('hand-console-secondary'),
                      label: secondary.label,
                      iconAsset: secondary.iconAsset,
                      tokens: tokens,
                      prominent: secondary.prominent,
                      flipHorizontally: secondary.flipHorizontally,
                      scale: buttonScale,
                      onPressed: secondary.onPressed,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HandTrayCommand {
  const HandTrayCommand({
    required this.label,
    required this.iconAsset,
    required this.prominent,
    this.flipHorizontally = false,
    this.motionKey,
    this.onPressed,
  });

  final String label;
  final String iconAsset;
  final bool prominent;
  final bool flipHorizontally;
  final MotionAnchor? motionKey;
  final VoidCallback? onPressed;
}

class AssignmentCommandBar extends StatelessWidget {
  const AssignmentCommandBar({
    required this.cards,
    required this.selectedCardID,
    required this.trump,
    required this.tokens,
    required this.language,
    required this.visibleTrayHeight,
    this.onCardTap,
    super.key,
  });

  final List<TableCard> cards;
  final String? selectedCardID;
  final String? trump;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final double visibleTrayHeight;
  final ValueChanged<String>? onCardTap;

  @override
  Widget build(BuildContext context) {
    final assignmentCardSize = scaledHandTrayCardSize(
      tokens.card.large,
      visibleTrayHeight,
    );
    final cardStride = handTrayAssignmentCardStride(assignmentCardSize.width);
    final railWidth = handTrayAssignmentRailWidth(
      assignmentCardSize.width,
      cards.length,
    );
    return SizedBox(
      width: handTrayAssignmentBarWidth(assignmentCardSize.width, cards.length),
      height: visibleTrayHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: handTrayAssignmentDividerSpacing,
        children: [
          Container(
            width: handTrayAssignmentDividerWidth,
            height: visibleTrayHeight - 10,
            margin: const EdgeInsets.only(
              top: handTrayAssignmentDividerTopMargin,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  tokens.colors.gold.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SizedBox(
            width: railWidth,
            child: Transform.translate(
              offset: const Offset(
                0,
                handTrayCardYOffset + handTrayAssignmentBaselineCorrection,
              ),
              child: Stack(
                alignment: Alignment.topRight,
                clipBehavior: Clip.none,
                children: [
                  for (final (index, card) in cards.indexed)
                    Positioned(
                      right: (cards.length - index - 1) * cardStride,
                      top: 0,
                      child: NaturalSizeViewport(
                        width: assignmentCardSize.width,
                        height: visibleTrayHeight,
                        naturalWidth: assignmentCardSize.width,
                        naturalHeight: assignmentCardSize.height,
                        clipBehavior: Clip.none,
                        child: AssignmentCommandCard(
                          card: card,
                          tokens: tokens,
                          trump: trump,
                          language: language,
                          selected: card.id == selectedCardID,
                          sizeOverride: assignmentCardSize,
                          onTap: () => onCardTap?.call(card.id),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AssignmentCommandCard extends StatelessWidget {
  const AssignmentCommandCard({
    required this.card,
    required this.tokens,
    required this.trump,
    required this.language,
    required this.selected,
    required this.sizeOverride,
    this.onTap,
    super.key,
  });

  final TableCard card;
  final DesignTokens tokens;
  final String? trump;
  final KolkhozLanguage language;
  final bool selected;
  final TokenCardSize sizeOverride;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final label = assignmentCardAccessibilityLabel(
      card,
      language,
      selected: selected,
    );
    final cardSurface = DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: selected
            ? [
                BoxShadow(
                  color: tokens.colors.gold.withValues(
                    alpha: assignmentCommandSelectedShadowOpacity,
                  ),
                  blurRadius: assignmentCommandSelectedShadowRadius,
                  offset: const Offset(
                    0,
                    assignmentCommandSelectedShadowYOffset,
                  ),
                ),
              ]
            : const [],
      ),
      child: Stack(
        children: [
          GameCard(
            card: cardWithSelection(card, highlighted: false),
            tokens: tokens,
            trump: trump,
            sizeOverride: sizeOverride,
          ),
          if (selected)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      assignmentCommandSelectedRadius,
                    ),
                    border: Border.all(
                      color: tokens.colors.gold,
                      width: assignmentCommandSelectedStrokeWidth,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    final interactiveCard = Tooltip(
      message: label,
      child: Semantics(
        container: true,
        button: enabled,
        enabled: enabled,
        selected: selected,
        label: label,
        onTap: onTap,
        child: ExcludeSemantics(
          child: FocusableActionDetector(
            enabled: enabled,
            mouseCursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  onTap?.call();
                  return null;
                },
              ),
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: TactileCardSurface(
                tokens: tokens,
                size: sizeOverride,
                pressEnabled: enabled,
                child: cardSurface,
              ),
            ),
          ),
        ),
      ),
    );
    if (!enabled) {
      return interactiveCard;
    }
    return DraggableCardSurface(
      data: CardDragData(
        cardID: card.id,
        kind: CardDragKind.assignment,
        phase: phaseAssignment,
        actionLabel: language == KolkhozLanguage.en
            ? 'DRAG TO ASSIGN'
            : 'ПЕРЕТАЩИТЕ ДЛЯ НАЗНАЧЕНИЯ',
        onAccepted: onTap!,
      ),
      feedback: GameCard(
        card: card,
        tokens: tokens,
        trump: trump,
        sizeOverride: sizeOverride,
      ),
      child: interactiveCard,
    );
  }
}

String assignmentCardAccessibilityLabel(
  TableCard card,
  KolkhozLanguage language, {
  required bool selected,
}) {
  final suit = card.suit == wreckerSuit
      ? language == KolkhozLanguage.en
            ? 'Wrecker'
            : 'Вредитель'
      : language.suitName(card.suit);
  final state = language == KolkhozLanguage.en
      ? selected
            ? ', selected for assignment'
            : ', available for assignment'
      : selected
      ? ', выбрана для назначения'
      : ', доступна для назначения';
  return language == KolkhozLanguage.en
      ? '${card.rank} of $suit$state'
      : '${card.rank} $suit$state';
}

class ActionIconButton extends StatelessWidget {
  const ActionIconButton({
    required this.label,
    required this.iconAsset,
    required this.tokens,
    required this.prominent,
    this.flipHorizontally = false,
    this.scale = 1,
    this.onPressed,
    super.key,
  });

  final String label;
  final String iconAsset;
  final DesignTokens tokens;
  final bool prominent;
  final bool flipHorizontally;
  final double scale;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final button = SizedBox(
      width: handTrayActionButtonSize * scale,
      height: handTrayActionButtonSize * scale,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: ChromeButtonBackground(
              asset: prominent
                  ? fieldPlanNavigationActiveFramePath
                  : fieldPlanNavigationInactiveFramePath,
            ),
          ),
          Transform.flip(
            flipX: flipHorizontally,
            child: ChromeAssetIcon(
              asset: iconAsset.startsWith('assets/')
                  ? iconAsset
                  : 'assets/ui/Icons/$iconAsset',
              width: handTrayActionIconSize * scale,
              height: handTrayActionIconSize * scale,
              fit: BoxFit.contain,
              muted: !enabled,
            ),
          ),
        ],
      ),
    );
    final child = enabled ? button : Opacity(opacity: 0.55, child: button);
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        onTap: onPressed,
        child: ExcludeSemantics(
          child: TactileControlSurface(
            enabled: enabled,
            onPressed: onPressed,
            pressTravel: 3 * scale,
            hoverLift: -1.5 * scale,
            hoverScale: 1.055,
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: tokens.colors.black.withValues(
                      alpha: prominent ? 0.28 : 0.18,
                    ),
                    blurRadius: (prominent ? 5 : 3) * scale,
                    offset: Offset(0, 2 * scale),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

const assignmentCommandSelectedRadius = 7.0;
const assignmentCommandSelectedStrokeWidth = 3.0;
const assignmentCommandSelectedShadowOpacity = 0.38;
const assignmentCommandSelectedShadowRadius = 9.0;
const assignmentCommandSelectedShadowYOffset = 2.0;
