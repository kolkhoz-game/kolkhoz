import 'dart:async';
import 'dart:math' as math;

import 'package:kolkhoz_app/src/app/settings/animation_speed.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_engine.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_lobby.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_action_codec.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_action_projection.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_ui_state.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/players/player.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import '../game_commands.dart';
import 'local_game_projection.dart';
import 'native_game_engine.dart';

class LocalGameEngine implements GameEngine {
  LocalGameEngine({
    required this.engine,
    required this.players,
    required this.lobby,
    required this.animationSpeed,
    required this.uiState,
    required this.setUiState,
    required this.revealedPlayerID,
    required this.setRevealedPlayerID,
    required this.lastSyncedPhase,
    required this.setLastSyncedPhase,
    required this.onGameUpdate,
    required this.onStateChanged,
    required this.onError,
    required this.onPersist,
    List<EngineAction> actionLog = const [],
    List<EngineAction> gameLog = const [],
  }) : actionLog = List.of(actionLog),
       gameLog = List.of(gameLog);

  final List<GamePlayer> Function() players;
  final GameLobby Function() lobby;
  final GameAnimationSpeed Function() animationSpeed;
  final GameUiState Function() uiState;
  final void Function(GameUiState) setUiState;
  final int? Function() revealedPlayerID;
  final void Function(int?) setRevealedPlayerID;
  final String? Function() lastSyncedPhase;
  final void Function(String?) setLastSyncedPhase;
  final void Function(GameEngineUpdate) onGameUpdate;
  final void Function() onStateChanged;
  final void Function(String?) onError;
  final void Function() onPersist;

  NativeGameEngine engine;
  Timer? _automaticStepTimer;
  GameCommand? _scheduledAutomaticCommand;
  String? _automaticRewardPreviewSuit;
  final math.Random _automaticDelayRandom = math.Random();
  int? _automaticPhaseBefore;
  int _automaticRequisitionCountBefore = 0;
  bool _disposed = false;

  List<EngineAction> actionLog;
  List<EngineAction> gameLog;

  @override
  GameEngineMode get mode => GameEngineMode.local;
  @override
  bool get humanActionInFlight => false;

  bool get hasScheduledAutomaticStep => _automaticStepTimer != null;

  @override
  TableViewModel project() => projectLocalGame(
    engine: engine,
    uiState: uiState(),
    revealedPlayerID: revealedPlayerID(),
    lobby: lobby(),
  );

  @override
  void sendHumanAction(LegalAction action) {
    clearAutomaticStepTimer();
    _send(
      SubmitGameAction(
        action: action.engineAction,
        source: GameActionSource.human,
      ),
    );
  }

  @override
  void sendHumanActions(List<EngineAction> actions) {
    if (actions.isEmpty) {
      return;
    }
    clearAutomaticStepTimer();
    final rollback = engine.clone();
    final transitions = <EngineTransitionEvent>[];
    for (final action in actions) {
      final encoded = cEngineAction(action);
      final result = encoded == null ? -1 : engine.applyManual(encoded);
      if (result != 0) {
        _replaceEngine(rollback);
        onError('Move rejected ($result)');
        onStateChanged();
        return;
      }
      transitions.addAll(engine.transitionEvents);
    }
    rollback.dispose();
    actionLog = [...actionLog, ...actions];
    gameLog = [...gameLog, ...actions];
    setUiState(uiState().clearSelectionAfterAction(actions.last.kind));
    onError(null);
    onGameUpdate(
      GameEngineUpdate(action: actions.last, transitions: transitions),
    );
    onStateChanged();
    onPersist();
  }

  void rescheduleAutomaticStep() {
    final shouldResume = hasScheduledAutomaticStep;
    clearAutomaticStepTimer();
    if (shouldResume) {
      scheduleAutomaticStep();
    }
  }

