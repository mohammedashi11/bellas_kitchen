/// How an order is paid for. Belongs to the Order domain (an order carries a
/// [PaymentMethod]); the cart's payment selector references it. Pure Dart.
enum PaymentMethod {
  card,
  cash;

  /// Human-readable label for UI.
  String get displayLabel => switch (this) {
        PaymentMethod.card => 'Card',
        PaymentMethod.cash => 'Cash',
      };

  /// Stable string used for Firestore storage (the enum name).
  String get storageKey => name;

  /// Parse a stored [storageKey] back into a [PaymentMethod], defaulting to
  /// [PaymentMethod.card] for unknown/missing values.
  static PaymentMethod fromStorage(String? key) => PaymentMethod.values
      .firstWhere((m) => m.name == key, orElse: () => PaymentMethod.card);
}
