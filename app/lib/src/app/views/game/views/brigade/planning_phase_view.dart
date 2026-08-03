import 'dart:ui' show clampDouble;

import 'package:flutter/material.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/views/brigade/brigade_layout.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/board_widgets.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/display/table_display.dart';
import 'package:kolkhoz_app/src/app/views/game/views/plots/plots_view.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/shared/display_text.dart';

class PlanningPhasePanel extends StatelessWidget {
  const PlanningPhasePanel({
    required this.model,
    required this.tokens,
    required this.language,
    this.focusedSuit,
    this.onAction,
    this.onSuitHovered,
    this.onRewardsRevealed,
    this.rewardCardScale = planningRewardCardScale,
    this.rewardColumnCount = 4,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final String? focusedSuit;
  final ValueChanged<LegalAction>? onAction;
  final ValueChanged<String?>? onSuitHovered;
  final VoidCallback? onRewardsRevealed;
  final double rewardCardScale;
  final int rewardColumnCount;

  @override
  Widget build(BuildContext context) {
    final revealAction = model.legalActions
        .where(
          (action) =>
              action.kind == actionRevealReward ||
              action.kind == actionRevealTrump,
        )
        .firstOrNull;
    if (model.table.isFamine &&
        (revealAction?.kind == actionRevealTrump ||
            model.table.finalYearTrumpCard != null)) {
      return FinalTrumpRevealPanel(
        model: model,
        tokens: tokens,
        language: language,
      );
    }
    return PlanningRewardsPanel(
      model: model,
      tokens: tokens,
      language: language,
      focusedSuit: focusedSuit,
      onAction: onAction,
      onSuitHovered: onSuitHovered,
      onRewardsRevealed: onRewardsRevealed,
      rewardCardScale: rewardCardScale,
      rewardColumnCount: rewardColumnCount,
    );
  }
}

class PlanningRewardsPanel extends StatefulWidget {
  const PlanningRewardsPanel({
    required this.model,
    required this.tokens,
    required this.language,
    this.focusedSuit,
    this.onAction,
    this.onSuitHovered,
    this.onRewardsRevealed,
    this.rewardCardScale = planningRewardCardScale,
    this.rewardColumnCount = 4,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final String? focusedSuit;
  final ValueChanged<LegalAction>? onAction;
  final ValueChanged<String?>? onSuitHovered;
  final VoidCallback? onRewardsRevealed;
  final double rewardCardScale;
  final int rewardColumnCount;

  @override
  State<PlanningRewardsPanel> createState() => _PlanningRewardsPanelState();
}

class _PlanningRewardsPanelState extends State<PlanningRewardsPanel> {
  final Map<String, String> completedRewardIDs = {};
  bool reportedAllRewards = false;

  @override
  void didUpdateWidget(PlanningRewardsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentRewards = {
      for (final job in widget.model.table.jobs) job.suit: job.reward?.id,
    };
    completedRewardIDs.removeWhere(
      (suit, cardID) => currentRewards[suit] != cardID,
    );
    if (!_allRewardsCompleted(currentRewards)) {
      reportedAllRewards = false;
    }
  }

  void _handleRewardCompleted(String suit, TableCard reward) {
    if (completedRewardIDs[suit] == reward.id) {
      return;
    }
    setState(() => completedRewardIDs[suit] = reward.id);
    final rewards = {
      for (final job in widget.model.table.jobs) job.suit: job.reward?.id,
    };
    if (_allRewardsCompleted(rewards) && !reportedAllRewards) {
      reportedAllRewards = true;
      widget.onRewardsRevealed?.call();
    }
  }

  bool _allRewardsCompleted(Map<String, String?> rewards) =>
      displaySuitOrder.every(
        (suit) =>
            rewards[suit] != null && completedRewardIDs[suit] == rewards[suit],
      );

  @override
  Widget build(BuildContext context) {
    final cardSize = scaledPlanningRewardCardSize(
      widget.tokens.card.small,
      widget.rewardCardScale,
    );
    final rewards = {
      for (final job in widget.model.table.jobs) job.suit: job.reward,
    };
    final managedOffers = {
      for (final card in widget.model.table.managedRewardOffers)
        card.suit: card,
    };
    final displayedRewards = {
      for (final suit in displaySuitOrder)
        suit: rewards[suit] ?? managedOffers[suit],
    };
    final rewardsReady = displaySuitOrder.every(
      (suit) => rewards[suit] != null,
    );
    final planningDecisionReady =
        rewardsReady || managedOffers.length == displaySuitOrder.length;
    final options = planningTrumpOptions(
      widget.model.legalActions,
      language: widget.language,
    );
    final selectorIsAI = planningTrumpSelectorIsAI(widget.model);
    final canSelectTrump = rewardsReady && !selectorIsAI;
    Widget rewardColumn(String suit) => SizedBox(
      width: cardSize.width,
      child: MotionTrackedRegion(
        motionKey: rewardPileMotionSourceKey(suit),
        child: Builder(
          builder: (context) {
            final option = optionForSuit(options, suit);
            final enabled =
                canSelectTrump &&
                option?.action != null &&
                widget.onAction != null;
            return RewardFlipCard(
              key: ValueKey('reward-flip-$suit'),
              reward: displayedRewards[suit],
              tokens: widget.tokens,
              size: cardSize,
              label: option?.label ?? widget.language.suitName(suit),
              selected: suit == widget.focusedSuit,
              enabled: enabled,
              onPressed: enabled
                  ? () => widget.onAction!(option!.action!)
                  : null,
              onHoverChanged: enabled
                  ? (hovered) =>
                        widget.onSuitHovered?.call(hovered ? suit : null)
                  : null,
              onCompleted: displayedRewards[suit] == null
                  ? null
                  : () => _handleRewardCompleted(suit, displayedRewards[suit]!),
            );
          },
        ),
      ),
    );
    final columnCount = widget.rewardColumnCount.clamp(
      1,
      displaySuitOrder.length,
    );
    final rewardRows = [
      for (var start = 0; start < displaySuitOrder.length; start += columnCount)
        displaySuitOrder
            .skip(start)
            .take(columnCount)
            .map(rewardColumn)
            .toList(),
    ];
    return PanelStyleSurface(
      key: const Key('planning-rewards-panel'),
      tokens: widget.tokens,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          DisplayText(
            managedOffers.isNotEmpty
                ? (widget.language == KolkhozLanguage.en
                      ? 'MANAGED ECONOMY'
                      : 'ПЛАНОВАЯ ЭКОНОМИКА')
                : (widget.language == KolkhozLanguage.en
                      ? 'REWARD REVEAL'
                      : 'ОТКРЫТИЕ НАГРАД'),
            textAlign: TextAlign.center,
            size: DisplayTextSize.caption,
            variant: DisplayTextWeight.bold,
            color: widget.tokens.colors.gold,
          ),
          if (managedOffers.isNotEmpty)
            DisplayText(
              managedOffers.values
                  .map(
                    (card) =>
                        '${widget.language.suitName(card.suit)} ${card.rank}',
                  )
                  .join(' · '),
              key: const Key('managed-economy-offers'),
              textAlign: TextAlign.center,
              size: DisplayTextSize.xSmall,
              color: widget.tokens.colors.cream,
            ),
          Column(
            key: ValueKey('planning-reward-grid-$columnCount'),
            mainAxisSize: MainAxisSize.min,
            spacing: planningRewardRowSpacing,
            children: [
              for (final row in rewardRows)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: planningRewardColumnSpacing,
                  children: row,
                ),
            ],
          ),
          DisplayText(
            planningDecisionReady
                ? planningTrumpStatus(widget.model, widget.language)
                : (widget.language == KolkhozLanguage.en
                      ? 'REVEALING REWARDS…'
                      : 'ОТКРЫВАЕМ НАГРАДЫ…'),
            key: const Key('planning-reward-status'),
            textAlign: TextAlign.center,
            size: DisplayTextSize.xSmall,
            variant: DisplayTextWeight.bold,
            color: rewardsReady
                ? widget.tokens.colors.gold
                : widget.tokens.colors.cream,
          ),
        ],
      ),
    );
  }
}

TrumpActionOption? optionForSuit(
  List<TrumpActionOption> options,
  String suit,
) => options.where((option) => option.suit == suit).firstOrNull;

const planningRewardColumnSpacing = 7.0;
const planningRewardRowSpacing = 7.0;
const planningRewardCardScale = 1.05;
const planningRewardMinimumSingleRowCardScale = 0.82;
const planningRewardMinimumCardScale = 0.72;
const planningRewardPanelHorizontalPadding = 20.0;

double planningRewardPanelWidth({
  required double baseCardWidth,
  required double cardScale,
  required int columnCount,
}) =>
    planningRewardPanelHorizontalPadding +
    baseCardWidth * cardScale * columnCount +
    planningRewardColumnSpacing * (columnCount - 1);

int planningRewardColumnCountForWidth({
  required double availableWidth,
  required double baseCardWidth,
}) =>
    availableWidth >=
        planningRewardPanelWidth(
          baseCardWidth: baseCardWidth,
          cardScale: planningRewardMinimumSingleRowCardScale,
          columnCount: 4,
        )
    ? 4
    : 2;

double planningRewardCardScaleForWidth({
  required double availableWidth,
  required double baseCardWidth,
  required int columnCount,
}) {
  final availableForCards =
      availableWidth -
      planningRewardPanelHorizontalPadding -
      planningRewardColumnSpacing * (columnCount - 1);
  return clampDouble(
    availableForCards / (baseCardWidth * columnCount),
    planningRewardMinimumCardScale,
    planningRewardCardScale,
  );
}

TokenCardSize scaledPlanningRewardCardSize(TokenCardSize base, double scale) {
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

class RewardFlipCard extends StatelessWidget {
  const RewardFlipCard({
    required this.reward,
    required this.tokens,
    required this.size,
    this.label,
    this.selected = false,
    this.enabled = false,
    this.onPressed,
    this.onHoverChanged,
    this.onCompleted,
    super.key,
  });

  final TableCard? reward;
  final DesignTokens tokens;
  final TokenCardSize size;
  final String? label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onPressed;
  final ValueChanged<bool>? onHoverChanged;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context) {
    final reward = this.reward;
    final card = CardFlip(
      showFront: reward != null,
      frontKey: reward == null ? null : ValueKey('reward-face-${reward.id}'),
      backKey: const ValueKey('reward-back'),
      onCompleted: onCompleted,
      front: reward == null
          ? const SizedBox.shrink()
          : TactileCardSurface(
              tokens: tokens,
              size: size,
              enabled: enabled || selected,
              focused: selected,
              onHoverChanged: onHoverChanged,
              child: GameCard(
                card: reward,
                tokens: tokens,
                trump: selected ? reward.suit : null,
                sizeOverride: size,
              ),
            ),
      back: ScaledCardBack(tokens: tokens, size: size),
    );
    final interactiveCard = Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: label,
      onTap: enabled ? onPressed : null,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          enabled: enabled,
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                if (enabled) {
                  onPressed?.call();
                }
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? onPressed : null,
            child: card,
          ),
        ),
      ),
    );
    return DraggableCardSurface(
      enabled: reward != null,
      data: CardDragData(
        cardID: reward?.id ?? 'unrevealed-reward',
        kind: CardDragKind.reward,
        phase: phasePlanning,
        canDrop: false,
        onAccepted: () {},
      ),
      feedback: reward == null
          ? ScaledCardBack(tokens: tokens, size: size)
          : GameCard(
              card: reward,
              tokens: tokens,
              trump: selected ? reward.suit : null,
              sizeOverride: size,
            ),
      child: interactiveCard,
    );
  }
}

