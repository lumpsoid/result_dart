// tests
// ignore_for_file: prefer_const_constructors
import 'dart:async';
import 'package:result_dart/result_dart.dart';
import 'package:test/test.dart';

// Replace with your actual import path

void main() {
  // Helpers
  const ok42 = Ok<int, String>(42);
  const failHello = Failure<int, String>('hello');

  // Ok / Failure construction
  group('Ok', () {
    test('holds value', () => expect(ok42.value, 42));
    test('isSuccess is true', () => expect(ok42.isSuccess, isTrue));
    test('isFailure is false', () => expect(ok42.isFailure, isFalse));
    test('error is null', () => expect(ok42.error, isNull));
    test('toString', () => expect(ok42.toString(), 'Ok(42)'));

    test(
      'equality – same value',
      () => expect(Ok<int, String>(42), equals(ok42)),
    );
    test(
      'equality – different value',
      () => expect(Ok<int, String>(1), isNot(equals(ok42))),
    );
    test('equality – different type param does not collide', () {
      // test
      // ignore: unrelated_type_equality_checks
      expect(Ok<int, String>(1) == Ok<int, int>(1), isFalse);
    });

    test('hashCode equals value hashCode for non-void', () {
      expect(ok42.hashCode, equals(42.hashCode));
    });

    test('hashCode for Ok<void,E> uses runtimeType', () {
      final a = Ok<void, String>(null);
      final b = Ok<void, String>(null);
      // They should be equal and share the same hash.
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('Failure', () {
    test('holds error', () => expect(failHello.error, 'hello'));
    test('isSuccess is false', () => expect(failHello.isSuccess, isFalse));
    test('isFailure is true', () => expect(failHello.isFailure, isTrue));
    test('value is null', () => expect(failHello.value, isNull));
    test('toString', () => expect(failHello.toString(), 'Failure(hello)'));

    test('equality – same error', () {
      expect(Failure<int, String>('hello'), equals(failHello));
    });
    test('equality – different error', () {
      expect(Failure<int, String>('world'), isNot(equals(failHello)));
    });
    test('hashCode equals error hashCode', () {
      expect(failHello.hashCode, equals('hello'.hashCode));
    });
  });

  // Static constructors
  group('Result.ok / Result.failure', () {
    test('Result.ok wraps in Ok', () {
      expect(Result.ok<int, String>(5), equals(Ok<int, String>(5)));
    });
    test('Result.failure wraps in Failure', () {
      expect(
        Result.failure<int, String>('e'),
        equals(Failure<int, String>('e')),
      );
    });
  });

  // map
  group('map', () {
    test('Ok – transforms value', () {
      expect(ok42.map((v) => v * 2), equals(Ok<int, String>(84)));
    });
    test('Failure – passes through unchanged', () {
      expect(
        failHello.map((v) => v * 2),
        equals(Failure<int, String>('hello')),
      );
    });
  });

  group('mapAsync', () {
    test('Ok – transforms value asynchronously', () async {
      final result = await ok42.mapAsync((v) async => v * 2);
      expect(result, equals(Ok<int, String>(84)));
    });
    test('Failure – passes through', () async {
      final result = await failHello.mapAsync((v) async => v * 2);
      expect(result, equals(Failure<int, String>('hello')));
    });
  });

  // flatMap
  group('flatMap', () {
    test('Ok → Ok', () {
      expect(
        ok42.flatMap((v) => Ok<String, String>('val=$v')),
        equals(Ok<String, String>('val=42')),
      );
    });
    test('Ok → Failure (converter fails)', () {
      expect(
        ok42.flatMap((_) => Failure<String, String>('inner error')),
        equals(Failure<String, String>('inner error')),
      );
    });
    test('Failure – short-circuits', () {
      var called = false;
      failHello.flatMap((v) {
        called = true;
        return Ok<String, String>('never');
      });
      expect(called, isFalse);
    });
  });

  group('flatMapAsync', () {
    test('Ok → Ok asynchronously', () async {
      final result = await ok42.flatMapAsync(
        (v) async => Ok<String, String>('val=$v'),
      );
      expect(result, equals(Ok<String, String>('val=42')));
    });
    test('Failure – short-circuits asynchronously', () async {
      var called = false;
      await failHello.flatMapAsync((v) async {
        called = true;
        return Ok<String, String>('never');
      });
      expect(called, isFalse);
    });
  });

  // mapError
  group('mapError', () {
    test('Failure – transforms error', () {
      expect(
        failHello.mapError((e) => e.length),
        equals(Failure<int, int>(5)),
      );
    });
    test('Ok – passes through', () {
      expect(ok42.mapError((e) => 0), equals(Ok<int, int>(42)));
    });
  });

  // recover
  group('recover', () {
    test('Failure – produces new Ok', () {
      final result = failHello.recover<Never>((e) => Ok(e.length));
      expect(result, equals(Ok<int, Never>(5)));
    });
    test('Failure – recover can itself fail', () {
      final result = failHello.recover<int>((e) => Failure(99));
      expect(result, equals(Failure<int, int>(99)));
    });
    test('Ok – not called', () {
      var called = false;
      final result = ok42.recover<Never>((_) {
        called = true;
        return Ok(0);
      });
      expect(called, isFalse);
      expect(result, equals(Ok<int, Never>(42)));
    });
  });

  // fold
  group('fold', () {
    test('Ok – calls onSuccess', () {
      expect(ok42.fold((v) => 'ok:$v', (e) => 'fail:$e'), 'ok:42');
    });
    test('Failure – calls onFailure', () {
      expect(failHello.fold((v) => 'ok:$v', (e) => 'fail:$e'), 'fail:hello');
    });
  });

  // onSuccess / onFailure / onTap
  group('onSuccess', () {
    test('Ok – action is called and this is returned', () {
      var called = false;
      final result = ok42.onSuccess((_) => called = true);
      expect(called, isTrue);
      expect(result, equals(ok42));
    });
    test('Failure – action is not called', () {
      var called = false;
      failHello.onSuccess((_) => called = true);
      expect(called, isFalse);
    });
  });

  group('onSuccessAsync', () {
    test('Ok – awaits action and returns result', () async {
      var called = false;
      final result = await ok42.onSuccessAsync((_) async => called = true);
      expect(called, isTrue);
      expect(result, equals(ok42));
    });
    test('Failure – action is not awaited', () async {
      var called = false;
      await failHello.onSuccessAsync((_) async => called = true);
      expect(called, isFalse);
    });
  });

  group('onFailure', () {
    test('Failure – action is called and this is returned', () {
      var called = false;
      final result = failHello.onFailure((_) => called = true);
      expect(called, isTrue);
      expect(result, equals(failHello));
    });
    test('Ok – action is not called', () {
      var called = false;
      ok42.onFailure((_) => called = true);
      expect(called, isFalse);
    });
  });

  group('onFailureAsync', () {
    test('Failure – awaits action', () async {
      var called = false;
      await failHello.onFailureAsync((_) async => called = true);
      expect(called, isTrue);
    });
  });

  group('onTap', () {
    test('Ok – calls onSuccess callback only', () {
      int? tapped;
      String? failTapped;
      ok42.onTap((v) => tapped = v, (e) => failTapped = e);
      expect(tapped, 42);
      expect(failTapped, isNull);
    });
    test('Failure – calls onFailure callback only', () {
      int? tapped;
      String? failTapped;
      failHello.onTap((v) => tapped = v, (e) => failTapped = e);
      expect(tapped, isNull);
      expect(failTapped, 'hello');
    });
    test('onFailure callback is optional', () {
      expect(() => failHello.onTap((_) {}), returnsNormally);
    });
  });

  // getOrThrow
  group('getOrThrow', () {
    test('Ok – returns value', () => expect(ok42.getOrThrow(), 42));
    test('Failure – throws ResultException with correct error', () {
      expect(
        () => failHello.getOrThrow(),
        throwsA(
          isA<ResultException<String>>().having(
            (e) => e.error,
            'error',
            'hello',
          ),
        ),
      );
    });
    test('ResultException toString contains type and error', () {
      final ex = ResultException<String>('oops');
      expect(ex.toString(), contains('ResultException<String>'));
      expect(ex.toString(), contains('oops'));
    });
  });

  // getOrElse / getOrDefault
  group('getOrElse', () {
    test('Ok – returns value', () {
      expect(ok42.getOrElse((_) => -1), 42);
    });
    test('Failure – calls defaultValue with error', () {
      expect(failHello.getOrElse((e) => e.length), 5);
    });
  });

  group('getOrDefault', () {
    test('Ok – returns value', () => expect(ok42.getOrDefault(-1), 42));
    test(
      'Failure – returns default',
      () => expect(failHello.getOrDefault(-1), -1),
    );
  });

  // toNullable
  group('toNullable', () {
    test('Ok – returns value', () => expect(ok42.toNullable(), 42));
    test(
      'Failure – returns null',
      () => expect(failHello.toNullable(), isNull),
    );
  });

  // asFuture
  group('asFuture', () {
    test('Ok – future completes with Ok', () async {
      expect(await ok42.asFuture, equals(ok42));
    });
    test('Failure – future completes with Failure', () async {
      expect(await failHello.asFuture, equals(failHello));
    });
  });

  // consumeSuccess / consumeFailure
  group('consumeSuccess', () {
    test('Ok – calls action and returns Ok(null)', () {
      int? seen;
      final result = ok42.consumeSuccess((v) => seen = v);
      expect(seen, 42);
      expect(result, equals(Ok<void, String>(null)));
    });
    test('Failure – passes through without calling action', () {
      var called = false;
      final result = failHello.consumeSuccess((_) => called = true);
      expect(called, isFalse);
      expect(result, equals(Failure<void, String>('hello')));
    });
  });

  group('consumeFailure', () {
    test('Failure – calls action and returns Failure(null)', () {
      String? seen;
      final result = failHello.consumeFailure((e) => seen = e);
      expect(seen, 'hello');
      expect(result, equals(Failure<int, void>(null)));
    });
    test('Ok – passes through without calling action', () {
      var called = false;
      final result = ok42.consumeFailure((_) => called = true);
      expect(called, isFalse);
      expect(result, equals(Ok<int, void>(42)));
    });
  });

  // tryRun / tryRunAsync
  group('Result.tryRun', () {
    test('successful action → Ok', () {
      final r = Result.tryRun(() => 99, (e, s) => 'err');
      expect(r, equals(Ok<int, String>(99)));
    });
    test('throwing action → Failure with mapped error', () {
      final r = Result.tryRun<int, String>(
        () => throw Exception('boom'),
        (e, s) => 'caught: $e',
      );
      expect(r.isFailure, isTrue);
      expect((r as Failure).error, contains('boom'));
    });
    test('non-Exception Error is NOT caught (propagates)', () {
      expect(
        () => Result.tryRun<int, String>(
          () => throw StateError('state'),
          (e, s) => 'caught',
        ),
        throwsStateError,
      );
    });
  });

  group('Result.tryRunAsync', () {
    test('successful async action → Ok', () async {
      final r = await Result.tryRunAsync(
        () async => 99,
        (e, s) => 'err',
      );
      expect(r, equals(Ok<int, String>(99)));
    });
    test('throwing async action → Failure', () async {
      final r = await Result.tryRunAsync<int, String>(
        () async => throw Exception('async boom'),
        (e, s) => 'caught',
      );
      expect(r.isFailure, isTrue);
    });
  });

  // combine2
  group('Result.combine2', () {
    final ok1 = Ok<int, String>(1);
    final ok2 = Ok<String, String>('two');
    final fail1 = Failure<int, String>('first error');
    final fail2 = Failure<String, String>('second error');

    test('both Ok → Ok of tuple', () {
      expect(
        Result.combine2(ok1, ok2),
        equals(Ok<(int, String), String>((1, 'two'))),
      );
    });
    test('first Failure → first error', () {
      final r = Result.combine2(fail1, ok2);
      expect(r, equals(Failure<(int, String), String>('first error')));
    });
    test('second Failure → second error', () {
      final r = Result.combine2(ok1, fail2);
      expect(r, equals(Failure<(int, String), String>('second error')));
    });
    test('both Failure → first error wins', () {
      final r = Result.combine2(fail1, fail2);
      expect(r, equals(Failure<(int, String), String>('first error')));
    });
  });

  // sequence
  group('Result.sequence', () {
    test('all Ok → Ok of list', () {
      final results = <Ok<int, String>>[Ok(1), Ok(2), Ok(3)];
      expect(
        Result.sequence(results),
        equals(Ok<List<int>, String>(const [1, 2, 3])),
      );
    });
    test('first failure short-circuits', () {
      final results = <Result<int, String>>[Ok(1), Failure('err'), Ok(3)];
      expect(
        Result.sequence(results),
        equals(Failure<List<int>, String>('err')),
      );
    });
    test('empty list → Ok of empty list', () {
      expect(
        Result.sequence<int, String>([]),
        // test
        // ignore: prefer_const_literals_to_create_immutables
        equals(Ok<List<int>, String>([])),
      );
    });
    test('only failures → first failure returned', () {
      final results = [
        Failure<int, String>('a'),
        Failure<int, String>('b'),
      ];
      expect(
        Result.sequence(results),
        equals(Failure<List<int>, String>('a')),
      );
    });
  });

  // FutureResultExtension
  group('FutureResultExtension', () {
    Future<Result<int, String>> futureOk(int v) async => Ok(v);
    Future<Result<int, String>> futureFail(String e) async => Failure(e);

    test('fold – Ok branch', () async {
      expect(
        await futureOk(7).fold((v) => 'ok:$v', (e) => 'fail:$e'),
        'ok:7',
      );
    });
    test('fold – Failure branch', () async {
      expect(
        await futureFail('oops').fold((v) => 'ok:$v', (e) => 'fail:$e'),
        'fail:oops',
      );
    });

    test('map – Ok', () async {
      expect(await futureOk(7).map((v) => v * 3), equals(Ok<int, String>(21)));
    });
    test('map – Failure passes through', () async {
      expect(
        await futureFail('e').map((v) => v * 3),
        equals(Failure<int, String>('e')),
      );
    });

    test('mapAsync – Ok', () async {
      final r = await futureOk(3).mapAsync((v) async => v + 1);
      expect(r, equals(Ok<int, String>(4)));
    });

    test('mapError – Failure', () async {
      final r = await futureFail('err').mapError((e) => e.length);
      expect(r, equals(Failure<int, int>(3)));
    });
    test('mapError – Ok passes through', () async {
      final r = await futureOk(1).mapError((e) => e.length);
      expect(r, equals(Ok<int, int>(1)));
    });

    test('flatMap – Ok → Ok', () async {
      final r = await futureOk(5).flatMap((v) => Ok<String, String>('$v'));
      expect(r, equals(Ok<String, String>('5')));
    });
    test('flatMap – Failure short-circuits', () async {
      var called = false;
      await futureFail('e').flatMap((v) {
        called = true;
        return Ok<String, String>('never');
      });
      expect(called, isFalse);
    });

    test('flatMapAsync – Ok → Ok', () async {
      final r = await futureOk(5).flatMapAsync(
        (v) async => Ok<String, String>('val=$v'),
      );
      expect(r, equals(Ok<String, String>('val=5')));
    });

    test('recover – Failure → Ok', () async {
      final r = await futureFail('oops').recover<Never>((e) => Ok(e.length));
      expect(r, equals(Ok<int, Never>(4)));
    });
    test('recover – Ok not affected', () async {
      final r = await futureOk(9).recover<Never>((_) => Ok(-1));
      expect(r, equals(Ok<int, Never>(9)));
    });

    test('onSuccess – Ok calls action', () async {
      int? seen;
      await futureOk(3).onSuccess((v) => seen = v);
      expect(seen, 3);
    });
    test('onSuccess – Failure does not call action', () async {
      var called = false;
      await futureFail('e').onSuccess((_) => called = true);
      expect(called, isFalse);
    });

    test('onSuccessAsync – Ok awaits action', () async {
      int? seen;
      await futureOk(3).onSuccessAsync((v) async => seen = v);
      expect(seen, 3);
    });

    test('onFailure – Failure calls action', () async {
      String? seen;
      await futureFail('err').onFailure((e) => seen = e);
      expect(seen, 'err');
    });
    test('onFailure – Ok does not call action', () async {
      var called = false;
      await futureOk(1).onFailure((_) => called = true);
      expect(called, isFalse);
    });

    test('onFailureAsync – Failure awaits action', () async {
      String? seen;
      await futureFail('err').onFailureAsync((e) async => seen = e);
      expect(seen, 'err');
    });

    test('onTap – Ok', () async {
      int? tapped;
      await futureOk(8).onTap((v) => tapped = v);
      expect(tapped, 8);
    });
    test('onTap – Failure', () async {
      String? tapped;
      await futureFail('e').onTap((_) {}, (e) => tapped = e);
      expect(tapped, 'e');
    });

    test('getOrDefault – Ok', () async {
      expect(await futureOk(4).getOrDefault(-1), 4);
    });
    test('getOrDefault – Failure', () async {
      expect(await futureFail('e').getOrDefault(-1), -1);
    });

    test('getOrElse – Ok', () async {
      expect(await futureOk(4).getOrElse((_) => -1), 4);
    });
    test('getOrElse – Failure uses callback', () async {
      expect(await futureFail('err').getOrElse((e) => e.length), 3);
    });

    test('consumeSuccess – Ok', () async {
      int? seen;
      final r = await futureOk(5).consumeSuccess((v) => seen = v);
      expect(seen, 5);
      expect(r, equals(Ok<void, String>(null)));
    });
    test('consumeSuccess – Failure passes through', () async {
      final r = await futureFail('e').consumeSuccess((_) {});
      expect(r, equals(Failure<void, String>('e')));
    });

    test('consumeFailure – Failure', () async {
      String? seen;
      final r = await futureFail('err').consumeFailure((e) => seen = e);
      expect(seen, 'err');
      expect(r, equals(Failure<int, void>(null)));
    });
    test('consumeFailure – Ok passes through', () async {
      final r = await futureOk(1).consumeFailure((_) {});
      expect(r, equals(Ok<int, void>(1)));
    });

    // Chaining / pipeline integration test
    test('async pipeline chains correctly', () async {
      final result = await futureOk(10)
          .map((v) => v * 2)
          .flatMap((v) => Ok<String, String>('result=$v'))
          .mapError((e) => 'mapped: $e');

      expect(result, equals(Ok<String, String>('result=20')));
    });

    test('async pipeline short-circuits on first failure', () async {
      final log = <String>[];
      final result = await futureFail('initial')
          .map((v) {
            log.add('map');
            return v * 2;
          })
          .flatMap((v) {
            log.add('flatMap');
            return Ok<String, String>('$v');
          });

      expect(log, isEmpty);
      expect(result, equals(Failure<String, String>('initial')));
    });
  });
}
