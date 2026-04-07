import 'package:flutter/foundation.dart';

import '../../core/services/milestone_service.dart';
import '../../domain/entities/gallery_image.dart';
import '../../domain/entities/timeline_entry.dart';
import '../../domain/entities/baby_profile.dart';

class TimelineViewModel extends ChangeNotifier {
  TimelineViewModel(this._milestoneService);

  final MilestoneService _milestoneService;

  List<TimelineEntry> _entries = const [];
  bool _isBuilding = false;

  List<TimelineEntry> get entries => _entries;
  bool get isBuilding => _isBuilding;
  bool get isEmpty => _entries.isEmpty;

  /// Builds the timeline from [images].
  ///
  /// Runs synchronously on the calling isolate (pure Dart, fast enough for
  /// typical gallery sizes ~100–500 images).
  void buildFromImages(
    List<GalleryImage> images, {
    BabyProfile? activeProfile,
  }) {
    _isBuilding = true;
    notifyListeners();

    try {
      _entries = _milestoneService.buildTimeline(
        images,
        birthDate: activeProfile?.birthDate,
      );
    } finally {
      _isBuilding = false;
      notifyListeners();
    }
  }
}