class FinalTrumpRevealPanel extends StatelessWidget {
  const FinalTrumpRevealPanel({
    required this.model,
    required this.tokens,
    required this.language,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;

  @override
  Widget build(BuildContext context) {
    final finalTrump = model.table.finalYearTrumpCard;
    final cardSize = tokens.card.small;
    return PanelStyleSurface(
      key: const Key('final-trump-reveal-panel'),
      tokens: tokens,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 7,
        children: [
          DisplayText(
            language == KolkhozLanguage.en ? 'REVEAL TRUMP' : 'ОТКРЫТЬ КОЗЫРЬ',
            textAlign: TextAlign.center,
            size: DisplayTextSize.caption,
            variant: DisplayTextWeight.bold,
            color: tokens.colors.gold,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              MotionTrackedRegion(
                motionKey: finalTrumpMotionSourceKey,
                child: ScaledCardBack(tokens: tokens, size: cardSize),
              ),
              if (finalTrump != null)
                GameCard(
                  card: finalTrump,
                  tokens: tokens,
                  sizeOverride: cardSize,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

bool planningTrumpSelectorIsAI(TableViewModel model) {
  if (model.table.phase != phasePlanning || model.table.isFamine) {
    return false;
  }
  for (final seat in model.table.seats) {
    if (seat.id == model.table.currentPlayerID) {
      return seat.controller == controllerHeuristicAI ||
          seat.controller == controllerMediumAI ||
          seat.controller == controllerNeuralAI;
    }
  }
  return false;
}
