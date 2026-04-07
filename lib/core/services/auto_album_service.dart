import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../../domain/entities/auto_album.dart';
import '../../domain/entities/gallery_image.dart';

/// Generates [AutoAlbum]s from a flat list of [GalleryImage]s.
///
/// Algorithm:
///   1. Temporal clustering  — photos within a 4-hour window form one event.
///   2. Scene labeling       — ML Kit ImageLabeler run on up to 2 samples per
///      cluster determines the album type and Korean title.
///   3. Scene-similarity merge — same-day clusters with the same type are
///      merged to avoid fragmented mini-albums.
///   4. Sort newest-first, return up to [maxAlbums] results.
class AutoAlbumService {
  AutoAlbumService()
      : _labeler = ImageLabeler(
          options: ImageLabelerOptions(confidenceThreshold: 0.45),
        );

  final ImageLabeler _labeler;

  static const Duration _eventGap = Duration(hours: 4);
  static const int _minClusterSize = 2;
  static const int maxAlbums = 30;

  // ── Label vocabularies ───────────────────────────────────────────────────
  static const Set<String> _birthdayLabels = {
    'Birthday cake', 'Cake', 'Candle', 'Party', 'Balloon',
    'Confetti', 'Celebration',
  };
  static const Set<String> _outdoorLabels = {
    'Outdoor', 'Nature', 'Sky', 'Plant', 'Tree', 'Grass', 'Cloud',
    'Mountain', 'Flower', 'Garden', 'Forest', 'Park', 'Vegetation',
    'Meadow', 'Field', 'Landscape',
  };
  static const Set<String> _waterLabels = {
    'Swimming pool', 'Water', 'Beach', 'Sea', 'Ocean', 'Swimming',
    'Pool', 'Lake', 'River', 'Waterfall', 'Sand',
  };
  static const Set<String> _winterLabels = {
    'Snow', 'Winter', 'Ice', 'Freezing', 'Frost', 'Snowflake',
  };
  static const Set<String> _animalLabels = {
    'Animal', 'Dog', 'Cat', 'Pet', 'Wildlife', 'Bird', 'Mammal',
    'Puppy', 'Kitten', 'Fish', 'Rabbit', 'Horse', 'Bear',
  };
  static const Set<String> _travelLabels = {
    'Architecture', 'Building', 'Landmark', 'City', 'Street', 'Tower',
    'Church', 'Stadium', 'Monument', 'Castle', 'Museum',
  };
  static const Set<String> _mealtimeLabels = {
    'Food', 'Meal', 'Ingredient', 'Tableware', 'Dish', 'Cuisine',
    'Recipe', 'Plate', 'Bowl', 'Beverage', 'Drink', 'Restaurant',
    'Dessert', 'Fruit', 'Vegetable', 'Baking',
  };

