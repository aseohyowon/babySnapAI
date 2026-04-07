import 'package:flutter/foundation.dart';

import '../../core/services/photo_ranking_service.dart';
import '../../domain/entities/gallery_image.dart';

enum BestPhotosState { idle, analyzing, done, error }

class BestPhotosViewModel extends ChangeNotifier {
  final PhotoRankingService _rankingService;
  bool _disposed = false;

  BestPhotosState _state = BestPhotosState.idle;
  List<PhotoScore> _scores = [];
  int _progress = 0;
  int _total = 0;
  String? _errorMessage;

  BestPhotosViewModel({PhotoRankingService? rankingService})
      : _rankingService = rankingService ?? PhotoRankingService();

  BestPhotosState get state => _state;
  List<PhotoScore> get scores => _scores;
  int get progress => _progress;
  int get total => _total;
  String? get errorMessage => _errorMessage;
  bool get isAnalyzing => _state == BestPhotosState.analyzing;

  double get progressFraction =>
      _total == 0 ? 0.0 : (_progress / _total).clamp(0.0, 1.0);

  Future<void> analyze(List<GalleryImage> images) async {
    if (_state == BestPhotosState.analyzing) return;

    _state = BestPhotosState.analyzing;
    _progress = 0;
    _total = images.length;
    _scores = [];
    _errorMessage = null;
    _notifySafe();

    try {
      final results = await _rankingService.rankTopPhotos(
        images,
        topN: 10,
        batchSize: 6,
        onProgress: (done, total) {
          if (_disposed) return;
          _progress = done;
          _total = total;
          _notifySafe();
        },
        onPartialResults: (partial) {
          if (_disposed) return;
          // Show live-updating top-N while analysis is still running.
          _scores = partial;
          _notifySafe();
        },
      );
      if (!_disposed) {
        _scores = results;
        _state = BestPhotosState.done;
      }
    } catch (e) {
      if (!_disposed) {
        _errorMessage = '분석 중 오류가 발생했습니다: $e';
        _state = BestPhotosState.error;
      }
    }
    _notifySafe();
  }

  void _notifySafe() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _rankingService.close();
    super.dispose();
  }
}

