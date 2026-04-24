/// Returns true if [a] and [b] are deeply equal.
///
/// Handles nested [List], [Map], [Set], and scalar values recursively.
bool deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return a == b;

  if (a is List && b is List) return _listEquals(a, b);
  if (a is Map && b is Map) return _mapEquals(a, b);
  if (a is Set && b is Set) return _setEquals(a, b);

  return a == b;
}

/// Returns a deep hash code consistent with [deepEquals].
int deepHashCode(Object? value) {
  if (value == null) return null.hashCode;
  if (value is List) return _listHashCode(value);
  if (value is Map) return _mapHashCode(value);
  if (value is Set) return _setHashCode(value);
  return value.hashCode;
}

// List

bool _listEquals(List<dynamic> a, List<dynamic> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!deepEquals(a[i], b[i])) return false;
  }
  return true;
}

int _listHashCode(List<dynamic> list) {
  var result = 0;
  for (final element in list) {
    result = _combine(result, deepHashCode(element));
  }
  return _finish(result);
}

// Map

bool _mapEquals(Map<dynamic, dynamic> a, Map<dynamic, dynamic> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key)) return false;
    if (!deepEquals(a[key], b[key])) return false;
  }
  return true;
}

int _mapHashCode(Map<dynamic, dynamic> map) {
  var result = 0;
  for (final entry in map.entries) {
    // XOR so that entry order does not affect the hash.
    result ^= _combine(deepHashCode(entry.key), deepHashCode(entry.value));
  }
  return _finish(result);
}

// Set

bool _setEquals(Set<dynamic> a, Set<dynamic> b) {
  if (a.length != b.length) return false;
  // Each element of [a] must have a match in [b] via deepEquals.
  // A direct `b.contains(element)` would use the element's own == /hashCode,
  // which may not be deep — so we fall back to a linear scan.
  for (final element in a) {
    if (!b.any((bElement) => deepEquals(element, bElement))) return false;
  }
  return true;
}

int _setHashCode(Set<dynamic> set) {
  var result = 0;
  for (final element in set) {
    // XOR so that iteration order does not affect the hash.
    result ^= deepHashCode(element);
  }
  return _finish(result);
}

// Jenkins hash helpers
//
// These are based on the Jenkins One-at-a-Time hash algorithm, but adapted
// for safe execution in Dart-on-JavaScript environments.
//
// Standard Jenkins uses 32-bit arithmetic, but JavaScript only safely
// represents integers up to 2^53-1. To avoid silent precision loss,
// all intermediate values are intentionally capped at 29 bits (0x1fffffff)
// rather than the standard 32 bits (0xffffffff).
//
// The inner masks (0x0007ffff, 0x03ffffff, 0x00003fff) pre-truncate values
// before left-shifting, ensuring intermediate results never exceed 2^53.
// This trades a small reduction in hash distribution for zero-dependency
// cross-platform safety without needing dart:typed_data.
//
// WARNING: These functions are intended for internal use as building blocks
// for object hashing (e.g. hashCode). They are NOT a drop-in replacement
// for a standard Jenkins hash and should not be used for:
//   - Cryptographic purposes
//   - Cross-platform hash persistence (storage/network)
//   - Any context requiring full 32-bit Jenkins compatibility

/// Mixes [value] into a running Jenkins hash [hash].
///
/// Call this once per field/value you want to include in the hash.
/// Finish the hash with [_finish] after all values are combined.
///
/// Example:
/// ```dart
/// var hash = 0;
/// hash = _combine(hash, field1.hashCode);
/// hash = _combine(hash, field2.hashCode);
/// return _finish(hash);
/// ```
///
/// Implementation notes:
/// - Outer mask `0x1fffffff` (29-bit) keeps addition results JS-safe.
///   Standard Jenkins would use `0xffffffff` (32-bit) here.
/// - Inner mask `0x0007ffff` (19-bit) pre-truncates [hash] before `<< 10`,
///   ensuring the shift result stays within 29 bits:
///   19 bits + 10 shift = 29 bits → safe under JS 2^53 limit.
/// - XOR with `h >> 6` avalanches bits downward to improve distribution.
int _combine(int hash, int value) {
  var h = hash;

  // Add [value] into the hash, masking to 29 bits to stay JS-safe.
  // (Standard Jenkins masks to 32 bits with 0xffffffff here.)
  h = 0x1fffffff & (h + value);

  // Avalanche bits upward via a shift-add, then mask back to 29 bits.
  // Inner mask 0x0007ffff (19-bit) ensures (h << 10) won't exceed 29 bits:
  //   19 bits << 10 = 29 bits, safely within the outer 0x1fffffff mask.
  h = 0x1fffffff & (h + ((0x0007ffff & h) << 10));

  // Avalanche bits downward via XOR to improve low-bit distribution.
  return h ^ (h >> 6);
}

/// Finalizes a Jenkins hash produced by one or more calls to [_combine].
///
/// Applies a final avalanche pass to improve bit distribution across
/// the full output range. Always call this once after all [_combine]
/// calls are complete.
///
/// Returns a non-negative 29-bit integer suitable for use as a hashCode.
///
/// Implementation notes:
/// - Inner mask `0x03ffffff` (26-bit) before `<< 3` keeps the shift
///   result within 29 bits: 26 bits + 3 shift = 29 bits.
/// - Inner mask `0x00003fff` (14-bit) before `<< 15` keeps the shift
///   result within 29 bits: 14 bits + 15 shift = 29 bits.
/// - Final outer mask `0x1fffffff` guarantees a non-negative result
///   on all platforms, since Dart's int is 64-bit on native but
///   behaves as a JS float on the web.
int _finish(int hash) {
  var h = hash;

  // Shift-add avalanche upward (×8 equivalent).
  // Inner mask 0x03ffffff (26-bit) prevents (h << 3) exceeding 29 bits:
  //   26 bits << 3 = 29 bits, safely within the outer 0x1fffffff mask.
  h = 0x1fffffff & (h + ((0x03ffffff & h) << 3));

  // Avalanche bits downward via XOR to mix upper and lower bits.
  h = h ^ (h >> 11);

  // Final shift-add avalanche and mask to produce the finished hash.
  // Inner mask 0x00003fff (14-bit) prevents (h << 15) exceeding 29 bits:
  //   14 bits << 15 = 29 bits, safely within the outer 0x1fffffff mask.
  return 0x1fffffff & (h + ((0x00003fff & h) << 15));
}