  void scheduleAutomaticStep() {
    if (_automaticStepTimer != null) {
      return;
    }
    if (!_engineDecisionNeedsRouting(engine)) {
      return;
    }
    final command = _automaticCommand(engine);
    if (command == null) {
      return;
    }
    _scheduledAutomaticCommand = command;
    _automaticStepTimer = Timer(
      _automaticStepDelay(engine, command),
      _runAutomaticStep,
    );
    _showAutomaticRewardPreview(command);
  }

  void clearAutomaticStepTimer() {
    _automaticStepTimer?.cancel();
    _automaticStepTimer = null;
    _scheduledAutomaticCommand = null;
    _clearAutomaticRewardPreview(notify: !_disposed);
  }

  void _runAutomaticStep() {
    _automaticStepTimer = null;
    _automaticPhaseBefore = engine.phase;
    _automaticRequisitionCountBefore = engine.phase == kcPhaseRequisition
        ? engine.requisitionEventCount
        : 0;
    final command = _scheduledAutomaticCommand ?? _automaticCommand(engine);
    _scheduledAutomaticCommand = null;
    if (command != null) {
      _send(command);
    }
  }

  bool _engineDecisionNeedsRouting(NativeGameEngine engine) {
    final phase = engine.phase;
    final legalActions = engine.legalActions;
    if (_centralPlannerAction(legalActions) != null ||
        (phase == kcPhaseRequisition && legalActions.isEmpty) ||
        (phase == kcPhasePlanning && engine.isFamine && legalActions.isEmpty)) {
      return true;
    }
    return _decisionPlayer(engine)?.waitsForHumanInput == false;
  }

  Duration _automaticStepDelay(NativeGameEngine engine, GameCommand command) {
    if (engine.phase != kcPhasePlanning || engine.isFamine) {
      return animationSpeed().automaticStepDelay;
    }
    if (command case SubmitGameAction(:final action)) {
      if (action.kind == actionAssignReward) {
        return jitteredAutomaticRewardPlanningDelay(
          animationSpeed(),
          _automaticDelayRandom.nextDouble(),
        );
      }
      if (action.kind == actionSetTrump) {
        return animationSpeed().automaticTrumpSelectionDelay;
      }
    }
    return animationSpeed().automaticStepDelay;
  }

  void _showAutomaticRewardPreview(GameCommand command) {
    final suit = switch (command) {
      SubmitGameAction(:final action) when action.kind == actionAssignReward =>
        action.suit,
      _ => null,
    };
    if (suit == null || suit == _automaticRewardPreviewSuit) {
      return;
    }
    _automaticRewardPreviewSuit = suit;
    setUiState(
      uiState().copyWith(
        selection: uiState().selection.copyWith(planningRewardSuit: suit),
      ),
    );
    onStateChanged();
  }

  void _clearAutomaticRewardPreview({required bool notify}) {
    if (_automaticRewardPreviewSuit == null) {
      return;
    }
    _automaticRewardPreviewSuit = null;
    if (_disposed) {
      return;
    }
    setUiState(
      uiState().copyWith(
        selection: uiState().selection.copyWith(clearPlanningRewardSuit: true),
      ),
    );
    if (notify) {
      onStateChanged();
    }
  }

  GameCommand? _automaticCommand(NativeGameEngine engine) {
    final legalActions = engine.legalActions;
    final centralPlannerAction = _centralPlannerAction(legalActions);
    if (centralPlannerAction != null) {
      return SubmitGameAction(
        action: engineActionFromCValue(centralPlannerAction),
        source: GameActionSource.centralPlanner,
      );
    }
    if ((engine.phase == kcPhaseRequisition && legalActions.isEmpty) ||
        (engine.phase == kcPhasePlanning &&
            engine.isFamine &&
            legalActions.isEmpty)) {
      return const AdvanceAutomaticGame();
    }
    final action = _decisionPlayer(engine)?.chooseAction(engine);
    if (action == null) {
      return null;
    }
    return SubmitGameAction(
      action: engineActionFromCValue(action),
      source: GameActionSource.ai,
    );
  }

