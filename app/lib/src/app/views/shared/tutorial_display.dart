import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:simple_animations/simple_animations.dart';

import 'package:kolkhoz_app/src/app/settings/game_motion.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/game/game_view.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_assets.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/shared/display_text.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/shared/tutorial_content.dart';

bool _trickHasViewerPlay(Trick trick, int? viewerSeatID) {
  return trick.plays.any(
    (play) => viewerSeatID == null || play.seatID == viewerSeatID,
  );
}

bool _learnerWonThirdTrick(TableViewModel model) {
  final table = model.table;
  final viewerSeatID = model.viewer.seatID;
  if (table.year != 1 ||
      table.phase != phaseAssignment ||
      viewerSeatID == null ||
      table.lastTrick.winnerSeatID != viewerSeatID) {
    return false;
  }
  return table.jobs
      .expand((job) => job.assignedCards)
      .any((card) => card.assignmentRound == 2);
}

bool _learnerAssignedThirdTrick(TableViewModel model) {
  return model.table.year == 1 &&
      model.table.phase != phaseAssignment &&
      model.table.jobs
          .expand((job) => job.assignedCards)
          .any((card) => card.assignmentRound == 3);
}

bool _learnerWonYearTwoAssignmentAfterRound(
  TableViewModel model,
  int completedRound,
) {
  final table = model.table;
  final viewerSeatID = model.viewer.seatID;
  if (table.year != 2 ||
      table.phase != phaseAssignment ||
      viewerSeatID == null ||
      table.lastTrick.winnerSeatID != viewerSeatID) {
    return false;
  }
  return table.jobs
      .expand((job) => job.assignedCards)
      .any((card) => card.assignmentRound == completedRound);
}

int _viewerMedals(TableViewModel model) {
  final viewerSeatID = model.viewer.seatID;
  if (viewerSeatID == null) {
    return 0;
  }
  return model.table.seats.firstWhere((seat) => seat.id == viewerSeatID).medals;
}

/// Returns true when the live game state satisfies a step's advance event.
bool tutorialStepSatisfied(TutorialAdvance advance, TableViewModel? model) {
  if (model == null) {
    return false;
  }
  final table = model.table;
  switch (advance) {
    case TutorialAdvance.manual:
      return false;
    case TutorialAdvance.rewardsRevealed:
      return model.legalActions.any(
        (action) => action.kind == actionCompleteTutorialRewardLesson,
      );
    case TutorialAdvance.trumpChosen:
      return table.trump != null || table.phase != phasePlanning;
    case TutorialAdvance.cardPlayed:
      return _trickHasViewerPlay(table.trick, model.viewer.seatID) ||
          _trickHasViewerPlay(table.lastTrick, model.viewer.seatID);
    case TutorialAdvance.learnerThirdTrickWon:
      return _learnerWonThirdTrick(model);
    case TutorialAdvance.learnerThirdTrickAssigned:
      return _learnerAssignedThirdTrick(model);
    case TutorialAdvance.learnerYearTwoFirstMultiSuitWon:
      return _learnerWonYearTwoAssignmentAfterRound(model, 1);
    case TutorialAdvance.learnerYearTwoSecondMultiSuitWon:
      return _learnerWonYearTwoAssignmentAfterRound(model, 3);
    case TutorialAdvance.saboteurFollowPaused:
      return model.legalActions.any(
        (action) => action.kind == actionCompleteTutorialSaboteurFollowLesson,
      );
    case TutorialAdvance.saboteurAssignmentOpened:
      return table.year == 3 &&
          table.phase == phaseAssignment &&
          table.lastTrick.plays.any((play) => play.card.suit == wreckerSuit);
    case TutorialAdvance.jobCompleted:
      return table.jobs.any(
        (job) => job.claimed || job.hours >= job.requiredHours,
      );
    case TutorialAdvance.swapPhase:
      return table.phase == phaseSwap || table.year > 1;
    case TutorialAdvance.yearTwoRequisition:
      return table.year > 2 ||
          (table.year == 2 && table.phase == phaseRequisition);
    case TutorialAdvance.yearThree:
      return table.year >= 3;
    case TutorialAdvance.famineYear:
      return table.isFamine;
    case TutorialAdvance.learnerFamineTwoWins:
      return table.year == 5 && _viewerMedals(model) >= 2;
    case TutorialAdvance.learnerHeroProtected:
      final viewerSeatID = model.viewer.seatID;
      return table.year == 5 &&
          viewerSeatID != null &&
          table.phase == phaseRequisition &&
          table.requisitionEvents.any(
            (event) =>
                event.seatID == viewerSeatID &&
                event.card == null &&
                event.message == 'Protected from requisition.',
          );
    case TutorialAdvance.gameOver:
      return table.phase == phaseGameOver;
  }
}

