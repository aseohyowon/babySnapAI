import 'package:flutter/foundation.dart';

import '../../core/services/auto_album_service.dart';
import '../../domain/entities/auto_album.dart';
import '../../domain/entities/gallery_image.dart';

enum AutoAlbumState { idle, generating, done, error }

class AutoAlbumViewModel extends ChangeNotifier {
  AutoAlbumViewModel({AutoAlbumService? service})
      : _service = service ?? AutoAlbumService();

  final AutoAlbumService _service;

  AutoAlbumState _state = AutoAlbumState.idle;
  List<AutoAlbum> _albums = [];
  int _progress = 0;
  int _total = 0;
  String? _errorMessage;

  AutoAlbumState get state => _state;
  List<AutoAlbum> get albums => _albums;
  int get progress => _progress;
  int get total => _total;
  String? get errorMessage => _errorMessage;
  bool get isGenerating => _state == AutoAlbumState.generating;

  double get progressFraction =>
      _total == 0 ? 0.0 : (_progress / _total).clamp(0.0, 1.0);

  Future<void> generate(List<GalleryImage> images) async {
    if (_state == AutoAlbumState.generating) return;

    _state = AutoAlbumState.generating;
    _progress = 0;
    _total = images.where((i) => i.isBaby).length;
    _albums = [];
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await _service.generateAlbums(
        images,
        onProgress: (done, total) {
          _progress = done;
          _total = total;
          notifyListeners();
        },
      );
      _albums = results;
      _state = AutoAlbumState.done;
    } catch (e) {
      _errorMessage = '앨범 생성 중 오류가 발생했습니다: $e';
      _state = AutoAlbumState.error;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _service.close();
    super.dispose();
  }
}
