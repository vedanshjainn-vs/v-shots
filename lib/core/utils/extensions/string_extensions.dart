// ════════════════════════════════════════════════
// Project Lyra — String Extensions
// ════════════════════════════════════════════════

/// Utility extensions on [String].
extension StringExtensions on String {
  /// Capitalize the first letter.
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Title case: capitalize each word.
  String get titleCase {
    return split(' ').map((word) => word.capitalize).join(' ');
  }

  /// Truncate with ellipsis.
  String truncate(int maxLength, {String suffix = '…'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}$suffix';
  }

  /// Whether the string is a valid email.
  bool get isValidEmail {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(this);
  }

  /// Whether the string is a valid URL.
  bool get isValidUrl {
    return Uri.tryParse(this)?.hasScheme ?? false;
  }

  /// Remove all whitespace.
  String get removeWhitespace => replaceAll(RegExp(r'\s+'), '');

  /// Convert "camelCase" or "PascalCase" to "snake_case".
  String get toSnakeCase {
    return replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    ).replaceFirst(RegExp(r'^_'), '');
  }

  /// Null-safe: returns null if the string is empty.
  String? get nullIfEmpty => isEmpty ? null : this;

  /// Parse to int safely.
  int? get toIntOrNull => int.tryParse(this);

  /// Parse to double safely.
  double? get toDoubleOrNull => double.tryParse(this);

  /// Whether the string contains only digits.
  bool get isNumeric => RegExp(r'^\d+$').hasMatch(this);

  /// Mask email for privacy: "j***@example.com"
  String get maskedEmail {
    if (!contains('@')) return this;
    final parts = split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '***@$domain';
    return '${name[0]}${'*' * (name.length - 2)}${name[name.length - 1]}@$domain';
  }
}