/// Approximate board region for a tutorial focus glow, matching the wide
/// board layout: rail on the left, jobs strip on top, hand tray at the
/// bottom. Rough alignment is fine — this is a soft spotlight, not a mask.
Rect? tutorialFocusRect(
  TutorialFocus focus,
  BoxConstraints constraints,
  DesignTokens tokens,
) {
  if (focus == TutorialFocus.none) {
    return null;
  }
  final size = Size(constraints.maxWidth, constraints.maxHeight);
  final metrics = ResponsiveBoardMetrics.fromSize(size, tokens);
  final margin = metrics.margin;
  final railWidth = metrics.railWidth(constraints.maxWidth - margin * 2);
  final gameLeft = margin + railWidth + metrics.separatorWidth;
  final gameWidth = math.max(0.0, constraints.maxWidth - margin - gameLeft);
  final gameHeight = math.max(0.0, constraints.maxHeight - margin * 2);
  switch (focus) {
    case TutorialFocus.none:
      return null;
    case TutorialFocus.rail:
      return Rect.fromLTWH(margin, margin, railWidth, gameHeight);
    case TutorialFocus.jobs:
      return Rect.fromLTWH(gameLeft, margin, gameWidth, gameHeight * 0.15);
    case TutorialFocus.table:
      return Rect.fromLTWH(
        gameLeft,
        margin + gameHeight * 0.17,
        gameWidth,
        gameHeight * 0.45,
      );
    case TutorialFocus.hand:
      return Rect.fromLTWH(
        gameLeft,
        margin + gameHeight * 0.66,
        gameWidth,
        gameHeight * 0.34,
      );
  }
}

