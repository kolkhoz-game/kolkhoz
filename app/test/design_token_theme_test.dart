import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/app.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';

void main() {
  test('Material theme follows dark design tokens', () {
    final theme = kolkhozTheme(defaultDesignTokens);

    expect(theme.brightness, Brightness.dark);
    expect(
      theme.scaffoldBackgroundColor,
      defaultDesignTokens.colors.background,
    );
    expect(theme.colorScheme.surface, defaultDesignTokens.colors.panel);
    expect(theme.colorScheme.onSurface, defaultDesignTokens.colors.cream);
    expect(
      theme.progressIndicatorTheme.color,
      defaultDesignTokens.colors.goldBright,
    );
    expect(
      theme.textSelectionTheme.cursorColor,
      defaultDesignTokens.colors.redDark,
    );
  });

  test('Material theme follows light design tokens', () {
    final theme = kolkhozTheme(lightDesignTokens);

    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, lightDesignTokens.colors.background);
    expect(theme.colorScheme.surface, lightDesignTokens.colors.panel);
    expect(theme.colorScheme.onSurface, lightDesignTokens.colors.cream);
    expect(theme.dialogTheme.backgroundColor, lightDesignTokens.colors.panel);
    expect(
      theme.dialogTheme.contentTextStyle?.color,
      lightDesignTokens.colors.cream,
    );
    expect(
      theme.textButtonTheme.style?.foregroundColor?.resolve({}),
      lightDesignTokens.colors.goldBright,
    );
  });
}
