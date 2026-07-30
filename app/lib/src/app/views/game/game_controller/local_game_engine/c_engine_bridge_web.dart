import 'dart:js_interop';

import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';

export 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';

@JS('kolkhozEngineCall')
external JSNumber _engineCall(JSString name, JSArray<JSNumber> arguments);

final class KCEngineHandle {
  const KCEngineHandle(this.address);

  final int address;
}

class KolkhozCEngineBridge {
  KCEngineHandle newEngine({
    int? seed,
    KolkhozGameVariants variants = KolkhozGameVariants.kolkhoz,
    List<KolkhozPlayerController> controllers =
        KolkhozPlayerController.defaultControllers,
    bool tutorial = false,
  }) {
    final normalized = KolkhozPlayerController.normalized(controllers);
    final address = _call('kc_web_engine_new', [
      (seed ?? DateTime.now().millisecondsSinceEpoch) & 0x7fffffff,
      tutorial ? 1 : 0,
      for (final controller in normalized) _controllerCode(controller),
    ]);
    if (address == 0) {
      throw StateError('Could not allocate the web game engine');
    }
    return KCEngineHandle(address);
  }

  KolkhozGameVariants kolkhozEngineDefaults() => KolkhozGameVariants.kolkhoz;

  void freeEngine(KCEngineHandle engine) {
    _call('kc_web_engine_free', [engine.address]);
  }

  KCEngineHandle cloneEngine(KCEngineHandle source) {
    final address = _call('kc_web_engine_clone', [source.address]);
    if (address == 0) {
      throw StateError('Could not clone the web game engine');
    }
    return KCEngineHandle(address);
  }

