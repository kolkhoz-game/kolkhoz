import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/native_game_engine.dart';

void main() {
  test('NativeGameEngine exclusively owns native lifecycle and clones', () {
    final bridge = KolkhozCEngineBridge();
    final engine = NativeGameEngine(
      bridge: bridge,
      seed: 20260721,
      variants: KolkhozGameVariants.kolkhoz,
      controllers: const [
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
      ],
    );
    final clone = engine.clone();
    final phase = engine.phase;

    expect(engine.seed, 20260721);
    expect(engine.variants, KolkhozGameVariants.kolkhoz);
    expect(engine.controllers, hasLength(4));
    expect(
      () => engine.controllers[0] = KolkhozPlayerController.neuralAI,
      throwsUnsupportedError,
    );

    engine.dispose();
    engine.dispose();

    expect(() => engine.phase, throwsStateError);
    expect(clone.phase, phase);
    clone.dispose();
  });

  test('final trick card returns ordered rule transitions in one dispatch', () {
    final bridge = KolkhozCEngineBridge();
    final engine = NativeGameEngine(
      bridge: bridge,
      seed: 20260723,
      variants: KolkhozGameVariants.kolkhoz,
      controllers: const [
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
      ],
    );
    addTearDown(engine.dispose);

    while (engine.phase != kcPhaseTrick) {
      final actions = engine.legalActions;
      expect(actions, isNotEmpty);
      final action = actions.firstWhere(
        (action) =>
            action.kind == kcActionConfirmRewardSwaps ||
            action.kind == kcActionConfirmSwap,
        orElse: () => actions.first,
      );
      expect(engine.applyManual(action), 0);
    }

    for (var play = 0; play < 4; play++) {
      final actions = engine.legalActions
          .where((action) => action.kind == kcActionPlayCard)
          .toList();
      expect(actions, isNotEmpty);
      expect(engine.applyManual(actions.first), 0);
      if (play < 3) {
        final currentWinner = engine.readNative(
          (bridge, pointer) => bridge.currentTrickWinner(pointer),
        );
        expect(
          currentWinner,
          isNot(-1),
          reason: 'the in-progress trick needs a visible leader',
        );
        expect(engine.transitionEvents.single.trickWinnerID, currentWinner);
      }
    }

    expect(
      engine.transitionEvents.map((event) => event.kind),
      containsAllInOrder([
        kcTransitionCardMoved,
        kcTransitionTrickResolved,
        kcTransitionAssignmentOpened,
      ]),
    );
    expect(engine.transitionEvents.first.fromZone, kcObjectZoneHand);
    expect(engine.transitionEvents.first.toZone, kcObjectZoneCurrentTrick);
  });

  test('Saboteur field leaves the Hero fully protected', () {
    var foundScenario = false;
    for (var seed = 1; seed <= 250 && !foundScenario; seed += 1) {
      final bridge = KolkhozCEngineBridge();
      final engine = NativeGameEngine(
        bridge: bridge,
        seed: seed,
        variants: KolkhozGameVariants.kolkhoz.copyWith(managedEconomy: false),
        controllers: const [
          KolkhozPlayerController.human,
          KolkhozPlayerController.human,
          KolkhozPlayerController.human,
          KolkhozPlayerController.human,
        ],
      );
      addTearDown(engine.dispose);
      final inspectedYears = <int>{};

      for (var actionCount = 0; actionCount < 900; actionCount += 1) {
        final year = engine.readNative(
          (bridge, pointer) => bridge.year(pointer),
        );
        if (engine.phase == kcPhaseGameOver) {
          break;
        }
        if (engine.phase == kcPhaseRequisition && inspectedYears.add(year)) {
          final requiredMedals = engine.readNative(
            (bridge, pointer) => bridge.isFamine(pointer) ? 3 : 4,
          );
          final heroID = engine.readNative(
            (bridge, pointer) => [
              for (var playerID = 0; playerID < 4; playerID += 1)
                if (bridge.playerMedals(pointer, playerID) == requiredMedals)
                  playerID,
            ].firstOrNull,
          );
          final wreckerSuit = engine.readNative(
            (bridge, pointer) => [
              for (var suit = 0; suit < 4; suit += 1)
                if ([
                  for (
                    var index = 0;
                    index < bridge.jobBucketCount(pointer, suit);
                    index += 1
                  )
                    bridge.jobBucketCard(pointer, suit, index).suit,
                ].contains(4))
                  suit,
            ].firstOrNull,
          );
          if (heroID != null && wreckerSuit != null) {
            final heroChoices = engine.legalActions.where(
              (action) =>
                  action.kind == kcActionSelectRequisitionCard &&
                  action.playerID == heroID,
            );
            final compromisedEvents = engine.readNative(
              (bridge, pointer) => [
                for (
                  var index = 0;
                  index < bridge.requisitionEventCount(pointer);
                  index += 1
                )
                  if (bridge.requisitionEventMessageKind(pointer, index) == 5)
                    bridge.requisitionEventPlayer(pointer, index),
              ],
            );
            expect(heroChoices, isEmpty);
            expect(compromisedEvents, isEmpty);
            foundScenario = true;
            break;
          }
        }
        if (engine.phase == kcPhaseRequisition && engine.legalActions.isEmpty) {
          expect(engine.stepAutomatic(), greaterThan(0));
          continue;
        }
        final action = engine.heuristicAction() ?? engine.legalActions.first;
        expect(engine.applyManual(action), 0);
      }
    }
    expect(foundScenario, isTrue);
  });

  test('tutorial engine authors the first three teaching years', () {
    final bridge = KolkhozCEngineBridge();
    final engine = NativeGameEngine(
      bridge: bridge,
      seed: 20260728,
      variants: KolkhozGameVariants.kolkhoz,
      controllers: const [
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
      ],
      tutorial: true,
    );
    addTearDown(engine.dispose);

    void advanceToRequisition(int expectedYear) {
      for (var actionCount = 0; actionCount < 300; actionCount += 1) {
        final year = engine.readNative(
          (bridge, pointer) => bridge.year(pointer),
        );
        if (year == expectedYear &&
            engine.phase == kcPhaseRequisition &&
            engine.legalActions.isNotEmpty) {
          return;
        }
        if (engine.phase == kcPhaseRequisition && engine.legalActions.isEmpty) {
          engine.stepAutomatic();
          continue;
        }
        final action = engine.heuristicAction() ?? engine.legalActions.first;
        expect(engine.applyManual(action), 0);
      }
      final year = engine.readNative((bridge, pointer) => bridge.year(pointer));
      final trick = engine.readNative(
        (bridge, pointer) => bridge.trickCount(pointer),
      );
      fail(
        'Tutorial year $expectedYear did not reach requisition '
        '(year $year, phase ${engine.phase}, trick $trick, '
        '${engine.legalActions.length} legal actions)',
      );
    }

    expect(engine.isTutorial, isTrue);

    advanceToRequisition(1);
    for (var suit = 0; suit < 4; suit += 1) {
      expect(
        engine.readNative(
          (bridge, pointer) => bridge.claimedJob(pointer, suit),
        ),
        isTrue,
        reason: 'Every Year 1 job should be completed',
      );
    }

    expect(engine.applyManual(engine.legalActions.single), 0);
    advanceToRequisition(2);
    for (var suit = 0; suit < 3; suit += 1) {
      expect(
        engine.readNative(
          (bridge, pointer) => bridge.claimedJob(pointer, suit),
        ),
        isTrue,
      );
    }
    expect(
      engine.readNative((bridge, pointer) => bridge.claimedJob(pointer, 3)),
      isFalse,
    );
    expect(
      engine.legalActions.any(
        (action) =>
            action.kind == kcActionSelectRequisitionCard &&
            action.playerID == 0 &&
            action.card.suit == 3 &&
            action.card.value == 13,
      ),
      isTrue,
      reason: 'Year 2 should make the learner nominate the Beet King',
    );
    while (engine.phase == kcPhaseRequisition &&
        engine.legalActions.any(
          (action) => action.kind == kcActionSelectRequisitionCard,
        )) {
      expect(engine.applyManual(engine.legalActions.first), 0);
    }
    expect(
      engine.readNative(
        (bridge, pointer) => [
          for (
            var index = 0;
            index < bridge.plotRevealedCount(pointer, 0);
            index += 1
          )
            bridge.plotRevealedCard(pointer, 0, index),
          for (
            var index = 0;
            index < bridge.exiledCount(pointer, 2);
            index += 1
          )
            if (bridge.exiledPlayer(pointer, 2, index) == 0)
              bridge.exiledCard(pointer, 2, index),
        ].map((card) => (card.suit, card.value)),
      ),
      contains((3, 13)),
      reason: 'The nominated Beet King should remain revealed or go North',
    );

    expect(engine.applyManual(engine.legalActions.single), 0);
    advanceToRequisition(3);
    final beetWorkers = engine.readNative(
      (bridge, pointer) => [
        for (
          var index = 0;
          index < bridge.jobBucketCount(pointer, 3);
          index += 1
        )
          bridge.jobBucketCard(pointer, 3, index),
      ],
    );
    expect(
      beetWorkers.any((card) => card.suit == 4),
      isTrue,
      reason: 'Year 3 should place the Saboteur into the failed job',
    );
    expect(
      engine.readNative((bridge, pointer) => bridge.workHours(pointer, 3)),
      greaterThanOrEqualTo(40),
      reason: 'The Saboteur should fail an otherwise completed beet job',
    );
    expect(
      engine.readNative((bridge, pointer) => bridge.claimedJob(pointer, 3)),
      isTrue,
      reason: 'The beet reward should be claimed before it is sabotaged',
    );
  });

  test('tutorial has an AI declare Year 1 trump after orientation', () {
    final bridge = KolkhozCEngineBridge();
    final engine = NativeGameEngine(
      bridge: bridge,
      seed: 20260728,
      variants: KolkhozGameVariants.kolkhoz,
      controllers: const [
        KolkhozPlayerController.human,
        KolkhozPlayerController.heuristicAI,
        KolkhozPlayerController.heuristicAI,
        KolkhozPlayerController.heuristicAI,
      ],
      tutorial: true,
    );
    addTearDown(engine.dispose);

    expect(
      engine.legalActions.single.kind,
      kcActionCompleteTutorialOrientation,
    );
    expect(engine.applyManual(engine.legalActions.single), 0);
    expect(
      engine.readNative((bridge, pointer) => bridge.currentPlayer(pointer)),
      1,
      reason: 'The first AI seat should be the Year 1 central planner',
    );
    expect(
      engine.legalActions.map((action) => action.kind),
      everyElement(kcActionRevealReward),
    );
    expect(
      engine.legalActions.map((action) => action.playerID),
      everyElement(1),
    );

    for (var step = 0; step < 4; step += 1) {
      expect(engine.stepAutomatic(), greaterThan(0));
    }

    expect(
      [
        for (var suit = 0; suit < 4; suit += 1)
          engine.readNative(
            (bridge, pointer) => bridge.revealedJobCard(pointer, suit).value,
          ),
      ],
      [2, 5, 1, 4],
      reason: 'Year 1 should introduce rewards with visibly different values',
    );
    expect(engine.phase, kcPhasePlanning);
    expect(
      engine.readNative((bridge, pointer) => bridge.trump(pointer)),
      -1,
      reason: 'Trump should remain unset while the reward lesson is visible',
    );
    expect(
      engine.readNative((bridge, pointer) => bridge.currentPlayer(pointer)),
      0,
      reason: 'The tutorial should pause for the learner after rewards reveal',
    );
    expect(
      engine.legalActions.single.kind,
      kcActionCompleteTutorialRewardLesson,
    );

    expect(engine.applyManual(engine.legalActions.single), 0);
    expect(
      engine.readNative((bridge, pointer) => bridge.currentPlayer(pointer)),
      1,
      reason: 'The AI central planner should resume after the reward lesson',
    );
    expect(engine.stepAutomatic(), greaterThan(0));
    expect(
      engine.readNative((bridge, pointer) => bridge.trump(pointer)),
      0,
      reason: 'The scripted AI should declare wheat as Year 1 trump',
    );
    expect(engine.phase, kcPhaseTrick);
  });

  test('learner wins Year 1 trick three and assigns it manually', () {
    final bridge = KolkhozCEngineBridge();
    final engine = NativeGameEngine(
      bridge: bridge,
      seed: 20260728,
      variants: KolkhozGameVariants.kolkhoz,
      controllers: const [
        KolkhozPlayerController.human,
        KolkhozPlayerController.heuristicAI,
        KolkhozPlayerController.heuristicAI,
        KolkhozPlayerController.heuristicAI,
      ],
      tutorial: true,
    );
    addTearDown(engine.dispose);

    expect(engine.applyManual(engine.legalActions.single), 0);
    for (var actionCount = 0; actionCount < 100; actionCount += 1) {
      final trickCount = engine.readNative(
        (bridge, pointer) => bridge.trickCount(pointer),
      );
      if (engine.phase == kcPhaseAssignment && trickCount == 3) {
        break;
      }

      final currentPlayer = engine.readNative(
        (bridge, pointer) => bridge.currentPlayer(pointer),
      );
      if (currentPlayer == 0 && engine.legalActions.isNotEmpty) {
        expect(engine.applyManual(engine.legalActions.first), 0);
      } else {
        expect(engine.stepAutomatic(), greaterThan(0));
      }
    }

    expect(engine.phase, kcPhaseAssignment);
    expect(
      engine.readNative((bridge, pointer) => bridge.trickCount(pointer)),
      3,
    );
    expect(engine.lastWinner, 0);
    expect(
      engine.readNative((bridge, pointer) => bridge.currentPlayer(pointer)),
      0,
    );
    final learnerPlay = engine
        .readNative(
          (bridge, pointer) => [
            for (
              var index = 0;
              index < bridge.lastTrickCount(pointer);
              index += 1
            )
              (
                player: bridge.lastTrickPlayer(pointer, index),
                card: bridge.lastTrickCard(pointer, index),
              ),
          ],
        )
        .singleWhere((play) => play.player == 0);
    expect((learnerPlay.card.suit, learnerPlay.card.value), (2, 13));

    final assignments = engine.legalActions
        .where((action) => action.kind == kcActionAssign)
        .toList();
    expect(assignments, hasLength(4));
    expect(assignments.map((action) => action.playerID), everyElement(0));
    expect(assignments.map((action) => action.targetSuit), everyElement(2));
    expect(
      engine.legalActions.where(
        (action) => action.kind == kcActionSubmitAssignments,
      ),
      isEmpty,
      reason: 'The learner should place the cards before submitting them',
    );
  });

  test('Year 2 turns the Beet King swap into two mixed-suit wins', () {
    final bridge = KolkhozCEngineBridge();
    final engine = NativeGameEngine(
      bridge: bridge,
      seed: 20260728,
      variants: KolkhozGameVariants.kolkhoz,
      controllers: const [
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
      ],
      tutorial: true,
    );
    addTearDown(engine.dispose);

    var checkedSwap = false;
    var checkedFirstMixedAssignment = false;
    var checkedSecondMixedAssignment = false;
    for (var actionCount = 0; actionCount < 500; actionCount += 1) {
      final year = engine.readNative((bridge, pointer) => bridge.year(pointer));
      final trick = engine.readNative(
        (bridge, pointer) => bridge.trickCount(pointer),
      );

      if (year == 2 &&
          engine.phase == kcPhaseSwap &&
          engine.currentPlayer == 0 &&
          !checkedSwap) {
        checkedSwap = true;
        final swaps = engine.legalActions
            .where((action) => action.kind == kcActionSwap)
            .toList();
        expect(swaps, hasLength(1));
        expect(
          (swaps.single.handCard.suit, swaps.single.handCard.value),
          (3, 13),
        );
        expect(
          (swaps.single.plotCard.suit, swaps.single.plotCard.value),
          (0, 10),
        );
        expect(
          engine.legalActions.where(
            (action) => action.kind == kcActionConfirmSwap,
          ),
          isEmpty,
          reason: 'The teaching swap should happen before confirmation',
        );
      }

      if (year == 2 &&
          engine.phase == kcPhaseAssignment &&
          trick == 2 &&
          !checkedFirstMixedAssignment) {
        checkedFirstMixedAssignment = true;
        expect(engine.lastWinner, 0);
        final assignments = engine.legalActions
            .where((action) => action.kind == kcActionAssign)
            .toList();
        expect(assignments, hasLength(4));
        expect(
          assignments
              .map((action) => (action.card.suit, action.targetSuit))
              .toSet(),
          {(0, 0), (3, 3)},
          reason: 'The first trump win should split Wheat from Beet workers',
        );
      }

      if (year == 2 &&
          engine.phase == kcPhaseAssignment &&
          trick == 4 &&
          !checkedSecondMixedAssignment) {
        checkedSecondMixedAssignment = true;
        expect(engine.lastWinner, 0);
        final assignments = engine.legalActions
            .where((action) => action.kind == kcActionAssign)
            .toList();
        expect(assignments, hasLength(4));
        expect(
          assignments.map((action) => action.targetSuit),
          everyElement(0),
          reason: 'The second mixed trick should all be directed to Wheat',
        );
      }

      if (year == 2 &&
          engine.phase == kcPhaseRequisition &&
          engine.legalActions.isNotEmpty) {
        break;
      }
      if (engine.phase == kcPhaseRequisition && engine.legalActions.isEmpty) {
        expect(engine.stepAutomatic(), greaterThan(0));
        continue;
      }
      final action = engine.heuristicAction() ?? engine.legalActions.first;
      expect(engine.applyManual(action), 0);
    }

    expect(checkedSwap, isTrue);
    expect(checkedFirstMixedAssignment, isTrue);
    expect(checkedSecondMixedAssignment, isTrue);
    expect(
      engine.legalActions.any(
        (action) =>
            action.kind == kcActionSelectRequisitionCard &&
            action.playerID == 0 &&
            action.card.suit == 3 &&
            action.card.value == 13,
      ),
      isTrue,
    );
  });

  test('tutorial teaches both Saboteur wild-card rules in Year 3', () {
    final bridge = KolkhozCEngineBridge();
    final engine = NativeGameEngine(
      bridge: bridge,
      seed: 20260728,
      variants: KolkhozGameVariants.kolkhoz,
      controllers: const [
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
        KolkhozPlayerController.human,
      ],
      tutorial: true,
    );
    addTearDown(engine.dispose);

    var checkedCompletedBeets = false;
    var checkedForcedFollow = false;
    var checkedFollowLessonPause = false;
    var checkedWildAssignment = false;
    var checkedYearThreeTrump = false;
    for (var actionCount = 0; actionCount < 700; actionCount += 1) {
      final year = engine.readNative((bridge, pointer) => bridge.year(pointer));
      final trick = engine.readNative(
        (bridge, pointer) => bridge.trickCount(pointer),
      );

      if (year == 3 && !checkedYearThreeTrump) {
        final trump = engine.readNative(
          (bridge, pointer) => bridge.trump(pointer),
        );
        if (trump >= 0) {
          checkedYearThreeTrump = true;
          expect(trump, 1, reason: 'Year 3 should switch to Sunflower trump');
        }
      }

      if (year == 3 &&
          !checkedCompletedBeets &&
          engine.readNative(
            (bridge, pointer) => bridge.claimedJob(pointer, 3),
          )) {
        checkedCompletedBeets = true;
        expect(
          engine.readNative((bridge, pointer) => bridge.workHours(pointer, 3)),
          greaterThanOrEqualTo(40),
        );
        expect(
          engine.readNative(
            (bridge, pointer) => [
              for (
                var index = 0;
                index < bridge.jobBucketCount(pointer, 3);
                index += 1
              )
                bridge.jobBucketCard(pointer, 3, index).suit,
            ],
          ),
          contains(4),
          reason: 'Beets should complete after already receiving the Saboteur',
        );
      }

      if (year == 3 && engine.phase == kcPhaseTrick && trick == 0) {
        final currentPlayer = engine.readNative(
          (bridge, pointer) => bridge.currentPlayer(pointer),
        );
        if (currentPlayer == 0 && !checkedForcedFollow) {
          checkedForcedFollow = true;
          final plays = engine.legalActions
              .where((action) => action.kind == kcActionPlayCard)
              .toList();
          expect(plays, hasLength(1));
          expect(plays.single.card.suit, 4);
          expect(
            engine.readNative(
              (bridge, pointer) => [
                for (
                  var index = 0;
                  index < bridge.currentTrickCount(pointer);
                  index += 1
                )
                  (
                    bridge.currentTrickPlayer(pointer, index),
                    bridge.currentTrickCard(pointer, index).suit,
                  ),
              ],
            ),
            [(3, 0)],
            reason: 'The AI should lead Wheat before the forced Saboteur',
          );
        }
        if (engine.legalActions.length == 1 &&
            engine.legalActions.single.kind ==
                kcActionCompleteTutorialSaboteurFollowLesson) {
          checkedFollowLessonPause = true;
          expect(
            engine.readNative(
              (bridge, pointer) => bridge.currentTrickCard(pointer, 1).suit,
            ),
            4,
          );
        }
      }

      if (year == 3 &&
          engine.phase == kcPhaseAssignment &&
          trick == 1 &&
          !checkedWildAssignment) {
        checkedWildAssignment = true;
        expect(
          engine.lastWinner,
          1,
          reason: 'The next AI should win with the higher Sunflower trump',
        );
        final capturedSuits = engine.readNative(
          (bridge, pointer) => [
            for (
              var index = 0;
              index < bridge.lastTrickCount(pointer);
              index += 1
            )
              bridge.lastTrickCard(pointer, index).suit,
          ],
        );
        expect(capturedSuits, contains(4));
        expect(
          capturedSuits,
          isNot(contains(3)),
          reason: 'No beet-suit card should make beets a normal target',
        );
        expect(
          engine.legalActions
              .where((action) => action.kind == kcActionAssign)
              .map((action) => action.targetSuit),
          everyElement(3),
          reason: 'The Saboteur should make beets legal for every card',
        );
      }

      if (year == 3 &&
          engine.phase == kcPhaseRequisition &&
          engine.legalActions.isNotEmpty) {
        break;
      }
      if (engine.phase == kcPhaseRequisition && engine.legalActions.isEmpty) {
        engine.stepAutomatic();
        continue;
      }
      final actions = engine.legalActions;
      expect(actions, isNotEmpty);
      expect(engine.applyManual(engine.heuristicAction() ?? actions.first), 0);
    }

    expect(checkedCompletedBeets, isTrue);
    expect(checkedForcedFollow, isTrue);
    expect(checkedFollowLessonPause, isTrue);
    expect(checkedWildAssignment, isTrue);
    expect(checkedYearThreeTrump, isTrue);
    expect(
      engine.readNative((bridge, pointer) => bridge.workHours(pointer, 3)),
      greaterThanOrEqualTo(40),
    );
    expect(
      engine.readNative(
        (bridge, pointer) => [
          for (
            var index = 0;
            index < bridge.jobBucketCount(pointer, 3);
            index += 1
          )
            bridge.jobBucketCard(pointer, 3, index).suit,
        ],
      ),
      contains(4),
    );
  });

  test('tutorial outcomes survive opposite legal player branches', () {
    for (final chooseLast in [false, true]) {
      final bridge = KolkhozCEngineBridge();
      final engine = NativeGameEngine(
        bridge: bridge,
        seed: chooseLast ? 2 : 1,
        variants: KolkhozGameVariants.kolkhoz,
        controllers: const [
          KolkhozPlayerController.human,
          KolkhozPlayerController.human,
          KolkhozPlayerController.human,
          KolkhozPlayerController.human,
        ],
        tutorial: true,
      );
      addTearDown(engine.dispose);

      var checkedYearOne = false;
      var checkedYearTwo = false;
      var checkedYearThree = false;
      for (var actionCount = 0; actionCount < 600; actionCount += 1) {
        final year = engine.readNative(
          (bridge, pointer) => bridge.year(pointer),
        );
        if (engine.phase == kcPhaseRequisition && engine.legalActions.isEmpty) {
          engine.stepAutomatic();
          continue;
        }
        if (engine.phase == kcPhaseRequisition &&
            engine.legalActions.isNotEmpty) {
          if (year == 1 && !checkedYearOne) {
            checkedYearOne = true;
            expect([
              for (var suit = 0; suit < 4; suit += 1)
                engine.readNative(
                  (bridge, pointer) => bridge.claimedJob(pointer, suit),
                ),
            ], everyElement(isTrue));
          } else if (year == 2 && !checkedYearTwo) {
            checkedYearTwo = true;
            expect(
              engine.readNative(
                (bridge, pointer) => bridge.claimedJob(pointer, 3),
              ),
              isFalse,
            );
            expect(
              engine.legalActions.any(
                (action) =>
                    action.kind == kcActionSelectRequisitionCard &&
                    action.playerID == 0,
              ),
              isTrue,
            );
          } else if (year == 3 && !checkedYearThree) {
            checkedYearThree = true;
            expect(
              engine.readNative(
                (bridge, pointer) => [
                  for (
                    var index = 0;
                    index < bridge.jobBucketCount(pointer, 3);
                    index += 1
                  )
                    bridge.jobBucketCard(pointer, 3, index).suit,
                ],
              ),
              contains(4),
            );
          }
          if (year == 3) break;
        }
        final actions = engine.legalActions;
        expect(
          actions,
          isNotEmpty,
          reason: 'branch=$chooseLast year=$year phase=${engine.phase}',
        );
        final action = chooseLast ? actions.last : actions.first;
        expect(engine.applyManual(action), 0);
      }
      expect(checkedYearOne, isTrue);
      expect(checkedYearTwo, isTrue);
      expect(checkedYearThree, isTrue);
    }
  });

  test('tutorial always runs through Year 5 before ending', () {
    for (final chooseLast in [false, true]) {
      final bridge = KolkhozCEngineBridge();
      final engine = NativeGameEngine(
        bridge: bridge,
        seed: chooseLast ? 20260729 : 20260728,
        variants: KolkhozGameVariants.kolkhoz,
        controllers: const [
          KolkhozPlayerController.human,
          KolkhozPlayerController.human,
          KolkhozPlayerController.human,
          KolkhozPlayerController.human,
        ],
        tutorial: true,
      );
      addTearDown(engine.dispose);

      var reachedGameOver = false;
      for (var actionCount = 0; actionCount < 1400; actionCount += 1) {
        if (engine.phase == kcPhaseGameOver) {
          reachedGameOver = true;
          break;
        }
        final actions = engine.legalActions;
        if (actions.isEmpty) {
          expect(
            engine.stepAutomatic(),
            greaterThanOrEqualTo(0),
            reason:
                'branch=$chooseLast year=${engine.readNative((bridge, pointer) => bridge.year(pointer))} phase=${engine.phase}',
          );
          continue;
        }
        final action = actions.firstWhere(
          (action) => action.kind == kcActionConfirmSwap,
          orElse: () =>
              engine.heuristicAction() ??
              (chooseLast ? actions.last : actions.first),
        );
        expect(engine.applyManual(action), 0);
      }

      expect(
        reachedGameOver,
        isTrue,
        reason:
            'branch=$chooseLast year=${engine.readNative((bridge, pointer) => bridge.year(pointer))} phase=${engine.phase} legal=${engine.legalActions.length}',
      );
      expect(engine.readNative((bridge, pointer) => bridge.year(pointer)), 5);
    }
  });

  test('tutorial guarantees the learner a real-trump famine sweep', () {
    for (final chooseLast in [false, true]) {
      final bridge = KolkhozCEngineBridge();
      final engine = NativeGameEngine(
        bridge: bridge,
        seed: chooseLast ? 20260731 : 20260730,
        variants: KolkhozGameVariants.kolkhoz,
        controllers: const [
          KolkhozPlayerController.human,
          KolkhozPlayerController.human,
          KolkhozPlayerController.human,
          KolkhozPlayerController.human,
        ],
        tutorial: true,
      );
      addTearDown(engine.dispose);

      for (var actionCount = 0; actionCount < 1400; actionCount += 1) {
        final year = engine.readNative(
          (bridge, pointer) => bridge.year(pointer),
        );
        if (year == 5 && engine.phase == kcPhaseSwap) {
          break;
        }
        final actions = engine.legalActions;
        if (actions.isEmpty) {
          expect(engine.stepAutomatic(), greaterThanOrEqualTo(0));
          continue;
        }
        final action = actions.firstWhere(
          (action) => action.kind == kcActionConfirmSwap,
          orElse: () => chooseLast ? actions.last : actions.first,
        );
        expect(engine.applyManual(action), 0);
      }

      expect(engine.readNative((bridge, pointer) => bridge.year(pointer)), 5);
      expect(engine.phase, kcPhaseSwap);
      final trumpSuit = engine.readNative(
        (bridge, pointer) => bridge.finalYearTrumpCard(pointer).suit,
      );
      expect(trumpSuit, inInclusiveRange(0, 3));

      final learnerCards = engine.readNative(
        (bridge, pointer) => [
          for (var index = 0; index < bridge.handCount(pointer, 0); index += 1)
            bridge.handCard(pointer, 0, index),
        ],
      );
      expect(learnerCards, hasLength(4));
      expect(
        learnerCards.where((card) => card.suit == trumpSuit),
        hasLength(2),
      );
      expect(
        learnerCards
            .where((card) => card.suit != trumpSuit)
            .map((card) => card.suit),
        hasLength(2),
      );
      expect(
        learnerCards
            .where((card) => card.suit != trumpSuit)
            .map((card) => card.suit)
            .toSet(),
        hasLength(2),
      );
      final swapActions = engine.legalActions
          .where((action) => action.kind == kcActionSwap)
          .toList();
      expect(swapActions, hasLength(1));
      final swap = swapActions.single;
      expect(swap.handCard.suit, isNot(trumpSuit));
      expect(swap.plotCard.suit, isNot(trumpSuit));
      expect(swap.handCard.suit, isNot(swap.plotCard.suit));
      expect(
        engine.legalActions.where(
          (action) => action.kind == kcActionConfirmSwap,
        ),
        isEmpty,
      );
      expect(engine.applyManual(swap), 0);

      final preparedCards = engine.readNative(
        (bridge, pointer) => [
          for (var index = 0; index < bridge.handCount(pointer, 0); index += 1)
            bridge.handCard(pointer, 0, index),
        ],
      );
      expect(
        preparedCards.where((card) => card.suit == trumpSuit),
        hasLength(2),
      );
      final preparedOffSuits = preparedCards
          .where((card) => card.suit != trumpSuit)
          .map((card) => card.suit)
          .toSet();
      expect(preparedOffSuits, hasLength(1));
      final weakestLearnerTrump = preparedCards
          .where((card) => card.suit == trumpSuit)
          .map((card) => card.value)
          .reduce((left, right) => left < right ? left : right);
      final opponentTrumpValues = engine.readNative(
        (bridge, pointer) => [
          for (var playerID = 1; playerID < 4; playerID += 1)
            for (
              var index = 0;
              index < bridge.handCount(pointer, playerID);
              index += 1
            )
              if (bridge.handCard(pointer, playerID, index).suit == trumpSuit)
                bridge.handCard(pointer, playerID, index).value,
        ],
      );
      expect(
        opponentTrumpValues.every((value) => value < weakestLearnerTrump),
        isTrue,
      );

      final checkedTricks = <int>{};
      for (var actionCount = 0; actionCount < 300; actionCount += 1) {
        if (engine.phase == kcPhaseRequisition) {
          break;
        }
        final trickCount = engine.readNative(
          (bridge, pointer) => bridge.trickCount(pointer),
        );
        if (engine.phase == kcPhaseAssignment &&
            checkedTricks.add(trickCount)) {
          final plays = engine.readNative(
            (bridge, pointer) => [
              for (
                var index = 0;
                index < bridge.lastTrickCount(pointer);
                index += 1
              )
                (
                  player: bridge.lastTrickPlayer(pointer, index),
                  card: bridge.lastTrickCard(pointer, index),
                ),
            ],
          );
          expect(
            engine.lastWinner,
            0,
            reason:
                'branch=$chooseLast trick=$trickCount plays=${plays.map((play) => (play.player, play.card.suit, play.card.value)).toList()}',
          );
          final learnerPlay = plays.singleWhere((play) => play.player == 0);
          if (trickCount == 1) {
            expect(plays.first.player, 3);
            expect(plays.first.card.suit, swap.handCard.suit);
            expect(learnerPlay.card.suit, trumpSuit);
            expect(learnerPlay.card.value, weakestLearnerTrump);
          } else if (trickCount == 2) {
            expect(learnerPlay.card.suit, trumpSuit);
            expect(plays.any((play) => play.card.suit == 4), isTrue);
          } else if (trickCount == 3) {
            expect(preparedOffSuits, contains(learnerPlay.card.suit));
          }
        }
        final actions = engine.legalActions;
        final currentHand = engine.readNative(
          (bridge, pointer) => [
            for (
              var index = 0;
              index < bridge.handCount(pointer, engine.currentPlayer);
              index += 1
            )
              (
                bridge.handCard(pointer, engine.currentPlayer, index).suit,
                bridge.handCard(pointer, engine.currentPlayer, index).value,
              ),
          ],
        );
        final currentTrick = engine.readNative(
          (bridge, pointer) => [
            for (
              var index = 0;
              index < bridge.currentTrickCount(pointer);
              index += 1
            )
              (
                bridge.currentTrickPlayer(pointer, index),
                bridge.currentTrickCard(pointer, index).suit,
                bridge.currentTrickCard(pointer, index).value,
              ),
          ],
        );
        expect(
          actions,
          isNotEmpty,
          reason:
              'branch=$chooseLast phase=${engine.phase} trick=$trickCount current=${engine.currentPlayer} hand=$currentHand currentTrick=$currentTrick off=$preparedOffSuits',
        );
        final action = actions.firstWhere(
          (action) => action.kind == kcActionConfirmSwap,
          orElse: () => chooseLast ? actions.last : actions.first,
        );
        expect(engine.applyManual(action), 0);
      }

      expect(engine.phase, kcPhaseRequisition);
      expect(checkedTricks, containsAll({1, 2}));
      expect(engine.lastWinner, 0);
      final closingLearnerCard = engine.readNative(
        (bridge, pointer) => [
          for (
            var index = 0;
            index < bridge.lastTrickCount(pointer);
            index += 1
          )
            if (bridge.lastTrickPlayer(pointer, index) == 0)
              bridge.lastTrickCard(pointer, index),
        ].single,
      );
      expect(
        preparedOffSuits,
        contains(closingLearnerCard.suit),
        reason:
            'branch=$chooseLast trump=$trumpSuit prepared=${preparedCards.map((card) => (card.suit, card.value)).toList()} closing=(${closingLearnerCard.suit}, ${closingLearnerCard.value})',
      );
      expect(
        engine.readNative((bridge, pointer) => bridge.playerMedals(pointer, 0)),
        3,
      );
      while (engine.phase == kcPhaseRequisition &&
          engine.legalActions.isEmpty) {
        expect(engine.stepAutomatic(), greaterThan(0));
      }
      final heroResolutionPlayers = engine.readNative(
        (bridge, pointer) => [
          for (
            var index = 0;
            index < bridge.requisitionEventCount(pointer);
            index += 1
          )
            if (const {
              4,
              5,
            }.contains(bridge.requisitionEventMessageKind(pointer, index)))
              bridge.requisitionEventPlayer(pointer, index),
        ],
      );
      expect(heroResolutionPlayers, [0]);
    }
  });
}
