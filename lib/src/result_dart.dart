// return pattern
// ignore_for_file: avoid_returning_this
import 'dart:async';
import 'package:meta/meta.dart';
import 'package:result_dart/src/deep_equality.dart';

/// A discriminated union representing either a success ([Ok]) or a failure
/// ([Failure]).
sealed class Result<T, E> {
  const Result();

  /// Whether this result represents a success.
  bool get isSuccess => this is Ok<T, E>;

  /// Whether this result represents a failure.
  bool get isFailure => this is Failure<T, E>;

  /// The wrapped value, or `null` when this is a [Failure].
  T? get value => switch (this) {
    Ok(:final value) => value,
    Failure() => null,
  };

  /// The wrapped error, or `null` when this is an [Ok].
  E? get error => switch (this) {
    Ok() => null,
    Failure(:final error) => error,
  };

  /// Lifts this synchronous result into a completed [Future].
  Future<Result<T, E>> get asFuture => Future.value(this);

  /// Maps the success value; passes failures through unchanged.
  Result<U, E> map<U>(U Function(T) converter) => switch (this) {
    Ok(:final value) => Ok(converter(value)),
    Failure(:final error) => Failure(error),
  };

  /// Async variant of [map].
  Future<Result<U, E>> mapAsync<U>(Future<U> Function(T) converter) async =>
      switch (this) {
        Ok(:final value) => Ok(await converter(value)),
        Failure(:final error) => Failure(error),
      };

  /// Chains an operation that itself returns a [Result]; short-circuits on
  /// failure.
  Result<U, E> flatMap<U>(Result<U, E> Function(T) converter) => switch (this) {
    Ok(:final value) => converter(value),
    Failure(:final error) => Failure(error),
  };

  /// Async variant of [flatMap].
  Future<Result<U, E>> flatMapAsync<U>(
    Future<Result<U, E>> Function(T) converter,
  ) async => switch (this) {
    Ok(:final value) => converter(value),
    Failure(:final error) => Failure(error),
  };

  /// Maps the error value; passes successes through unchanged.
  Result<T, F> mapError<F>(F Function(E) converter) => switch (this) {
    Ok(:final value) => Ok(value),
    Failure(:final error) => Failure(converter(error)),
  };

  /// Attempts to recover from a failure by producing a new [Result].
  Result<T, F> recover<F>(Result<T, F> Function(E) onFailure) => switch (this) {
    Ok(:final value) => Ok(value),
    Failure(:final error) => onFailure(error),
  };

  /// Collapses both cases into a single value of type [R].
  R fold<R>(R Function(T) onSuccess, R Function(E) onFailure) => switch (this) {
    Ok(:final value) => onSuccess(value),
    Failure(:final error) => onFailure(error),
  };

  /// Async version of [fold]
  Future<R> foldAsync<R>(
    Future<R> Function(T) onSuccess,
    Future<R> Function(E) onFailure,
  ) => switch (this) {
    Ok(:final value) => onSuccess(value),
    Failure(:final error) => onFailure(error),
  };

  /// Runs [action] if this is [Ok]; returns `this` for chaining.
  Result<T, E> onSuccess(void Function(T) action) {
    if (this case Ok(:final value)) action(value);
    return this;
  }

  /// Async variant of [onSuccess].
  Future<Result<T, E>> onSuccessAsync(Future<void> Function(T) action) async {
    if (this case Ok(:final value)) await action(value);
    return this;
  }

  /// Runs [action] if this is [Failure]; returns `this` for chaining.
  Result<T, E> onFailure(void Function(E) action) {
    if (this case Failure(:final error)) action(error);
    return this;
  }

  /// Async variant of [onFailure].
  Future<Result<T, E>> onFailureAsync(Future<void> Function(E) action) async {
    if (this case Failure(:final error)) await action(error);
    return this;
  }

  /// Runs [onSuccess] or [onFailure] as a side-effect and returns `this`.
  Result<T, E> onTap(
    void Function(T) onSuccess, [
    void Function(E)? onFailure,
  ]) {
    switch (this) {
      case Ok(:final value):
        onSuccess(value);
      case Failure(:final error):
        onFailure?.call(error);
    }
    return this;
  }