  int phase(KCEngineHandle engine) => _get(engine, 0);
  int year(KCEngineHandle engine) => _get(engine, 1);
  int currentPlayer(KCEngineHandle engine) => _get(engine, 2);
  int leadPlayer(KCEngineHandle engine) => _get(engine, 3);
  int trump(KCEngineHandle engine) => _get(engine, 4);
  int trickCount(KCEngineHandle engine) => _get(engine, 5);
  int lastWinner(KCEngineHandle engine) => _get(engine, 6);
  int winnerID(KCEngineHandle engine) => _get(engine, 7);
  bool isFamine(KCEngineHandle engine) => _get(engine, 8) != 0;
  bool isTutorial(KCEngineHandle engine) => _get(engine, 9) != 0;
  int visibleScore(KCEngineHandle engine, int playerID) =>
      _get(engine, 10, playerID);
  int finalScore(KCEngineHandle engine, int playerID) =>
      _get(engine, 11, playerID);
  int playerMedals(KCEngineHandle engine, int playerID) =>
      _get(engine, 12, playerID);
  int playerBankedMedals(KCEngineHandle engine, int playerID) =>
      _get(engine, 13, playerID);
  bool playerBrigadeLeader(KCEngineHandle engine, int playerID) =>
      _get(engine, 14, playerID) != 0;
  int handCount(KCEngineHandle engine, int playerID) =>
      _get(engine, 15, playerID);
  EngineCardValue handCard(KCEngineHandle engine, int playerID, int index) =>
      _card(_get(engine, 16, playerID, index));
  int plotRevealedCount(KCEngineHandle engine, int playerID) =>
      _get(engine, 17, playerID);
  EngineCardValue plotRevealedCard(
    KCEngineHandle engine,
    int playerID,
    int index,
  ) => _card(_get(engine, 18, playerID, index));
  int plotHiddenCount(KCEngineHandle engine, int playerID) =>
      _get(engine, 19, playerID);
  EngineCardValue plotHiddenCard(
    KCEngineHandle engine,
    int playerID,
    int index,
  ) => _card(_get(engine, 20, playerID, index));
  int plotStackCount(KCEngineHandle engine, int playerID) =>
      _get(engine, 21, playerID);
  int plotStackRevealedCount(
    KCEngineHandle engine,
    int playerID,
    int stackIndex,
  ) => _get(engine, 22, playerID, stackIndex);
  EngineCardValue plotStackRevealedCard(
    KCEngineHandle engine,
    int playerID,
    int stackIndex,
    int cardIndex,
  ) => _card(_get(engine, 23, playerID, stackIndex, cardIndex));
  int plotStackHiddenCount(
    KCEngineHandle engine,
    int playerID,
    int stackIndex,
  ) => _get(engine, 24, playerID, stackIndex);
  EngineCardValue plotStackHiddenCard(
    KCEngineHandle engine,
    int playerID,
    int stackIndex,
    int cardIndex,
  ) => _card(_get(engine, 25, playerID, stackIndex, cardIndex));
  bool hasRevealedJob(KCEngineHandle engine, int suit) =>
      _get(engine, 26, suit) != 0;
  EngineCardValue revealedJobCard(KCEngineHandle engine, int suit) =>
      _card(_get(engine, 27, suit));
  bool claimedJob(KCEngineHandle engine, int suit) =>
      _get(engine, 28, suit) != 0;
  int workHours(KCEngineHandle engine, int suit) => _get(engine, 29, suit);
  int jobBucketCount(KCEngineHandle engine, int suit) => _get(engine, 30, suit);
  EngineCardValue jobBucketCard(KCEngineHandle engine, int suit, int index) =>
      _card(_get(engine, 31, suit, index));
  int jobBucketTrick(KCEngineHandle engine, int suit, int index) =>
      _get(engine, 32, suit, index);
  int currentTrickCount(KCEngineHandle engine) => _get(engine, 33);
  int currentTrickWinner(KCEngineHandle engine) => _get(engine, 34);
  int currentTrickPlayer(KCEngineHandle engine, int index) =>
      _get(engine, 35, index);
  EngineCardValue currentTrickCard(KCEngineHandle engine, int index) =>
      _card(_get(engine, 36, index));
  int lastTrickCount(KCEngineHandle engine) => _get(engine, 37);
  int lastTrickPlayer(KCEngineHandle engine, int index) =>
      _get(engine, 38, index);
  EngineCardValue lastTrickCard(KCEngineHandle engine, int index) =>
      _card(_get(engine, 39, index));
  int pendingAssignmentTarget(KCEngineHandle engine, int index) =>
      _get(engine, 40, index);
  int exiledCount(KCEngineHandle engine, int year) => _get(engine, 41, year);
  EngineCardValue exiledCard(KCEngineHandle engine, int year, int index) =>
      _card(_get(engine, 42, year, index));
  int exiledPlayer(KCEngineHandle engine, int year, int index) =>
      _get(engine, 43, year, index);
  int requisitionEventCount(KCEngineHandle engine) => _get(engine, 44);
  int requisitionEventPlayer(KCEngineHandle engine, int index) =>
      _get(engine, 45, index);
  int requisitionEventSuit(KCEngineHandle engine, int index) =>
      _get(engine, 46, index);
  EngineCardValue requisitionEventCard(KCEngineHandle engine, int index) =>
      _card(_get(engine, 47, index));
  int requisitionEventMessageKind(KCEngineHandle engine, int index) =>
      _get(engine, 48, index);

  List<EngineTransitionEvent> transitionEvents(KCEngineHandle engine) => [
    for (var index = 0; index < _get(engine, 49); index += 1)
      EngineTransitionEvent(
        kind: _get(engine, 50, index),
        playerID: _get(engine, 51, index),
        card: _card(_get(engine, 52, index)),
        fromZone: _get(engine, 53, index),
        toZone: _get(engine, 54, index),
        fromOwner: _get(engine, 55, index),
        toOwner: _get(engine, 56, index),
        targetSuit: _get(engine, 57, index),
        trickWinnerID: _get(engine, 58, index),
      ),
  ];

