import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/main_menu/settings/settings_view.dart';
import 'package:kolkhoz_app/src/app/views/shared/chrome_button.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/shared/display_text.dart';

void main() {
  testWidgets('text fields normalize, validate, and submit through Material', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final formKey = GlobalKey<FormState>();
    String? submitted;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(focusColor: Colors.amber),
        home: Material(
          child: Form(
            key: formKey,
            child: KolkhozTextField(
              tokens: defaultDesignTokens,
              controller: controller,
              labelText: 'CODE',
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                const UpperCaseTextFormatter(),
              ],
              validator: (value) =>
                  (value?.isEmpty ?? true) ? 'REQUIRED' : null,
              onSubmitted: (value) => submitted = value,
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'ab-12');
    expect(controller.text, 'AB12');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(submitted, 'AB12');

    controller.clear();
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('REQUIRED'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    final focusedBorder = field.decoration?.focusedBorder as OutlineInputBorder;
    expect(focusedBorder.borderSide.color, Colors.amber);
  });

  testWidgets('account form validates and normalizes sign-in values', (
    tester,
  ) async {
    String? submittedEmail;
    String? submittedPassword;
    var signUpCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: CloudAuthView(
            tokens: defaultDesignTokens,
            language: KolkhozLanguage.en,
            configured: true,
            ready: true,
            busy: false,
            message: null,
            messageIsError: false,
            onSignIn: (email, password) async {
              submittedEmail = email;
              submittedPassword = password;
            },
            onSignUp: (_, _) async => signUpCount += 1,
            onResetPassword: (_) async {},
          ),
        ),
      ),
    );

    final signIn = find.bySemanticsLabel('SIGN IN');
    await tester.tap(signIn);
    await tester.pump();
    expect(find.text('ENTER EMAIL'), findsOneWidget);

    final email = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'EMAIL',
    );
    final password = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'PASSWORD',
    );
    await tester.enterText(email, ' player@example.com ');
    await tester.enterText(password, 'collective');
    await tester.tap(signIn);
    await tester.pump();

    expect(submittedEmail, 'player@example.com');
    expect(submittedPassword, 'collective');

    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'CONFIRM PASSWORD',
      ),
      'different',
    );
    await tester.tap(find.bySemanticsLabel('CREATE'));
    await tester.pump();
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(signUpCount, 0);
  });

  testWidgets('directional focus groups move between controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: KolkhozDirectionalFocusGroup(
          axis: Axis.horizontal,
          child: Row(
            children: [
              TactileButton(
                semanticLabel: 'First',
                onPressed: () {},
                child: const SizedBox(width: 80, height: 40),
              ),
              TactileButton(
                semanticLabel: 'Second',
                onPressed: () {},
                child: const SizedBox(width: 80, height: 40),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Second'))
          .flagsCollection
          .isFocused
          .toBoolOrNull(),
      isTrue,
    );
  });

  testWidgets('keyboard focus uses the active theme focus color', (
    tester,
  ) async {
    for (final focusColor in [Colors.amber, Colors.lightBlue]) {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(focusColor),
          theme: ThemeData(focusColor: focusColor),
          home: Center(
            child: TactileButton(
              haptics: false,
              onPressed: () {},
              child: const SizedBox(width: 120, height: 56),
            ),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final animated = tester.widget<AnimatedContainer>(
        find.byKey(const Key('tactile-control-transform')),
      );
      final decoration = animated.decoration! as BoxDecoration;
      expect(decoration.border!.top.color, focusColor);
    }
  });

  testWidgets('panel changes hand focus to the new region', (tester) async {
    var panel = 0;
    late StateSetter setState;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setter) {
            setState = setter;
            return KolkhozFocusHandoff(
              handoffKey: panel,
              semanticLabel: 'Panel $panel',
              child: TextButton(onPressed: () {}, child: Text('Panel $panel')),
            );
          },
        ),
      ),
    );

    setState(() => panel = 1);
    await tester.pump();
    await tester.pump();

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'Kolkhoz panel focus handoff',
    );
  });

  testWidgets('confirmation dialogs focus the safe action first', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showKolkhozConfirmation(
                context: context,
                tokens: defaultDesignTokens,
                title: 'Delete account?',
                message: 'This cannot be undone.',
                cancelLabel: 'CANCEL',
                confirmLabel: 'DELETE',
                destructive: true,
              );
            },
            child: const Text('OPEN'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('chrome buttons expose one labeled button action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ChromeAssetButton(
            label: 'Create game',
            tokens: defaultDesignTokens,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            textSize: DisplayTextSize.caption,
            uppercase: false,
            onPressed: () {},
          ),
        ),
      ),
    );

    final button = find.bySemanticsLabel('Create game');
    expect(button, findsOneWidget);
    expect(find.byType(TextButton), findsOneWidget);
    final node = tester.getSemantics(button);
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isEnabled.toBoolOrNull(), isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    semantics.dispose();
  });

  testWidgets('chrome buttons use native keyboard activation', (tester) async {
    var activations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ChromeAssetButton(
            label: 'Create game',
            tokens: defaultDesignTokens,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            textSize: DisplayTextSize.caption,
            uppercase: false,
            onPressed: () => activations += 1,
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    expect(activations, 1);
    expect(FocusManager.instance.primaryFocus, isNotNull);
  });

  testWidgets('material tactile selections expose one selected button node', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: TactileButton(
            selected: true,
            semanticSelected: true,
            semanticLabel: 'Kolkhoz',
            onPressed: () {},
            child: const Text('visual label'),
          ),
        ),
      ),
    );

    final selected = find.bySemanticsLabel('Kolkhoz');
    expect(selected, findsOneWidget);
    expect(find.byType(TextButton), findsOneWidget);
    final node = tester.getSemantics(selected);
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isSelected.toBoolOrNull(), isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(find.bySemanticsLabel('visual label'), findsNothing);
    semantics.dispose();
  });

  testWidgets('disabled chrome buttons expose no tap action', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: ChromeAssetButton(
            label: 'Use favorite',
            tokens: defaultDesignTokens,
            backgroundColor: Colors.grey,
            textColor: Colors.black,
            textSize: DisplayTextSize.caption,
            uppercase: false,
            enabled: false,
          ),
        ),
      ),
    );

    final node = tester.getSemantics(find.bySemanticsLabel('Use favorite'));
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isEnabled.toBoolOrNull(), isFalse);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    semantics.dispose();
  });

  testWidgets('tactile buttons travel on press and spring home on release', (
    tester,
  ) async {
    var activations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: TactileButton(
            haptics: false,
            onPressed: () => activations += 1,
            child: const SizedBox(key: Key('control'), width: 120, height: 56),
          ),
        ),
      ),
    );

    Matrix4 transform() => tester
        .widget<AnimatedContainer>(
          find.byKey(const Key('tactile-control-transform')),
        )
        .transform!;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('control'))),
    );
    await tester.pump(tactileControlPressDuration);

    expect(transform().storage[0], closeTo(tactileControlPressScale, 0.001));
    expect(transform().storage[13], closeTo(tactileControlPressTravel, 0.001));

    await gesture.up();
    await tester.pump(tactileControlReleaseDuration);

    expect(activations, 1);
    expect(transform().storage[0], closeTo(1, 0.001));
    expect(transform().storage[13], closeTo(0, 0.001));
  });

  testWidgets('tactile buttons lift on pointer hover', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: TactileButton(
            haptics: false,
            onPressed: () {},
            child: const SizedBox(key: Key('control'), width: 120, height: 56),
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.byKey(const Key('control'))));
    await tester.pump(tactileControlHoverDuration);

    final animated = tester.widget<AnimatedContainer>(
      find.byKey(const Key('tactile-control-transform')),
    );
    expect(
      animated.transform!.storage[0],
      closeTo(tactileControlHoverScale, 0.001),
    );
    expect(
      animated.transform!.storage[13],
      closeTo(tactileControlHoverLift, 0.001),
    );
  });

  testWidgets('reduced motion applies tactile states without interpolation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Center(
            child: TactileButton(
              haptics: false,
              onPressed: () {},
              child: const SizedBox(
                key: Key('control'),
                width: 120,
                height: 56,
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('control'))),
    );
    await tester.pump();

    final animated = tester.widget<AnimatedContainer>(
      find.byKey(const Key('tactile-control-transform')),
    );
    expect(animated.duration, Duration.zero);
    expect(animated.transform!.storage[13], tactileControlPressTravel);

    await gesture.up();
  });

  testWidgets('disabling a tactile button clears active pointer state', (
    tester,
  ) async {
    var enabled = true;
    late StateSetter setState;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, update) {
            setState = update;
            return Center(
              child: TactileButton(
                haptics: false,
                enabled: enabled,
                onPressed: enabled ? () {} : null,
                child: const SizedBox(
                  key: Key('control'),
                  width: 120,
                  height: 56,
                ),
              ),
            );
          },
        ),
      ),
    );

    Matrix4 transform() => tester
        .widget<AnimatedContainer>(
          find.byKey(const Key('tactile-control-transform')),
        )
        .transform!;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('control'))),
    );
    await tester.pump(tactileControlPressDuration);
    expect(transform().storage[13], tactileControlPressTravel);

    setState(() => enabled = false);
    await tester.pump();
    setState(() => enabled = true);
    await tester.pump(tactileControlReleaseDuration);

    expect(transform().storage[0], closeTo(1, 0.001));
    expect(transform().storage[13], closeTo(0, 0.001));
    await gesture.up();
  });

  testWidgets('tactile text buttons activate exactly once', (tester) async {
    var activations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: TactileTextButton(
            onPressed: () => activations += 1,
            child: const Text('ACTIVATE'),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TactileTextButton));
    await tester.pumpAndSettle();

    expect(activations, 1);
  });
}
