import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of a [InAppPurchaseService.buyPremium] call.
enum IAPOutcome {
  /// Purchase completed ??premium granted and saved to SharedPreferences.
  purchased,

  /// Purchase is awaiting bank / carrier approval.  Does NOT grant premium yet.
  pending,

  /// User dismissed the billing dialog.
  canceled,

  /// Billing error during the purchase flow.
  failed,
}

/// Wraps the [InAppPurchase] plugin with Future-based purchase/restore methods.
///
/// **Product IDs** (must be registered in Google Play Console):
///   ??[productId]        ??one-time lifetime purchase (non-consumable)
///   ??[monthlyProductId] ??monthly auto-renewing subscription
///
/// Call [initialize] once at app startup before any other method.
class InAppPurchaseService {
  InAppPurchaseService();

  // ?? Product IDs ???????????????????????????????????????????????????????????
  static const String productId        = 'babysnap_ai_premium';
  static const String monthlyProductId = 'babysnap_ai_premium_monthly';

  // ?? SharedPreferences keys ????????????????????????????????????????????????
  static const String _statusKey      = 'baby_gallery_premium_status';
  static const String _purchasedAtKey = 'baby_gallery_premium_purchased_at';
  static const String _typeKey        = 'baby_gallery_premium_type';    // 'lifetime' | 'monthly'
  static const String _expiresAtKey   = 'baby_gallery_premium_expires_at'; // ISO-8601 for monthly
  static const String _pendingKey     = 'baby_gallery_premium_pending';

  // A cached local subscription period. The platform handles real renewals;
  // this is an offline fallback so the UI can display an approximate expiry.
  static const Duration _monthDuration = Duration(days: 31);

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Completer<IAPOutcome>? _pendingCompleter;
  bool _isRestoring = false;

  // Both product details cached after the first queryProductDetails call.
  final Map<String, ProductDetails> _cachedProducts = {};

  // ?? Lifecycle ?????????????????????????????????????????????????????????????

