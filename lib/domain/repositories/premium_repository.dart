import '../entities/premium_state.dart';

abstract class PremiumRepository {
  Future<PremiumState> getPremiumStatus();

  /// [monthly] = true  → starts a monthly subscription purchase.
  /// [monthly] = false → starts a one-time lifetime purchase.
  ///
  /// Throws [PurchasePendingException] if the purchase is awaiting approval.
  /// Throws [Exception] on cancellation or billing failure.
  Future<void> upgradeToPremium({bool monthly = false});

  Future<void> restorePremium();
}
