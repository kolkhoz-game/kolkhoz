import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/views/shared/chrome_button.dart';

void main() {
  testWidgets('tactile controls travel on press and spring home on release', (
    tester,
  ) async {
    var activations = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: TactileControlSurface(
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

    expect(transform().storage[0], 1);
    expect(transform().storage[13], 0);

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

  testWidgets('tactile controls lift on pointer hover', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: TactileControlSurface(
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
            child: TactileControlSurface(
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

  testWidgets('disabling a tactile control clears active pointer state', (
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
              child: TactileControlSurface(
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