  /// Start listening to the IAP purchase stream.
  /// Call this once, early in the app lifecycle (e.g. ServiceLocator.initialize).
  void initialize() {
    _subscription = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        debugPrint('[IAP] purchaseStream error: $error');
        final c = _pendingCompleter;
        _pendingCompleter = null;
        c?.completeError(error);
      },
    );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  // ?? Public API ????????????????????????????????????????????????????????????

  /// Fast, offline-friendly check: returns true if SharedPreferences says
  /// the user has a valid (non-expired) premium status.
  Future<bool> getCachedPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_statusKey) != 'premium') return false;
    // Monthly subscriptions: treat as expired if the locally cached expiry
    // has passed.  The real renewal state is resolved by restorePurchases().
    final expiresRaw = prefs.getString(_expiresAtKey);
    if (expiresRaw != null) {
      final expires = DateTime.tryParse(expiresRaw);
      if (expires != null && DateTime.now().isAfter(expires)) {
        debugPrint('[IAP] Cached subscription appears expired ??run restore to confirm');
        return false;
      }
    }
    return true;
  }

  /// Returns true if there is a purchase awaiting bank / carrier approval.
  Future<bool> hasPendingPurchase() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingKey) ?? false;
  }

  /// Initiates a purchase through the platform billing system.
  ///
  /// [monthly] = true  ??monthly subscription ([monthlyProductId])
  /// [monthly] = false ??one-time lifetime purchase ([productId])
  ///
  /// Returns [IAPOutcome] indicating what happened.
  /// Throws on unrecoverable errors (store unavailable, product not found).
  Future<IAPOutcome> buyPremium({bool monthly = false}) async {
    if (_pendingCompleter != null) {
      throw StateError('寃곗젣媛 ?대? 吏꾪뻾 以묒엯?덈떎');
    }

    final isAvailable = await InAppPurchase.instance.isAvailable();
    if (!isAvailable) {
      throw Exception('Google Play???ъ슜?????놁뒿?덈떎. ?ㅽ듃?뚰겕 ?곌껐???뺤씤?댁＜?몄슂.');
    }

    final targetId = monthly ? monthlyProductId : productId;
    final details = await _fetchProduct(targetId);
    if (details == null) {
      throw Exception('?곹뭹 ?뺣낫瑜?遺덈윭?????놁뒿?덈떎.\n'
          'Play Console??"$targetId"??媛) ?깅줉?섏뼱 ?덈뒗吏 ?뺤씤?댁＜?몄슂.');
    }

    _pendingCompleter = Completer<IAPOutcome>();
    _isRestoring = false;

    final purchaseParam = PurchaseParam(productDetails: details);
    try {
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      _pendingCompleter = null;
      rethrow;
    }

    return _pendingCompleter!.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        _pendingCompleter = null;
        return IAPOutcome.canceled;
      },
    );
  }

  /// Queries the store for previous purchases and restores premium if found.
  ///
  /// Returns true if a premium purchase was restored.
  Future<bool> restorePurchases() async {
    if (_pendingCompleter != null) {
      throw StateError('寃곗젣媛 ?대? 吏꾪뻾 以묒엯?덈떎');
    }

    final isAvailable = await InAppPurchase.instance.isAvailable();
    if (!isAvailable) {
      // Unable to reach the store ??fall back to the local cache so the user
      // isn't blocked while offline.
      return getCachedPremiumStatus();
    }

    _pendingCompleter = Completer<IAPOutcome>();
    _isRestoring = true;

    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      _pendingCompleter = null;
      _isRestoring = false;
      rethrow;
    }

    // Give the store up to 30 s to deliver restored purchases.
    final outcome = await _pendingCompleter!.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pendingCompleter = null;
        _isRestoring = false;
        return IAPOutcome.canceled; // timeout = no purchases found
      },
    );
    return outcome == IAPOutcome.purchased;
  }

  // ?? Stream handler ????????????????????????????????????????????????????????

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    IAPOutcome? resolvedOutcome;

    for (final purchase in purchases) {
      // Always complete pending transactions to avoid billing issues.
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }

      // Only process our known product IDs.
      if (purchase.productID != productId &&
          purchase.productID != monthlyProductId) continue;

      final isMonthly = purchase.productID == monthlyProductId;

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _setPremiumLocally(monthly: isMonthly);
          await _clearPendingFlag();
          resolvedOutcome = IAPOutcome.purchased;
          debugPrint('[IAP] Purchase/restore success ??type: ${isMonthly ? "monthly" : "lifetime"}');
          break;

        case PurchaseStatus.pending:
          // Bank / carrier approval required. Mark locally so the UI can
          // display an informational message on the next app launch.
          await _markPurchasePending();
          resolvedOutcome = IAPOutcome.pending;
          debugPrint('[IAP] Purchase pending approval');
          break;

        case PurchaseStatus.error:
          debugPrint('[IAP] Purchase error: ${purchase.error}');
          resolvedOutcome = IAPOutcome.failed;
          break;

        case PurchaseStatus.canceled:
          resolvedOutcome = IAPOutcome.canceled;
          break;
      }
    }

    if (_isRestoring) {
      final c = _pendingCompleter;
      _pendingCompleter = null;
      _isRestoring = false;
      c?.complete(resolvedOutcome ?? IAPOutcome.canceled);
    } else if (resolvedOutcome != null) {
      final c = _pendingCompleter;
      _pendingCompleter = null;
      c?.complete(resolvedOutcome);
    }
  }

  // ?? Helpers ???????????????????????????????????????????????????????????????

  /// Fetches product details for [id], caching both products in one query.
  Future<ProductDetails?> _fetchProduct(String id) async {
    if (_cachedProducts.containsKey(id)) return _cachedProducts[id];

    try {
      final response = await InAppPurchase.instance
          .queryProductDetails({productId, monthlyProductId});

      for (final p in response.productDetails) {
        _cachedProducts[p.id] = p;
        debugPrint('[IAP] Loaded product: ${p.id} (${p.price})');
      }
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('[IAP] Products not found in Play Console: ${response.notFoundIDs}. '
            'Make sure they are published in the internal/closed track.');
      }
    } catch (e) {
      debugPrint('[IAP] queryProductDetails error: $e');
    }

    return _cachedProducts[id];
  }

  /// Persists the premium grant to SharedPreferences, including subscription
  /// type and a locally estimated expiry for monthly subscriptions.
  Future<void> _setPremiumLocally({required bool monthly}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statusKey, 'premium');
    await prefs.setString(_typeKey, monthly ? 'monthly' : 'lifetime');
    await prefs.setString(_purchasedAtKey, DateTime.now().toIso8601String());
    if (monthly) {
      final expires = DateTime.now().add(_monthDuration);
      await prefs.setString(_expiresAtKey, expires.toIso8601String());
    } else {
      await prefs.remove(_expiresAtKey); // lifetime never expires
    }
    debugPrint('[IAP] Premium saved ??type: ${monthly ? "monthly" : "lifetime"}');
  }

  Future<void> _markPurchasePending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingKey, true);
  }

  Future<void> _clearPendingFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
  }
}