  /// Returns the value or throws [ResultException] if this is a [Failure].
  T getOrThrow() => switch (this) {
    Ok(:final value) => value,
    Failure(:final error) => throw ResultException<E>(error),
  };

  /// Returns the value, or calls [defaultValue] with the error if [Failure].
  T getOrElse(T Function(E) defaultValue) => switch (this) {
    Ok(:final value) => value,
    Failure(:final error) => defaultValue(error),
  };

  /// Returns the value, or [defaultValue] if this is a [Failure].
  T getOrDefault(T defaultValue) => switch (this) {
    Ok(:final value) => value,
    Failure() => defaultValue,
  };

  /// Converts to a nullable; returns `null` on [Failure].
  T? toNullable() => value;

  /// Executes [action] on the value and returns `Ok(null)`, or passes the
  /// failure through.
  Result<void, E> consumeSuccess(void Function(T) action) => switch (this) {
    Ok(:final value) => () {
      action(value);
      return Ok<void, E>(null);
    }(),
    Failure(:final error) => Failure(error),
  };

  /// Executes [action] on the error and returns `Failure(null)`, or passes the
  /// success through.
  Result<T, void> consumeFailure(void Function(E) action) => switch (this) {
    Ok(:final value) => Ok(value),
    Failure(:final error) => () {
      action(error);
      return Failure<T, void>(null);
    }(),
  };

  /// Wraps [value] in an [Ok].
  static Result<T, E> ok<T, E>(T value) => Ok<T, E>(value);

  /// Wraps [error] in a [Failure].
  static Result<T, E> failure<T, E>(E error) => Failure<T, E>(error);

  /// Runs [action] synchronously; wraps the return value in [Ok] on success or
  /// calls [onError] to produce the [Failure] error.
  static Result<T, E> tryRun<T, E>(
    T Function() action,
    E Function(Object, StackTrace) onError,
  ) {
    try {
      return Ok(action());
    } on Exception catch (e, s) {
      return Failure(onError(e, s));
    }
  }

  /// Async variant of [tryRun].
  static Future<Result<T, E>> tryRunAsync<T, E>(
    Future<T> Function() action,
    E Function(Object, StackTrace) onError,
  ) async {
    try {
      return Ok(await action());
    } on Exception catch (e, s) {
      return Failure(onError(e, s));
    }
  }

  /// Combines two independent results into a record pair.
  /// Returns the **first** failure encountered if either input failed.
  static Result<(T1, T2), E> combine2<T1, T2, E>(
    Result<T1, E> r1,
    Result<T2, E> r2,
  ) => switch ((r1, r2)) {
    (Ok<T1, E>(:final value), Ok<T2, E>(value: final value2)) => Ok((
      value,
      value2,
    )),
    (Failure<T1, E>(:final error), _) => Failure(error),
    (_, Failure<T2, E>(:final error)) => Failure(error),
    (Ok<T1, E>(), Failure<T2, E>(:final error)) => Failure(error),
  };

  /// Collapses a list of results into a single result containing a list.
  /// Short-circuits on the **first** failure.
  static Result<List<T>, E> sequence<T, E>(List<Result<T, E>> results) {
    final values = <T>[];
    for (final r in results) {
      switch (r) {
        case Ok(:final value):
          values.add(value);
        case Failure(:final error):
          return Failure(error);
      }
    }
    return Ok(values);
  }
}

/// The success case.
@immutable
class Ok<T, E> extends Result<T, E> {
  /// Creates a successful result wrapping [value].
  const Ok(this.value);

  @override
  final T value;

  @override
  String toString() => 'Ok($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Ok<T, E> &&
          runtimeType == other.runtimeType &&
          deepEquals(value, other.value);

  @override
  // `void` (i.e. Null) values all share hashCode 0, which causes every
  // Ok<void, E> to collide. Fall back to runtimeType for the Null case.
  int get hashCode => T == Null ? runtimeType.hashCode : deepHashCode(value);
}

/// The failure case.
@immutable
class Failure<T, E> extends Result<T, E> {
  /// Creates a failed result wrapping [error].
  const Failure(this.error);

  @override
  final E error;

  @override
  String toString() => 'Failure($error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T, E> &&
          runtimeType == other.runtimeType &&
          deepEquals(error, other.error);

  @override
  int get hashCode => deepHashCode(error);
}

