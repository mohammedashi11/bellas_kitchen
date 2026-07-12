import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bellas_kitchen/main.dart';

void main() {
  testWidgets('BellasKitchenApp renders without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: BellasKitchenApp(),
      ),
    );
    // App renders without error. MaterialApp.router is a MaterialApp that
    // wires up a Router, so both are present in the tree.
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Router<Object>), findsOneWidget);
  });
}
