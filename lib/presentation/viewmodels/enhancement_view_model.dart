import 'package:flutter/foundation.dart';

import '../../core/services/image_enhancement_service.dart';

enum EnhancementStatus {
  idle,
  processing,
  done,
  saving,
  saved,
  error,
}

class EnhancementViewModel extends ChangeNotifier {
  EnhancementViewModel({
    required String sourcePath,
    required ImageEnhancementService service,
  })  : _sourcePath = sourcePath,
        _service = service;

  final String _sourcePath;
  final ImageEnhancementService _service;

  String get sourcePath => _sourcePath;

  EnhancementParams _params = const EnhancementParams();
  EnhancementParams get params => _params;

  String? _enhancedPath;
  String? get enhancedPath => _enhancedPath;

  bool get hasResult => _enhancedPath != null;

  EnhancementStatus _status = EnhancementStatus.idle;
  EnhancementStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get isBusy =>
      _status == EnhancementStatus.processing ||
      _status == EnhancementStatus.saving;

  /// Queued params currently being processed (null when idle).
  EnhancementParams? _pendingParams;

  // ── Public API ─────────────────────────────────────────────────────────────

  void updateBrightness(double value) => _updateParam(
        _params.copyWith(brightness: value),
      );

  void updateContrast(double value) => _updateParam(
        _params.copyWith(contrast: value),
      );

  void updateSharpness(double value) => _updateParam(
        _params.copyWith(sharpness: value),
      );

  void resetParams() {
    _updateParam(const EnhancementParams());
  }

  Future<bool> saveEnhanced() async {
    if (_enhancedPath == null) return false;
    _status = EnhancementStatus.saving;
    _errorMessage = null;
    notifyListeners();

    final ok = await _service.saveEnhancedImage(_enhancedPath!);
    _status = ok ? EnhancementStatus.saved : EnhancementStatus.error;
    if (!ok) _errorMessage = '저장에 실패했습니다. 권한을 확인해 주세요.';
    notifyListeners();
    return ok;
  }

  // ── Internal helpers ───────────────────────────────────────────────────────

  /// Debounce: if a processing run is already in progress, store the most
  /// recent params as pending and process them once the current run finishes.
  void _updateParam(EnhancementParams newParams) {
    if (_params == newParams) return;
    _params = newParams;
    notifyListeners();

    if (_status == EnhancementStatus.processing) {
      _pendingParams = newParams;
      return;
    }
    _runEnhancement(newParams);
  }

  Future<void> _runEnhancement(EnhancementParams params) async {
    _status = EnhancementStatus.processing;
    _errorMessage = null;
    notifyListeners();

    final result = await _service.enhanceImage(_sourcePath, params);

    // If another set of params arrived while we were processing, use those.
    final next = _pendingParams;
    _pendingParams = null;

    if (result == null) {
      _status = EnhancementStatus.error;
      _errorMessage = '이미지 처리에 실패했습니다.';
      notifyListeners();
      return;
    }

    _enhancedPath = result;
    _status = EnhancementStatus.done;
    notifyListeners();

    if (next != null && next != _params) {
      _params = next;
      notifyListeners();
      _runEnhancement(next);
    }
  }
}
