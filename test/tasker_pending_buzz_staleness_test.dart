import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openstrap_edge/platform/tasker_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ch = MethodChannel('openstrap/tasker');
  final now = DateTime.fromMillisecondsSinceEpoch(1_760_000_000_000);

  void mockPeek(Object? reply) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, (call) async {
      if (call.method == 'peek_pending_buzz') return reply;
      return null;
    });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, null);
  });

  test('a buzz queued seconds ago is still delivered', () async {
    mockPeek({
      'pattern': 3,
      'requestedAtMs': now.millisecondsSinceEpoch - 30 * 1000,
    });
    final p = await TaskerBridge.peekPendingBuzz();
    expect(p, isNotNull);
    expect(p!.pattern, 3);
    expect(p.isFresh(now), isTrue);
  });

  test('a buzz queued hours ago is stale', () async {
    mockPeek({
      'pattern': 2,
      'requestedAtMs':
          now.millisecondsSinceEpoch - const Duration(hours: 13).inMilliseconds,
    });
    final p = await TaskerBridge.peekPendingBuzz();
    expect(p!.isFresh(now), isFalse);
  });

  test('a flag with no request time (older build) is stale', () async {
    mockPeek({'pattern': 2, 'requestedAtMs': null});
    final p = await TaskerBridge.peekPendingBuzz();
    expect(p!.pattern, 2);
    expect(p.isFresh(now), isFalse);
  });

  test('a request time far in the future is stale', () {
    final p = PendingTaskerBuzz(
      pattern: 2,
      requestedAtMs:
          now.millisecondsSinceEpoch + const Duration(hours: 1).inMilliseconds,
    );
    expect(p.isFresh(now), isFalse);
  });

  test('nothing queued peeks as null', () async {
    mockPeek(null);
    expect(await TaskerBridge.peekPendingBuzz(), isNull);
  });

  test('a buzz_strap call runs the pending-flag delivery, not its own buzz',
      () async {
    var delivered = 0;
    TaskerBridge(deliverPending: () async => delivered++);
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      ch.name,
      ch.codec.encodeMethodCall(const MethodCall('buzz_strap')),
      (_) {},
    );
    expect(delivered, 1);
  });

  test('custom vibration extras and loop flags are parsed correctly', () async {
    mockPeek({
      'pattern': 0,
      'patternName': 'banca',
      'sequence': '0,200,2',
      'count': 3,
      'delayMs': 400,
      'loop': true,
      'loopIntervalMs': 2000,
      'timeoutSec': 120,
      'requestedAtMs': now.millisecondsSinceEpoch - 1000,
    });
    final p = await TaskerBridge.peekPendingBuzz();
    expect(p, isNotNull);
    expect(p!.patternName, 'banca');
    expect(p.sequence, '0,200,2');
    expect(p.count, 3);
    expect(p.delayMs, 400);
    expect(p.loop, isTrue);
    expect(p.loopIntervalMs, 2000);
    expect(p.timeoutSec, 120);
    expect(p.isFresh(now), isTrue);
  });

  test('stop_buzz_loop platform message invokes onStopLoop callback', () async {
    var stopped = 0;
    TaskerBridge(
      deliverPending: () async {},
      onStopLoop: () => stopped++,
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      ch.name,
      ch.codec.encodeMethodCall(const MethodCall('stop_buzz_loop')),
      (_) {},
    );
    expect(stopped, 1);
  });
}
