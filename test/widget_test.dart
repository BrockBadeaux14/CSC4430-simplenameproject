import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:simplenameproject/main.dart';

void main() {
  testWidgets(
    'Counter stays clickable after falling and reset preserves count',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      expect(find.text('0'), findsOneWidget);
      final element = find.byKey(const ValueKey('gravity-element-2'));
      final startY = tester.getTopLeft(element).dy;
      for (var i = 0; i < 180; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.getTopLeft(element).dy, greaterThan(startY));
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.byTooltip('Drop elements again'));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      expect(tester.getTopLeft(element).dy, closeTo(startY, 1));
    },
  );

  testWidgets('Elements can be grabbed and tossed without incrementing', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    final element = find.byKey(const ValueKey('gravity-element-2'));
    final initial = tester.getTopLeft(element);
    await tester.drag(element, const Offset(-120, -100));
    await tester.pump();
    expect(tester.getTopLeft(element).dx, lessThan(initial.dx - 80));
    expect(tester.getTopLeft(element).dy, lessThan(initial.dy - 60));
    expect(find.text('0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Phone-sized layout fits after resizing', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pump();
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (var i = 0; i < 3; i++) {
      final rect = tester.getRect(find.byKey(ValueKey('gravity-element-$i')));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
      expect(rect.bottom, lessThanOrEqualTo(640));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Native window samples move elements and unsubscribe on disposal',
    (tester) async {
      const name = 'simplenameproject/window_motion';
      final calls = <String>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel(name), (
        call,
      ) async {
        calls.add(call.method);
        return null;
      });
      addTearDown(
        () =>
            messenger.setMockMethodCallHandler(const MethodChannel(name), null),
      );
      await tester.pumpWidget(const MyApp());
      expect(calls, contains('listen'));
      final element = find.byKey(const ValueKey('gravity-element-2'));
      final initialX = tester.getTopLeft(element).dx;
      for (final sample in [
        [0.0, 0.0, 0.0],
        [-20.0, 0.0, 1 / 60],
      ]) {
        tester.binding.channelBuffers.push(
          name,
          const StandardMethodCodec().encodeSuccessEnvelope(sample),
          (_) {},
        );
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getTopLeft(element).dx, greaterThan(initialX));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(calls, contains('cancel'));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.macOS}),
  );
}
