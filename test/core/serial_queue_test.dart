import 'dart:async';

import 'package:desktop/core/utils/serial_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SerialQueue', () {
    test('runs actions one at a time, in submission order', () async {
      final queue = SerialQueue();
      final order = <String>[];

      final first = Completer<void>();
      final a = queue.run(() async {
        order.add('a-start');
        await first.future;
        order.add('a-end');
      });
      final b = queue.run(() async {
        order.add('b-start');
        order.add('b-end');
      });

      // b must not begin until a has finished, even though a is still blocked.
      await Future<void>.delayed(Duration.zero);
      expect(order, ['a-start']);

      first.complete();
      await Future.wait([a, b]);
      expect(order, ['a-start', 'a-end', 'b-start', 'b-end']);
    });

    test(
      'isBusy is true from submission until the last action drains',
      () async {
        final queue = SerialQueue();
        expect(queue.isBusy, isFalse);

        final gate = Completer<void>();
        final done = queue.run(() => gate.future);
        expect(queue.isBusy, isTrue, reason: 'busy synchronously on submit');

        gate.complete();
        await done;
        expect(queue.isBusy, isFalse);
      },
    );

    test(
      'a failing action rejects only itself; the queue keeps draining',
      () async {
        final queue = SerialQueue();

        final failed = queue.run(() async => throw StateError('boom'));
        final next = queue.run(() async => 42);

        await expectLater(failed, throwsStateError);
        expect(await next, 42);
        expect(queue.isBusy, isFalse);
      },
    );
  });
}
