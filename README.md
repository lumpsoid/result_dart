# Result&lt;T, E&gt;

A type-safe discriminated union for Dart that represents either a success (`Ok<T, E>`) or a failure (`Failure<T, E>`). Built on Dart 3 sealed classes and exhaustive pattern-matching — no runtime `is`/`as` casts.

## Table of Contents

- [Installation](#installation)
- [Core Types](#core-types)
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
  - [Constructors & Static Helpers](#constructors--static-helpers)
  - [Inspection](#inspection)
  - [Transformation](#transformation)
  - [Side Effects](#side-effects)
  - [Unwrapping](#unwrapping)
  - [Combining Results](#combining-results)
- [Async Support](#async-support)
- [FutureResultExtension](#futureresultextension)
- [Error Handling](#error-handling)
- [Design Notes](#design-notes)

---

## Core Types

| Type | Description |
|---|---|
| `Result<T, E>` | Sealed base class. Either `Ok` or `Failure`. |
| `Ok<T, E>` | The success case, wrapping a value of type `T`. |
| `Failure<T, E>` | The failure case, wrapping an error of type `E`. |
| `ResultException<E>` | Thrown by `getOrThrow()` when the result is a `Failure`. |

---

## Quick Start

```dart
// Create results
Result<int, String> divide(int a, int b) {
  if (b == 0) return Failure('Division by zero');
  return Ok(a ~/ b);
}

// Consume results
final result = divide(10, 2);

// Pattern match (exhaustive)
switch (result) {
  case Ok(:final value): print('Got $value');
  case Failure(:final error): print('Error: $error');
}

// Chain operations
final message = divide(10, 2)
    .map((n) => n * 3)
    .flatMap((n) => n > 10 ? Ok('Big: $n') : Failure('Too small'))
    .getOrElse((e) => 'Fallback: $e');
```

---

## API Reference

### Constructors & Static Helpers

```dart
// Direct constructors
Ok<int, String>(42)
Failure<int, String>('something went wrong')

// Static factory methods
Result.ok<int, String>(42)
Result.failure<int, String>('error')

// Wrap a throwing function
Result<int, String> result = Result.tryRun(
  () => int.parse(userInput),
  (e, s) => 'Invalid number: $e',
);

// Async variant
Future<Result<Data, String>> result = Result.tryRunAsync(
  () => fetchData(),
  (e, s) => 'Network error: $e',
);
```

### Inspection

```dart
result.isSuccess   // true if Ok
result.isFailure   // true if Failure
result.value       // T? — null if Failure
result.error       // E? — null if Ok
```

### Transformation

All transformation methods short-circuit on `Failure`, passing the error through unchanged.

| Method | Signature | Description |
|---|---|---|
| `map` | `(T → U) → Result<U, E>` | Transform the success value. |
| `mapAsync` | `(T → Future<U>) → Future<Result<U, E>>` | Async `map`. |
| `flatMap` | `(T → Result<U, E>) → Result<U, E>` | Chain an operation that may itself fail. |
| `flatMapAsync` | `(T → Future<Result<U, E>>) → Future<Result<U, E>>` | Async `flatMap`. |
| `mapError` | `(E → F) → Result<T, F>` | Transform the error type. |
| `recover` | `(E → Result<T, F>) → Result<T, F>` | Attempt recovery from a failure. |
| `fold` | `(T → R, E → R) → R` | Collapse both cases to a single value. |
| `consumeSuccess` | `(T → void) → Result<void, E>` | Run a side-effect and discard the value. |
| `consumeFailure` | `(E → void) → Result<T, void>` | Run a side-effect and discard the error. |

```dart
// Example: pipeline
final result = await Result.tryRunAsync(() => fetchUser(id), toError)
    .mapAsync((user) => enrichProfile(user))
    .flatMapAsync((profile) => saveProfile(profile))
    .mapError((e) => AppError.fromRaw(e));
```

### Side Effects

These methods run callbacks for observation or logging and always return `this` (or `Future<this>`) for chaining.

```dart
result
  .onSuccess((value) => log.info('Got $value'))
  .onFailure((error) => log.error('Failed: $error'));

// Combined tap
result.onTap(
  (value) => analytics.track('success'),
  (error) => analytics.track('failure'),
);

// Async variants
await result
    .onSuccessAsync((v) async => await audit.log(v))
    .onFailureAsync((e) async => await alerts.send(e));
```

### Unwrapping

```dart
// Throws ResultException<E> on failure
final value = result.getOrThrow();

// Provide a fallback value
final value = result.getOrDefault(0);

// Compute a fallback from the error
final value = result.getOrElse((error) => computeDefault(error));

// Convert to nullable (returns null on failure)
final value = result.toNullable();

// Lift into a Future<Result>
final future = result.asFuture;
```

### Combining Results

```dart
// Combine two independent results into a record pair
// Returns the first failure if either input failed
final combined = Result.combine2(fetchUser(), fetchConfig());
// combined is Result<(User, Config), ApiError>

combined.map((record) {
  final (user, config) = record;
  return buildApp(user, config);
});

// Collapse a list of results into a single result
// Short-circuits on the first failure
final allResults = Result.sequence([parse('1'), parse('2'), parse('3')]);
// allResults is Result<List<int>, ParseError>
```

---

## Async Support

Every synchronous method has a corresponding async variant directly on `Result`. For `Future<Result<T, E>>` chains, prefer the `FutureResultExtension`.

```dart
// Sync
final r = fetchSync().map(transform).flatMap(validate);

// Async — identical style
final r = await fetchAsync()
    .mapAsync(transform)
    .flatMapAsync(validate);
```

---

## FutureResultExtension

The extension on `Future<Result<T, E>>` mirrors the full sync API so async pipelines read identically to synchronous ones:

```dart
extension FutureResultExtension<T, E> on Future<Result<T, E>>
```

Available methods: `fold`, `map`, `mapAsync`, `mapError`, `flatMap`, `flatMapAsync`, `recover`, `onSuccess`, `onSuccessAsync`, `onFailure`, `onFailureAsync`, `onTap`, `getOrDefault`, `getOrElse`, `consumeSuccess`, `consumeFailure`.

```dart
final greeting = await getUserIdFromSession()         // Result<int, AuthError>
    .asFuture
    .flatMapAsync((id) => fetchUser(id))              // Result<User, AuthError>
    .mapAsync((user) => buildGreeting(user))          // Result<String, AuthError>
    .getOrElse((e) => 'Hello, guest!');
```

---

## Error Handling

`ResultException<E>` is thrown only by `getOrThrow()`. It preserves the static error type so catch-sites can inspect it:

```dart
try {
  final value = result.getOrThrow();
} on ResultException<ApiError> catch (e) {
  print(e.error.code); // typed as ApiError
}
```

`tryRun` and `tryRunAsync` only catch `Exception` subtypes. Errors (e.g., `Error`, `AssertionError`) propagate normally. If you need broader coverage, wrap `onError` accordingly or catch at the call site.

---

## Design Notes

**Exhaustive pattern-matching.** Because `Result` is a Dart 3 `sealed` class, `switch` expressions over it are checked at compile time. Adding a new subclass would cause compile errors at every unhandled switch site.

**No runtime casting.** All branching uses Dart 3 pattern syntax (`case Ok(:final value)`, `case Failure(:final error)`). There are no `is`/`as` expressions in the implementation.

**Immutability.** Both `Ok` and `Failure` are `@immutable`. Equality and hash codes are value-based.

**Void edge case.** `Ok<void, E>` instances all share `hashCode 0` if keyed on value. The implementation falls back to `runtimeType.hashCode` for the `Null` type to avoid collisions in sets and maps.

**Error-only catch in `tryRun`.** Only `Exception` is caught, not `Error`. This is intentional — programming errors such as null dereferences should not be silently converted into `Failure` values.