  CEngineActionValue? _centralPlannerAction(
    List<CEngineActionValue> legalActions,
  ) {
    if (legalActions.length != 1) {
      return null;
    }
    final action = legalActions.single;
    return action.kind == kcActionRevealReward ||
            action.kind == kcActionRevealTrump
        ? action
        : null;
  }

  LocalGamePlayer? _decisionPlayer(NativeGameEngine engine) {
    final playerID = engine.phase == kcPhaseAssignment
        ? engine.lastWinner
        : engine.currentPlayer;
    final currentPlayers = players();
    if (playerID < 0 || playerID >= currentPlayers.length) {
      return null;
    }
    final player = currentPlayers[playerID];
    return player is LocalGamePlayer ? player : null;
  }

  void _replaceEngine(NativeGameEngine nextEngine) {
    final previous = engine;
    engine = nextEngine;
    previous.dispose();
  }

  void _send(GameCommand command) {
    switch (command) {
      case SubmitGameAction():
        final action = cEngineAction(command.action);
        if (action == null) {
          _handleCommandResult(
            LocalGameCommandResult(
              command: command,
              accepted: false,
              stateChanged: false,
              errorCode: -1,
            ),
          );
          return;
        }
        final result = command.source == GameActionSource.ai
            ? engine.applyAIAction(action)
            : engine.applyManual(action);
        _handleCommandResult(
          LocalGameCommandResult(
            command: command,
            accepted: result == 0,
            stateChanged: result == 0,
            errorCode: result,
          ),
        );
      case AdvanceAutomaticGame():
        final result = engine.stepAutomatic();
        _handleCommandResult(
          LocalGameCommandResult(
            command: command,
            accepted: result >= 0,
            stateChanged: result > 0,
            errorCode: result < 0 ? -result : 0,
          ),
        );
      default:
        onError('${command.runtimeType} is not a local game command');
        onStateChanged();
    }
  }

  void _handleCommandResult(LocalGameCommandResult event) {
    final command = event.command;
    _clearAutomaticRewardPreview(notify: false);
    if (command is SubmitGameAction &&
        command.source == GameActionSource.human) {
      if (!event.accepted) {
        onError('Move rejected (${event.errorCode})');
      } else {
        onError(null);
        actionLog = [...actionLog, command.action];
        gameLog = [...gameLog, command.action];
        setUiState(uiState().clearSelectionAfterAction(command.action.kind));
      }
    } else {
      if (!event.accepted) {
        onError('Automatic move rejected (${event.errorCode})');
        onStateChanged();
        return;
      }
      if (!event.stateChanged) {
        return;
      }
      onError(null);
      if (command case SubmitGameAction(:final action)) {
        actionLog = [...actionLog, action];
        gameLog = [...gameLog, action];
      }
      if (_automaticPhaseBefore == kcPhaseRequisition &&
          engine.requisitionEventCount > _automaticRequisitionCountBefore) {
        final index = _automaticRequisitionCountBefore;
        final card = engine.requisitionEventCard(index);
        gameLog = [
          ...gameLog,
          EngineAction(
            kind: actionRequisitionEvent,
            playerID: engine.requisitionEventPlayer(index),
            suit: suitName(engine.requisitionEventSuit(index)),
            card: card.isValid
                ? EngineCard(
                    suit: suitName(card.suit) ?? wreckerSuit,
                    value: card.value,
                  )
                : null,
            requisitionKind: engine.requisitionEventMessageKind(index),
          ),
        ];
      }
    }
    _automaticPhaseBefore = null;
    _automaticRequisitionCountBefore = 0;
    if (event.stateChanged) {
      onGameUpdate(
        GameEngineUpdate(
          action: switch (command) {
            SubmitGameAction(:final action) => action,
            _ => null,
          },
          transitions: engine.transitionEvents,
        ),
      );
    }
    onStateChanged();
    if (event.stateChanged) {
      onPersist();
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    clearAutomaticStepTimer();
    engine.dispose();
  }
}
