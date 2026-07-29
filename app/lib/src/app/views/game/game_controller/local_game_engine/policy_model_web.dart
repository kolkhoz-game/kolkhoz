import 'package:flutter/services.dart';

import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_bridge.dart';

const mediumNeuralPolicyAsset = 'assets/policies/medium_policy.json';
const hardNeuralPolicyAsset = 'assets/policies/hard_policy.json';
const defaultNeuralPolicyAsset = hardNeuralPolicyAsset;

/// The public web build only exposes the fixed heuristic-AI demo and tutorial.
///
/// Keeping this lightweight implementation lets the shared app initialize its
/// policy slots without shipping or allocating native neural-policy buffers.
class KolkhozNativePolicyModel {
  const KolkhozNativePolicyModel._();

  Object get native => this;

  Object workspace(KolkhozCEngineBridge bridge) => this;

  static Future<KolkhozNativePolicyModel> loadAsset(
    String assetPath, {
    AssetBundle? bundle,
  }) async => const KolkhozNativePolicyModel._();

  static KolkhozNativePolicyModel fromJson(Map<String, Object?> json) =>
      const KolkhozNativePolicyModel._();

  void dispose() {}
}
