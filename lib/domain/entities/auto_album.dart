import 'package:flutter/material.dart';

import 'gallery_image.dart';

/// Semantic category detected for an auto-generated album.
enum AlbumType {
  birthday,
  outdoor,
  water,
  winter,
  animal,
  travel,
  mealtime,
  season,
  event,
}

extension AlbumTypeVisuals on AlbumType {
  Color get color {
    switch (this) {
      case AlbumType.birthday:
        return const Color(0xFFEC4899);
      case AlbumType.outdoor:
        return const Color(0xFF10B981);
      case AlbumType.water:
        return const Color(0xFF3B82F6);
      case AlbumType.winter:
        return const Color(0xFF60A5FA);
      case AlbumType.animal:
        return const Color(0xFFF97316);
      case AlbumType.travel:
        return const Color(0xFF8B5CF6);
      case AlbumType.mealtime:
        return const Color(0xFFF59E0B);
      case AlbumType.season:
        return const Color(0xFF34D399);
      case AlbumType.event:
        return const Color(0xFF6366F1);
    }
  }
}

/// An automatically generated album grouping related [GalleryImage]s.
class AutoAlbum {
  const AutoAlbum({
    required this.id,
    required this.title,
    required this.emoji,
    required this.type,
    required this.images,
    required this.date,
  });

  final String id;
  final String title;
  final String emoji;
  final AlbumType type;
  final List<GalleryImage> images;

  /// Start date of the earliest image in this album.
  final DateTime date;

  /// End date of the latest image in this album.
  DateTime get endDate => images
      .map((i) => i.createdAt)
      .reduce((a, b) => a.isAfter(b) ? a : b);

  /// Best cover image: highest face count, fallback to middle image.
  GalleryImage get coverImage {
    final withFaces = images.where((i) => i.faceCount > 0).toList();
    if (withFaces.isNotEmpty) {
      return withFaces.reduce(
          (a, b) => a.faceCount >= b.faceCount ? a : b);
    }
    return images[images.length ~/ 2];
  }
}
