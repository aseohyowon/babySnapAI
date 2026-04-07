import '../entities/premium_state.dart';
import '../repositories/premium_repository.dart';

class GetPremiumStatusUseCase {
  GetPremiumStatusUseCase(this._repository);

  final PremiumRepository _repository;

  Future<PremiumState> execute() => _repository.getPremiumStatus();

  /// [monthly] = true → monthly subscription; false → lifetime.
  Future<void> upgradeToPremium({bool monthly = false}) =>
      _repository.upgradeToPremium(monthly: monthly);

  Future<void> restorePremium() => _repository.restorePremium();
}
