import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/in_app_purchase_service.dart';
import '../../domain/entities/premium_state.dart';
import '../../domain/repositories/premium_repository.dart';

class PremiumRepositoryImpl implements PremiumRepository {
  PremiumRepositoryImpl(this._iapService);

  final InAppPurchaseService _iapService;

  // SharedPreferences keys (mirror InAppPurchaseService constants).
  static const String _statusKey      = 'baby_gallery_premium_status';
  static const String _purchasedAtKey = 'baby_gallery_premium_purchased_at';
  static const String _typeKey        = 'baby_gallery_premium_type';
  static const String _expiresAtKey   = 'baby_gallery_premium_expires_at';

  @override
  Future<PremiumState> getPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final statusRaw    = prefs.getString(_statusKey) ?? 'free';
    final typeRaw      = prefs.getString(_typeKey)   ?? 'lifetime';
    final purchasedRaw = prefs.getString(_purchasedAtKey);
    final expiresRaw   = prefs.getString(_expiresAtKey);

    final status = statusRaw == 'premium'
        ? PremiumStatus.premium
        : PremiumStatus.free;
    final type = typeRaw == 'monthly'
        ? PremiumType.monthly
        : PremiumType.lifetime;
    final purchasedAt =
        purchasedRaw != null ? DateTime.tryParse(purchasedRaw) : null;
    final expiresAt =
        expiresRaw != null ? DateTime.tryParse(expiresRaw) : null;

    return PremiumState(
      status: status,
      purchasedAt: purchasedAt,
      premiumType: type,
      expiresAt: expiresAt,
    );
  }

  @override
  Future<void> upgradeToPremium({bool monthly = false}) async {
    final outcome = await _iapService.buyPremium(monthly: monthly);
    switch (outcome) {
      case IAPOutcome.purchased:
        return; // InAppPurchaseService already wrote to SharedPreferences
      case IAPOutcome.pending:
        throw const PurchasePendingException();
      case IAPOutcome.canceled:
        throw Exception('구매가 취소되었습니다');
      case IAPOutcome.failed:
        throw Exception('결제 처리 중 오류가 발생했습니다. 다시 시도해주세요.');
    }
  }

  @override
  Future<void> restorePremium() async {
    final restored = await _iapService.restorePurchases();
    if (!restored) {
      // restorePurchases() already tried the local cache as a fallback;
      // if it returned false there is genuinely no premium to restore.
      // We do not throw — callers check isPremium after this returns.
    }
  }
}