  /// Main entry point. Returns albums sorted newest-first.
  Future<List<AutoAlbum>> generateAlbums(
    List<GalleryImage> images, {
    void Function(int done, int total)? onProgress,
  }) async {
    final candidates = images.where((i) => i.isBaby).toList();
    if (candidates.isEmpty) return [];

    final sorted = [...candidates]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // 1. Split into temporal clusters.
    final clusters = _splitIntoClusters(sorted);

    final albums = <AutoAlbum>[];
    final total = clusters.length;

    for (var i = 0; i < total; i++) {
      final cluster = clusters[i];
      if (cluster.length < _minClusterSize) {
        onProgress?.call(i + 1, total);
        continue;
      }

      // 2. Run ML Kit on representative samples.
      final labels = await _labelCluster(cluster);

      // 3. Classify → type + Korean title + emoji.
      final (type, title, emoji) =
          _classify(labels, cluster.first.createdAt);

      albums.add(AutoAlbum(
        id: 'album_${cluster.first.createdAt.millisecondsSinceEpoch}',
        title: title,
        emoji: emoji,
        type: type,
        images: cluster,
        date: cluster.first.createdAt,
      ));

      onProgress?.call(i + 1, total);
    }

    // 4. Sort newest-first.
    albums.sort((a, b) => b.date.compareTo(a.date));

    // 5. Merge same-day clusters of the same type.
    final merged = _mergeSameDay(albums.take(maxAlbums).toList());

    return merged;
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  /// Splits a time-sorted list into clusters separated by [_eventGap].
  List<List<GalleryImage>> _splitIntoClusters(List<GalleryImage> sorted) {
    if (sorted.isEmpty) return [];
    final clusters = <List<GalleryImage>>[];
    var current = <GalleryImage>[sorted.first];

    for (var i = 1; i < sorted.length; i++) {
      final gap =
          sorted[i].createdAt.difference(sorted[i - 1].createdAt).abs();
      if (gap > _eventGap) {
        clusters.add(current);
        current = [];
      }
      current.add(sorted[i]);
    }
    if (current.isNotEmpty) clusters.add(current);
    return clusters;
  }

  /// Runs ML Kit labeling on up to 2 samples from [cluster].
  Future<Set<String>> _labelCluster(List<GalleryImage> cluster) async {
    final indices = <int>{0};
    if (cluster.length > 2) indices.add(cluster.length ~/ 2);

    final labelSet = <String>{};
    for (final idx in indices) {
      try {
        final inputImage = InputImage.fromFile(cluster[idx].file);
        final labels = await _labeler.processImage(inputImage);
        for (final label in labels) {
          labelSet.add(label.label);
        }
      } catch (_) {
        // Unreadable file — skip silently.
      }
    }
    return labelSet;
  }

  /// Maps a label set to (AlbumType, Korean title, emoji).
  (AlbumType, String, String) _classify(
      Set<String> labels, DateTime date) {
    if (labels.any(_birthdayLabels.contains)) {
      return (AlbumType.birthday, '생일 파티', '🎂');
    }
    if (labels.any(_waterLabels.contains)) {
      return (AlbumType.water, '물놀이', '🏊');
    }
    if (labels.any(_winterLabels.contains)) {
      return (AlbumType.winter, '겨울 추억', '❄️');
    }
    if (labels.any(_animalLabels.contains)) {
      return (AlbumType.animal, '동물 친구들', '🐾');
    }
    if (labels.any(_travelLabels.contains)) {
      return (AlbumType.travel, '여행 기억', '✈️');
    }
    if (labels.any(_mealtimeLabels.contains)) {
      return (AlbumType.mealtime, '식사 시간', '🍽️');
    }
    if (labels.any(_outdoorLabels.contains)) {
      return (AlbumType.outdoor, '야외 나들이', '🌳');
    }

    // Season fallback.
    final m = date.month;
    if (m >= 3 && m <= 5) return (AlbumType.season, '봄 나들이', '🌸');
    if (m >= 6 && m <= 8) return (AlbumType.season, '여름 추억', '☀️');
    if (m >= 9 && m <= 11) return (AlbumType.season, '가을 소풍', '🍁');
    return (AlbumType.season, '겨울 이야기', '⛄');
  }

  /// Merges consecutive albums that share the same day and same [AlbumType].
  List<AutoAlbum> _mergeSameDay(List<AutoAlbum> albums) {
    if (albums.length <= 1) return albums;
    final result = <AutoAlbum>[];
    var i = 0;

    while (i < albums.length) {
      var current = albums[i];

      while (i + 1 < albums.length) {
        final next = albums[i + 1];
        final sameDay = current.date.year == next.date.year &&
            current.date.month == next.date.month &&
            current.date.day == next.date.day;
        final sameType = current.type == next.type;

        if (sameDay && sameType) {
          final combinedImages = [...current.images, ...next.images]
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          current = AutoAlbum(
            id: current.id,
            title: current.title,
            emoji: current.emoji,
            type: current.type,
            images: combinedImages,
            date: current.date,
          );
          i++;
        } else {
          break;
        }
      }

      result.add(current);
      i++;
    }

    return result;
  }

  void close() => _labeler.close();
}
