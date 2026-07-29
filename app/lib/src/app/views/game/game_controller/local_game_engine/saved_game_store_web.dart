import 'dart:io';

import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';

export 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_serialization.dart';

class KolkhozSavedGamePayload {
  const KolkhozSavedGamePayload({
    required this.seed,
    required this.variants,
    required this.controllers,
    required this.actions,
    this.tutorial = false,
    this.gameLogActions = const [],
  });

  final int seed;
  final KolkhozGameVariants variants;
  final List<KolkhozPlayerController> controllers;
  final List<EngineAction> actions;
  final bool tutorial;
  final List<EngineAction> gameLogActions;
}

/// The web demo never resumes games; reloading always starts from the menu.
class KolkhozAutosaveStore {
  const KolkhozAutosaveStore();

  static KolkhozAutosaveStore defaultStore() =>
      KolkhozAutosaveStore();

  static KolkhozAutosaveStore defaultTutorialStore() =>
      KolkhozAutosaveStore();

  static File defaultFile() => File('/kolkhoz-web-demo.json');

  KolkhozSavedGamePayload? load() => null;
  void save(KolkhozSavedGamePayload payload) {}
  void clear() {}
}
