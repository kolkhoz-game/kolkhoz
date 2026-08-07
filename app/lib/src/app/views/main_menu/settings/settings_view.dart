import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kolkhoz_app/src/app/profile/profile_controller/player_identity.dart';
import 'package:kolkhoz_app/src/app/profile/profile_controller/profile_controller.dart';
import 'package:kolkhoz_app/src/app/profile/profile_controller/progression.dart';
import 'package:kolkhoz_app/src/app/remote_connection/remote_error.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/profile/models/profile_remote_models.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_controller/menu_remote_models.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/main_menu_controller/menu_remote_connection.dart';
import 'package:kolkhoz_app/src/app/views/shared/app_text.dart';
import 'package:kolkhoz_app/src/app/views/shared/chrome_button.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_assets.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_typography.dart';
import 'package:kolkhoz_app/src/app/views/shared/printed_underlay.dart';
import 'package:kolkhoz_app/src/app/remote_connection/json_shape.dart';
import 'package:kolkhoz_app/src/app/profile/views/player_profile_panel.dart';
import 'package:kolkhoz_app/src/app/views/shared/rule_content.dart';
import '../main_menu_view.dart';

part 'admin_operations_view.dart';
part 'cloud_auth_view.dart';
part 'comrades_view.dart';
part 'profile_view.dart';
part 'rules_view.dart';

const maxAccountEmailLength = 254;

class _ProfilePortraitChoice extends StatelessWidget {
  const _ProfilePortraitChoice({
    required this.tokens,
    required this.asset,
    required this.selected,
    required this.unlocked,
    required this.onPressed,
  });

  final DesignTokens tokens;
  final String asset;
  final bool selected;
  final bool unlocked;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TactileButton(
      selected: selected,
      semanticSelected: selected,
      semanticLabel: unlocked ? asset : '$asset (locked)',
      enabled: unlocked && onPressed != null,
      onPressed: onPressed,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: unlocked ? 1 : 0.42,
            child: PlayerProfilePortraitImage(
              tokens: tokens,
              asset: asset,
              size: 58,
              selected: selected,
            ),
          ),
          if (!unlocked)
            Image.asset(
              'assets/ui/Icons/icon-lock.png',
              width: 22,
              height: 22,
              filterQuality: FilterQuality.none,
            ),
        ],
      ),
    );
  }
}

class MainMenuGoldDivider extends StatelessWidget {
  const MainMenuGoldDivider({super.key, required this.tokens});

  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: tokens.colors.gold.withValues(alpha: 0.35),
    );
  }
}

class MainMenuAssetIcon extends StatelessWidget {
  const MainMenuAssetIcon(
    this.asset, {
    super.key,
    this.size = 18,
    this.opacity = 1,
  });

  final String asset;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        asset,
        width: size,
        height: size,
        filterQuality: FilterQuality.none,
      ),
    );
  }
}