/// Thrown by [Result.getOrThrow] when the result is a [Failure].
///
/// The generic parameter [E] is preserved so catch-sites can inspect the
/// static error type.
class ResultException<E> implements Exception {
  /// Creates a [ResultException] wrapping the given [error].
  const ResultException(this.error);

  /// The underlying error from the [Failure] that triggered this exception.
  final E error;

  @override
  String toString() => 'ResultException<$E>: $error';
}

/// Forwards every [Result] operation to a `Future<Result<T, E>>` so that async
/// pipelines read identically to synchronous ones.
extension FutureResultExtension<T, E> on Future<Result<T, E>> {
  /// Awaits the result and folds it; both callbacks may themselves be async.
  Future<R> fold<R>(
    FutureOr<R> Function(T) onSuccess,
    FutureOr<R> Function(E) onFailure,
  ) async => switch (await this) {
    Ok(:final value) => onSuccess(value),
    Failure(:final error) => onFailure(error),
  };

  /// Maps the success value of the awaited result; passes failures through
  /// unchanged.
  Future<Result<U, E>> map<U>(U Function(T) converter) async =>
      (await this).map(converter);

  /// Async variant of [map] for the awaited result.
  Future<Result<U, E>> mapAsync<U>(Future<U> Function(T) converter) async =>
      (await this).mapAsync(converter);

  /// Maps the error value of the awaited result; passes successes through
  /// unchanged.
  Future<Result<T, F>> mapError<F>(F Function(E) converter) async =>
      (await this).mapError(converter);

  /// Chains an operation on the awaited result that itself returns a [Result];
  /// short-circuits on failure.
  Future<Result<U, E>> flatMap<U>(Result<U, E> Function(T) converter) async =>
      (await this).flatMap(converter);

  /// Async variant of [flatMap] for the awaited result.
  Future<Result<U, E>> flatMapAsync<U>(
    Future<Result<U, E>> Function(T) converter,
  ) async => (await this).flatMapAsync(converter);

  /// Attempts to recover from a failure of the awaited result.
  Future<Result<T, F>> recover<F>(
    Result<T, F> Function(E) onFailure,
  ) async => (await this).recover(onFailure);

  /// Runs [action] if the awaited result is [Ok]; returns the result for
  /// chaining.
  Future<Result<T, E>> onSuccess(void Function(T) action) async =>
      (await this).onSuccess(action);

  /// Async variant of [onSuccess] for the awaited result.
  Future<Result<T, E>> onSuccessAsync(Future<void> Function(T) action) async =>
      (await this).onSuccessAsync(action);

  /// Runs [action] if the awaited result is [Failure]; returns the result for
  /// chaining.
  Future<Result<T, E>> onFailure(void Function(E) action) async =>
      (await this).onFailure(action);

  /// Async variant of [onFailure] for the awaited result.
  Future<Result<T, E>> onFailureAsync(Future<void> Function(E) action) async =>
      (await this).onFailureAsync(action);

  /// Runs [onSuccess] or [onFailure] as a side-effect on the awaited result
  /// and returns it.
  Future<Result<T, E>> onTap(
    void Function(T) onSuccess, [
    void Function(E)? onFailure,
  ]) async => (await this).onTap(onSuccess, onFailure);

  /// Returns the value of the awaited result, or throws [ResultException] if
  /// this is a [Failure].
  Future<T> getOrThrow() async => (await this).getOrThrow();

  /// Returns the value of the awaited result, or [defaultValue] if it is a
  /// [Failure].
  Future<T> getOrDefault(T defaultValue) async =>
      (await this).getOrDefault(defaultValue);

  /// Returns the value of the awaited result, or calls [defaultValue] with the
  /// error if it is a [Failure].
  Future<T> getOrElse(T Function(E) defaultValue) async =>
      (await this).getOrElse(defaultValue);

  /// Executes [action] on the value of the awaited result and returns
  /// `Ok(null)`, or passes the failure through.
  Future<Result<void, E>> consumeSuccess(void Function(T) action) async =>
      (await this).consumeSuccess(action);

  /// Executes [action] on the error of the awaited result and returns
  /// `Failure(null)`, or passes the success through.
  Future<Result<T, void>> consumeFailure(void Function(E) action) async =>
      (await this).consumeFailure(action);
}