class TutorialWalkthroughOverlay extends StatefulWidget {
  const TutorialWalkthroughOverlay({
    required this.tokens,
    required this.language,
    required this.content,
    required this.onClose,
    this.onOrientationComplete,
    this.onContinueAction,
    this.model,
    super.key,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final TutorialContent content;
  final VoidCallback onClose;
  final VoidCallback? onOrientationComplete;
  final ValueChanged<String>? onContinueAction;
  final TableViewModel? model;

  @override
  State<TutorialWalkthroughOverlay> createState() =>
      _TutorialWalkthroughOverlayState();
}

/// True while the local player has an urgent affordance in the hand tray's
/// corner (confirming a selected trick card, or submitting assignments).
/// The tutorial panel folds away so it never covers those buttons.
bool tutorialShouldAutoCollapse(TableViewModel? model) {
  if (model == null) {
    return false;
  }
  final table = model.table;
  final pendingPlay =
      table.phase == phaseTrick && model.selection.handCardID != null;
  final viewerSeat = model.viewer.seatID;
  final assigning =
      table.phase == phaseAssignment &&
      viewerSeat != null &&
      table.lastTrick.winnerSeatID == viewerSeat;
  return pendingPlay || assigning;
}

Alignment tutorialPanelAlignment(TutorialFocus focus) {
  return focus == TutorialFocus.hand
      ? Alignment.topRight
      : Alignment.bottomRight;
}

class _TutorialWalkthroughOverlayState
    extends State<TutorialWalkthroughOverlay> {
  int orientationIndex = 0;
  bool orientationComplete = false;
  int stepIndex = 0;
  bool autoAdvanced = false;
  Timer? autoAdvanceTimer;

  /// null follows the auto-collapse rules; true/false is a manual override
  /// that lasts until the auto-collapse condition changes again.
  bool? manualCollapse;

  TutorialStepContent get step => widget.content.steps[stepIndex];
  bool get isLastStep => stepIndex == widget.content.steps.length - 1;
  bool get orientationRequired =>
      widget.model == null ||
      widget.model!.legalActions.any(
        (action) => action.kind == actionCompleteTutorialOrientation,
      );

  @override
  void initState() {
    super.initState();
    if (!orientationRequired) {
      orientationComplete = true;
      stepIndex = _resumeStepIndex(widget.model);
    }
  }

  int _resumeStepIndex(TableViewModel? model) {
    final table = model?.table;
    if (table == null) return 0;
    final resumeKey = switch (table.year) {
      1 => switch (table.phase) {
        phasePlanning =>
          model!.legalActions.any(
                (action) => action.kind == actionCompleteTutorialRewardLesson,
              )
              ? 'year1.rewards'
              : 'year1.planning',
        phaseTrick => 'year1.trick',
        phaseAssignment => 'year1.assignment',
        phaseRequisition => 'year1.requisition',
        _ => 'year1.planning',
      },
      2 => switch (table.phase) {
        phaseRequisition => 'year2.requisition',
        phaseAssignment =>
          table.jobs
                  .expand((job) => job.assignedCards)
                  .any((card) => card.assignmentRound == 3)
              ? 'year2.secondAssignment'
              : table.jobs
                    .expand((job) => job.assignedCards)
                    .any((card) => card.assignmentRound == 1)
              ? 'year2.firstAssignment'
              : 'year2.default',
        _ => 'year2.default',
      },
      3 =>
        model!.legalActions.any(
              (action) =>
                  action.kind == actionCompleteTutorialSaboteurFollowLesson,
            )
            ? 'year3.follow'
            : table.phase == phaseAssignment &&
                  table.lastTrick.plays.any(
                    (play) => play.card.suit == wreckerSuit,
                  )
            ? 'year3.assignment'
            : 'year3.default',
      4 => 'year4.default',
      _ => table.phase == phaseGameOver ? 'gameOver' : 'year5.default',
    };
    return widget.content.stepIndexForResumeKey(resumeKey);
  }

  @override
  void dispose() {
    autoAdvanceTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(TutorialWalkthroughOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!orientationRequired) {
      orientationComplete = true;
    }
    if (isLastStep ||
        step.advance == TutorialAdvance.manual ||
        !step.autoAdvance) {
      return;
    }
    final wasSatisfied = tutorialStepSatisfied(step.advance, oldWidget.model);
    final nowSatisfied = tutorialStepSatisfied(step.advance, widget.model);
    if (!wasSatisfied && nowSatisfied) {
      autoAdvanceTimer?.cancel();
      setState(() {
        stepIndex += 1;
        autoAdvanced = true;
        manualCollapse = false;
      });
      autoAdvanceTimer = Timer(const Duration(milliseconds: 1600), () {
        if (mounted) {
          setState(() => autoAdvanced = false);
        }
      });
    }
  }

  void goBack() {
    if (stepIndex == 0) {
      return;
    }
    setState(() {
      stepIndex -= 1;
      autoAdvanced = false;
    });
  }

  void goNext() {
    if (step.advance != TutorialAdvance.manual &&
        !tutorialStepSatisfied(step.advance, widget.model)) {
      setState(() => manualCollapse = true);
      return;
    }
    if (isLastStep) {
      widget.onClose();
      return;
    }
    final continueAction = step.continueAction;
    final collapseAfterContinue = step.collapseAfterContinue;
    if (continueAction != null) {
      widget.onContinueAction?.call(continueAction);
    }
    setState(() {
      stepIndex += 1;
      autoAdvanced = false;
      if (collapseAfterContinue) {
        manualCollapse = true;
      }
    });
  }

  void advanceOrientation() {
    if (orientationIndex < widget.content.orientationStops.length - 1) {
      setState(() => orientationIndex += 1);
      return;
    }
    setState(() {
      orientationComplete = true;
      stepIndex = widget.content.firstMatchStepIndex;
    });
    widget.onOrientationComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final collapsed =
        manualCollapse ?? tutorialShouldAutoCollapse(widget.model);
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 700;
            final panelWidth = math
                .min(
                  wide ? constraints.maxWidth * 0.5 : constraints.maxWidth - 20,
                  520,
                )
                .toDouble();
            final showingOrientation =
                !orientationComplete && orientationRequired;
            final focus = showingOrientation
                ? widget.content.orientationStops[orientationIndex].focus
                : step.focus;
            final glowRect = wide
                ? tutorialFocusRect(focus, constraints, widget.tokens)
                : null;
            final satisfied = tutorialStepSatisfied(step.advance, widget.model);
            return Stack(
              children: [
                if (glowRect != null)
                  TutorialFocusGlow(rect: glowRect, tokens: widget.tokens),
                if (showingOrientation)
                  Align(
                    alignment: tutorialPanelAlignment(focus),
                    child: Padding(
                      padding: EdgeInsets.all(wide ? 16 : 10),
                      child: SizedBox(
                        width: panelWidth,
                        child: TutorialOrientationPanel(
                          stop:
                              widget.content.orientationStops[orientationIndex],
                          index: orientationIndex,
                          count: widget.content.orientationStops.length,
                          header: widget.content.orientationHeader.resolve(
                            widget.language,
                          ),
                          beginLabel: widget.content.orientationBeginLabel
                              .resolve(widget.language),
                          tokens: widget.tokens,
                          language: widget.language,
                          onBack: orientationIndex == 0
                              ? null
                              : () => setState(() => orientationIndex -= 1),
                          onNext: advanceOrientation,
                          onClose: widget.onClose,
                        ),
                      ),
                    ),
                  )
                else if (collapsed)
                  Positioned(
                    right: wide ? 24 : 14,
                    bottom: wide
                        ? math.max(
                            14,
                            constraints.maxHeight -
                                (tutorialFocusRect(
                                      TutorialFocus.hand,
                                      constraints,
                                      widget.tokens,
                                    )?.bottom ??
                                    constraints.maxHeight) +
                                14,
                          )
                        : 14,
                    child: TutorialCollapsedBadge(
                      tokens: widget.tokens,
                      onExpand: () => setState(() => manualCollapse = false),
                    ),
                  )
                else
                  Align(
                    alignment: tutorialPanelAlignment(focus),
                    child: Padding(
                      padding: EdgeInsets.all(wide ? 16 : 10),
                      child: SizedBox(
                        width: panelWidth,
                        child: TutorialDialoguePanel(
                          step: step,
                          index: stepIndex,
                          count: widget.content.steps.length,
                          tokens: widget.tokens,
                          language: widget.language,
                          satisfied: satisfied,
                          celebrating: autoAdvanced,
                          onBack: goBack,
                          onNext: goNext,
                          onCollapse: () =>
                              setState(() => manualCollapse = true),
                          onClose: widget.onClose,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class TutorialOrientationPanel extends StatelessWidget {
  const TutorialOrientationPanel({
    required this.stop,
    required this.index,
    required this.count,
    required this.header,
    required this.beginLabel,
    required this.tokens,
    required this.language,
    required this.onNext,
    required this.onClose,
    this.onBack,
    super.key,
  });

  final TutorialOrientationStop stop;
  final int index;
  final int count;
  final String header;
  final String beginLabel;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return PanelStyleSurface(
      tokens: tokens,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 12,
        children: [
          ForemanMishaCard(
            key: const ValueKey('tutorial-orientation-foreman-card'),
            tokens: tokens,
            width: 92,
            height: 110,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 9,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DisplayText(
                            header,
                            size: DisplayTextSize.caption,
                            variant: DisplayTextWeight.bold,
                            color: tokens.colors.gold,
                          ),
                          Text(
                            stop.title(language).toUpperCase(),
                            style: kolkhozFontStyle.copyWith(
                              color: tokens.colors.cream,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      key: const Key('tutorial-close'),
                      onTap: onClose,
                      child: Icon(
                        Icons.close,
                        color: tokens.colors.creamDim,
                        size: 22,
                      ),
                    ),
                  ],
                ),
                Text(
                  stop.body(language),
                  style: kolkhozFontStyle.copyWith(
                    color: tokens.colors.cream,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                TutorialProgressDots(
                  index: index,
                  count: count,
                  tokens: tokens,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 8,
                  children: [
                    ChromeAssetButton(
                      key: const Key('tutorial-back'),
                      label: language.strings.tutorialdisplayBack,
                      tokens: tokens,
                      enabled: onBack != null,
                      backgroundAsset: chromeButtonSecondaryAsset,
                      textColor: tokens.colors.cardInk,
                      textSize: DisplayTextSize.caption,
                      width: 110,
                      height: 34,
                      onPressed: onBack ?? () {},
                    ),
                    ChromeAssetButton(
                      key: const Key('tutorial-next'),
                      label: index == count - 1
                          ? beginLabel
                          : language.strings.tutorialdisplayNext,
                      tokens: tokens,
                      backgroundAsset: chromeButtonPrimaryAsset,
                      textColor: tokens.colors.onAccent,
                      textSize: DisplayTextSize.caption,
                      width: 130,
                      height: 34,
                      onPressed: onNext,
                    ),
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

/// The folded-away tutorial: a small Misha badge that re-opens the panel.
class TutorialCollapsedBadge extends StatelessWidget {
  const TutorialCollapsedBadge({
    required this.tokens,
    required this.onExpand,
    super.key,
  });

  final DesignTokens tokens;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final motion = GameMotion.of(context);
    return GestureDetector(
      key: const Key('tutorial-expand'),
      behavior: HitTestBehavior.opaque,
      onTap: onExpand,
      child: Tooltip(
        message: 'Open Foreman Misha',
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: motion.enabled
              ? const Duration(milliseconds: 520)
              : Duration.zero,
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Transform.translate(
            offset: Offset(0, -120 * (1 - value)),
            child: Transform.rotate(
              angle: -0.08 * (1 - value),
              child: Opacity(opacity: value, child: child),
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ForemanMishaCard(
                key: const ValueKey('tutorial-collapsed-foreman-card'),
                tokens: tokens,
                width: 58,
                height: 79,
              ),
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tokens.colors.redBright,
                    border: Border.all(color: tokens.colors.cream, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: tokens.colors.black.withValues(alpha: 0.35),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    '!',
                    style: kolkhozFontStyle.copyWith(
                      color: tokens.colors.cream,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
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

/// Soft pulsing spotlight over the board region a step refers to. Ignores
/// pointer events so the board underneath stays fully playable.
class TutorialFocusGlow extends StatelessWidget {
  const TutorialFocusGlow({
    required this.rect,
    required this.tokens,
    super.key,
  });

  final Rect rect;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: MirrorAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1100),
          builder: (context, value, child) {
            final pulse = 0.30 + value * 0.45;
            final gold = tokens.colors.gold;
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: gold.withValues(alpha: pulse),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gold.withValues(alpha: pulse * 0.35),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class TutorialDialoguePanel extends StatelessWidget {
  const TutorialDialoguePanel({
    required this.step,
    required this.index,
    required this.count,
    required this.tokens,
    required this.language,
    required this.onBack,
    required this.onNext,
    required this.onClose,
    this.onCollapse,
    this.satisfied = false,
    this.celebrating = false,
    super.key,
  });

  final TutorialStepContent step;
  final int index;
  final int count;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onClose;
  final VoidCallback? onCollapse;
  final bool satisfied;
  final bool celebrating;

  bool get isLastStep => index == count - 1;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: celebrating
            ? [
                BoxShadow(
                  color: tokens.colors.gold.withValues(alpha: 0.55),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ]
            : const [],
      ),
      child: PanelStyleSurface(
        tokens: tokens,
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: 10,
          children: [
            Flexible(
              flex: 0,
              child: ForemanMishaCard(
                key: const ValueKey('tutorial-dialogue-foreman-card'),
                tokens: tokens,
                width: 92,
                height: 110,
              ),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 7,
                children: [
                  TutorialHeader(
                    step: step,
                    tokens: tokens,
                    language: language,
                    onCollapse: onCollapse,
                    onClose: onClose,
                  ),
                  Text(
                    step.body(language),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: kolkhozFontStyle.copyWith(
                      color: tokens.colors.creamDim,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TutorialTip(step: step, tokens: tokens, language: language),
                  TutorialCallout(
                    step: step,
                    tokens: tokens,
                    language: language,
                    satisfied: satisfied,
                  ),
                  TutorialProgressDots(
                    index: index,
                    count: count,
                    tokens: tokens,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 8,
                    children: [
                      ChromeAssetButton(
                        key: const Key('tutorial-back'),
                        label: language.strings.tutorialdisplayBack,
                        tokens: tokens,
                        enabled: index > 0,
                        backgroundAsset: chromeButtonSecondaryAsset,
                        textColor: tokens.colors.cardInk,
                        textSize: DisplayTextSize.caption,
                        width: 110,
                        height: 34,
                        onPressed: onBack,
                      ),
                      ChromeAssetButton(
                        key: const Key('tutorial-next'),
                        label: isLastStep
                            ? language.strings.tutorialdisplayDone
                            : language.strings.tutorialdisplayNext,
                        tokens: tokens,
                        backgroundAsset: chromeButtonPrimaryAsset,
                        textColor: tokens.colors.onAccent,
                        textSize: DisplayTextSize.caption,
                        width: 110,
                        height: 34,
                        onPressed: onNext,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ForemanHintBubble extends StatelessWidget {
  const ForemanHintBubble({
    required this.message,
    required this.tokens,
    super.key,
  });

  final String message;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return PanelStyleSurface(
      tokens: tokens,
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 8,
        children: [
          ForemanMishaCard(
            key: const ValueKey('foreman-hint-card'),
            tokens: tokens,
            width: 58,
            height: 70,
          ),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 270),
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: kolkhozFontStyle.copyWith(
                  color: tokens.colors.cream,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TutorialHeader extends StatelessWidget {
  const TutorialHeader({
    required this.step,
    required this.tokens,
    required this.language,
    required this.onClose,
    this.onCollapse,
    super.key,
  });

  final TutorialStepContent step;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final VoidCallback onClose;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 8,
      children: [
        Image.asset(
          step.iconPath,
          width: 23,
          height: 23,
          filterQuality: FilterQuality.none,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 1,
            children: [
              DisplayText(
                language.strings.tutorialdisplayForemanMisha,
                size: DisplayTextSize.caption,
                variant: DisplayTextWeight.bold,
                color: tokens.colors.gold,
              ),
              Text(
                step.title(language).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kolkhozFontStyle.copyWith(
                  color: tokens.colors.cream,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        if (onCollapse != null)
          GestureDetector(
            key: const Key('tutorial-collapse'),
            behavior: HitTestBehavior.opaque,
            onTap: onCollapse,
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: tokens.colors.steel.withValues(alpha: 0.56),
                ),
              ),
              child: DisplayText(
                'V',
                size: DisplayTextSize.caption,
                variant: DisplayTextWeight.bold,
                color: tokens.colors.creamDim,
              ),
            ),
          ),
        GestureDetector(
          key: const Key('tutorial-close'),
          behavior: HitTestBehavior.opaque,
          onTap: onClose,
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: tokens.colors.steel.withValues(alpha: 0.56),
              ),
            ),
            child: DisplayText(
              'X',
              size: DisplayTextSize.caption,
              variant: DisplayTextWeight.bold,
              color: tokens.colors.creamDim,
            ),
          ),
        ),
      ],
    );
  }
}

class TutorialTip extends StatelessWidget {
  const TutorialTip({
    required this.step,
    required this.tokens,
    required this.language,
    super.key,
  });

  final TutorialStepContent step;
  final DesignTokens tokens;
  final KolkhozLanguage language;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: tokens.colors.redDark.withValues(alpha: 0.46),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 7,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              color: tokens.colors.redDark.withValues(alpha: 0.34),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: tokens.colors.redBright.withValues(alpha: 0.58),
              ),
            ),
            child: DisplayText(
              language.strings.tutorialdisplayTip,
              size: DisplayTextSize.caption,
              variant: DisplayTextWeight.bold,
              color: tokens.colors.redBright,
            ),
          ),
          Expanded(
            child: Text(
              step.tip(language),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: kolkhozFontStyle.copyWith(
                color: tokens.colors.cream,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TutorialCallout extends StatelessWidget {
  const TutorialCallout({
    required this.step,
    required this.tokens,
    required this.language,
    this.satisfied = false,
    super.key,
  });

  final TutorialStepContent step;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final bool satisfied;

  @override
  Widget build(BuildContext context) {
    final calloutText = satisfied
        ? language.strings.tutorialdisplayDoneWellWorkedComrade
        : step.callout(language);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: tokens.colors.gold.withValues(alpha: satisfied ? 0.95 : 0.55),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Image.asset(
            satisfied
                ? fieldPlanToolbarConfirmIconPath
                : 'assets/ui/Embellishments/tutorial-focus-spark.png',
            width: 20,
            height: 20,
            filterQuality: FilterQuality.none,
          ),
          Expanded(
            child: Text(
              calloutText.toUpperCase(),
              style: kolkhozFontStyle.copyWith(
                color: tokens.colors.goldBright,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TutorialProgressDots extends StatelessWidget {
  const TutorialProgressDots({
    required this.index,
    required this.count,
    required this.tokens,
    super.key,
  });

  final int index;
  final int count;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 5,
      children: [
        for (var dotIndex = 0; dotIndex < count; dotIndex += 1)
          Container(
            key: ValueKey('tutorial-dot-$dotIndex'),
            width: dotIndex == index ? 22 : 8,
            height: 6,
            decoration: BoxDecoration(
              color: dotIndex <= index
                  ? tokens.colors.gold
                  : tokens.colors.steel.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}
