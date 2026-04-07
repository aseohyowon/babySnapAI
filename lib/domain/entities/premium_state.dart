enum PremiumStatus {
  free,
  premium,
}

/// Whether the user purchased a one-time lifetime licence or a monthly subscription.
enum PremiumType {
  lifetime,
  monthly,
}

/// Thrown by [PremiumRepository.upgradeToPremium] when the purchase is
/// awaiting bank / carrier approval.
class PurchasePendingException implements Exception {
  const PurchasePendingException();
  @override
  String toString() =>
      '결제 승인 대기 중입니다. 승인이 완료되면 앱을 재시작하면 자동으로 적용됩니다.';
}

class PremiumState {
  const PremiumState({
    required this.status,
    required this.purchasedAt,
    this.premiumType = PremiumType.lifetime,
    this.expiresAt,
  });

  final PremiumStatus status;
  final DateTime? purchasedAt;

  /// Whether this is a lifetime or monthly subscription purchase.
  final PremiumType premiumType;

  /// Non-null for monthly subscriptions.  Null for lifetime purchases.
  /// Derived from the local cache — the platform handles real renewal.
  final DateTime? expiresAt;

  bool get isPremium {
    if (status != PremiumStatus.premium) return false;
    // Monthly subscription: check locally cached expiry as a best-effort guard.
    // The authoritative check is performed by restorePurchases() on each launch.
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return false;
    return true;
  }

  bool get isMonthly => premiumType == PremiumType.monthly;
}
