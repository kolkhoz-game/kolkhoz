import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'package:kolkhoz_app/src/app/views/game/game_controller/game_presentation_transition.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';

enum GameSoundCue {
  cardPlay('audio/card_play.wav', 0.55),
  trickWin('audio/trick_win.wav', 0.65),
  assignment('audio/assignment.wav', 0.5),
  requisition('audio/requisition.wav', 0.65),
  yearStart('audio/year_start.wav', 0.55),
  gameOver('audio/game_over.wav', 0.7);

  const GameSoundCue(this.assetPath, this.volume);

  final String assetPath;
  final double volume;
}

GameSoundCue? gameSoundCueForTransition({
  required GamePresentationTransition transition,
}) {
  final previous = transition.before;
  final next = transition.after;
  if (next.table.phase == phaseGameOver &&
      previous.table.phase != phaseGameOver) {
    return GameSoundCue.gameOver;
  }
  if (next.table.year > previous.table.year) {
    return GameSoundCue.yearStart;
  }
  if (next.table.phase == phaseRequisition &&
      previous.table.phase != phaseRequisition) {
    return GameSoundCue.requisition;
  }
  if (next.table.phase == phaseAssignment &&
      previous.table.phase != phaseAssignment) {
    return GameSoundCue.trickWin;
  }
  final event = transition.event;
  if (event?.kind == kcTransitionCardMoved &&
      event?.toZone == kcObjectZoneCurrentTrick) {
    return GameSoundCue.cardPlay;
  }
  if (previous.table.phase == phaseAssignment &&
      next.table.phase != phaseAssignment) {
    return GameSoundCue.assignment;
  }
  return null;
}

GameSoundCue? gameSoundCueWithVoiceOverride(
  GameSoundCue? cue,
  String? voiceAsset,
) {
  return cue == GameSoundCue.cardPlay && voiceAsset != null ? null : cue;
}

List<String> assignmentWorkAssetsForTransition({
  required GamePresentationTransition transition,
}) {
  if (transition.assignmentTargets.isEmpty) {
    return const [];
  }
  final targetSuit = transition.assignmentTargets.values.first;
  final assets = <String>['audio/assignment_$targetSuit.wav'];
  if (transition.assignmentCardIDs.any(
    (cardID) => cardID.startsWith('$wreckerSuit-'),
  )) {
    assets.add('audio/assignment_saboteur.wav');
  }
  return assets;
}

String? faceCardVoiceAssetForTransition({
  required GamePresentationTransition transition,
}) {
  final event = transition.event;
  if (event == null ||
      event.kind != kcTransitionCardMoved ||
      event.toZone != kcObjectZoneCurrentTrick ||
      !event.card.isValid) {
    return null;
  }
  final suit = engineSuitName(event.card.suit) ?? wreckerSuit;
  final value = event.card.value;
  final playerID = event.playerID;
  if (suit == wreckerSuit) {
    final variant = (transition.after.table.year + playerID).isEven
        ? 'wrench'
        : 'any-crop';
    return 'audio/voice_lines/saboteur-$variant.wav';
  }
  final rank = switch (value) {
    11 => 'jack',
    12 => 'queen',
    13 => 'king',
    _ => null,
  };
  if (rank == null) {
    return null;
  }
  final playedCard =
      [
            ...transition.after.table.trick.plays,
            ...transition.after.table.lastTrick.plays,
          ]
          .where(
            (play) =>
                play.seatID == playerID &&
                play.card.suit == suit &&
                play.card.value == value,
          )
          .firstOrNull;
  final prefix = playedCard?.card.nomenclature ?? false ? 'nomenklatura-' : '';
  return 'audio/voice_lines/$prefix$rank-$suit.wav';
}

class GameSoundController {
  GameSoundController({this.enabled = true});

  bool enabled;
  final List<AudioPlayer> _activePlayers = [];

  Future<void> play(GameSoundCue? cue) async {
    if (cue == null) {
      return;
    }
    await playAsset(cue.assetPath, volume: cue.volume);
  }

  Future<void> playAsset(String? assetPath, {double volume = 0.85}) async {
    if (!enabled || assetPath == null) {
      return;
    }
    final player = AudioPlayer();
    _activePlayers.add(player);
    try {
      await player.play(AssetSource(assetPath), volume: volume);
      unawaited(player.onPlayerComplete.first.then((_) => _release(player)));
    } catch (_) {
      await _release(player);
    }
  }

  Future<void> _release(AudioPlayer player) async {
    _activePlayers.remove(player);
    await player.dispose();
  }

  Future<void> dispose() async {
    final players = List<AudioPlayer>.of(_activePlayers);
    _activePlayers.clear();
    await Future.wait(players.map((player) => player.dispose()));
  }
}