  bool swapCount(KCEngineHandle engine, int playerID) =>
      _get(engine, 59, playerID) != 0;
  bool swapConfirmed(KCEngineHandle engine, int playerID) =>
      _get(engine, 60, playerID) != 0;
  bool passConfirmed(KCEngineHandle engine, int playerID) =>
      _get(engine, 61, playerID) != 0;
  EngineCardValue finalYearTrumpCard(KCEngineHandle engine) =>
      _card(_get(engine, 62));

  List<CEngineActionValue> legalActions(KCEngineHandle engine) => [
    for (var index = 0; index < _get(engine, 63); index += 1)
      CEngineActionValue(
        kind: _get(engine, 64, index),
        playerID: _get(engine, 65, index),
        suit: _get(engine, 66, index),
        card: _card(_get(engine, 67, index)),
        handCard: _card(_get(engine, 68, index)),
        plotCard: _card(_get(engine, 69, index)),
        plotZone: _get(engine, 70, index),
        targetSuit: _get(engine, 71, index),
      ),
  ];

  int apply(KCEngineHandle engine, CEngineActionValue action) =>
      _apply(engine, action, 0);
  int applyManual(KCEngineHandle engine, CEngineActionValue action) =>
      _apply(engine, action, 1);
  int applyAIAction(KCEngineHandle engine, CEngineActionValue action) =>
      _apply(engine, action, 2);
  int applyPolicyAction(KCEngineHandle engine, CEngineActionValue action) =>
      applyAIAction(engine, action);

  int stepAutomatic(KCEngineHandle engine) =>
      _call('kc_web_engine_step_automatic', [engine.address]);

  CEngineActionValue? heuristicAction(KCEngineHandle engine) {
    if (_call('kc_web_engine_heuristic_action', [engine.address]) == 0) {
      return null;
    }
    return CEngineActionValue(
      kind: _selected(0),
      playerID: _selected(1),
      suit: _selected(2),
      card: _card(_selected(3)),
      handCard: _card(_selected(4)),
      plotCard: _card(_selected(5)),
      plotZone: _selected(6),
      targetSuit: _selected(7),
    );
  }

  CEngineActionValue? policyAction(
    KCEngineHandle engine,
    Object model, [
    Object? workspace,
  ]) => heuristicAction(engine);

  int stepPolicyAutomatic(KCEngineHandle engine, Object model) =>
      stepAutomatic(engine);

  Object allocPolicyWorkspace(Object model) => model;
  void freePolicyWorkspace(Object workspace) {}

  int _apply(KCEngineHandle engine, CEngineActionValue action, int mode) =>
      _call('kc_web_engine_apply', [
        engine.address,
        mode,
        action.kind,
        action.playerID,
        action.suit,
        action.card.suit,
        action.card.value,
        action.handCard.suit,
        action.handCard.value,
        action.plotCard.suit,
        action.plotCard.value,
        action.plotZone,
        action.targetSuit,
      ]);

  int _get(
    KCEngineHandle engine,
    int field, [
    int a = 0,
    int b = 0,
    int c = 0,
  ]) => _call('kc_web_engine_get', [engine.address, field, a, b, c]);

  int _selected(int field) => _call('kc_web_selected_action_get', [field]);

  int _controllerCode(KolkhozPlayerController controller) {
    return switch (controller) {
      KolkhozPlayerController.human => kcControllerExternal,
      KolkhozPlayerController.heuristicAI => kcControllerHeuristicAI,
      KolkhozPlayerController.mediumAI => kcControllerPolicyAI,
      KolkhozPlayerController.neuralAI => kcControllerPolicyAI,
    };
  }

  EngineCardValue _card(int packed) {
    final encodedSuit = (packed >> 8) & 0xff;
    final encodedValue = packed & 0xff;
    return EngineCardValue(
      suit: encodedSuit - 2,
      value: encodedValue >= 128 ? encodedValue - 256 : encodedValue,
    );
  }

  int _call(String name, List<int> arguments) {
    final jsArguments = [for (final value in arguments) value.toJS].toJS;
    return _engineCall(name.toJS, jsArguments).toDartDouble.toInt();
  }
}
