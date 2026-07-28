import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/views/shared/art_direction.dart';
import 'package:kolkhoz_app/src/app/views/shared/field_plan_assets.dart';

void main() {
  testWidgets('art assets render their field-plan source', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ArtAssetImage(
          asset: ArtAssetRef(fieldPlanPath: fieldPlanToolbarConfirmIconPath),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                fieldPlanToolbarConfirmIconPath,
      ),
      findsOneWidget,
    );
  });
}
