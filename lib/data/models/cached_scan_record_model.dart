import '../../domain/entities/gallery_image.dart';

class CachedScanRecordModel {
  const CachedScanRecordModel({
    required this.assetId,
    required this.path,
    required this.createdAt,
    required this.modifiedAt,
    required this.hasFace,
    required this.isBaby,
    required this.faceCount,
    this.faceVector,
  });

  final String assetId;
  final String path;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final bool hasFace;
  final bool isBaby;
  final int faceCount;
  final List<double>? faceVector;

  factory CachedScanRecordModel.fromJson(Map<String, dynamic> json) {
    return CachedScanRecordModel(
      assetId: json['assetId'] as String,
      path: json['path'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      hasFace: json['hasFace'] as bool,
      isBaby: json['isBaby'] as bool,
      faceCount: json['faceCount'] as int,
      faceVector: json.containsKey('faceVector')
          ? (json['faceVector'] as List<dynamic>)
              .map((e) => (e as num).toDouble())
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'assetId': assetId,
      'path': path,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
      'hasFace': hasFace,
      'isBaby': isBaby,
      'faceCount': faceCount,
      if (faceVector != null && faceVector!.isNotEmpty) 'faceVector': faceVector,
    };
  }

  CachedScanRecordModel copyWith({
    String? path,
    DateTime? createdAt,
    DateTime? modifiedAt,
    bool? hasFace,
    bool? isBaby,
    int? faceCount,
    List<double>? faceVector,
  }) {
    return CachedScanRecordModel(
      assetId: assetId,
      path: path ?? this.path,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      hasFace: hasFace ?? this.hasFace,
      isBaby: isBaby ?? this.isBaby,
      faceCount: faceCount ?? this.faceCount,
      faceVector: faceVector ?? this.faceVector,
    );
  }

  GalleryImage toEntity() {
    return GalleryImage(
      assetId: assetId,
      path: path,
      createdAt: createdAt,
      faceCount: faceCount,
      isBaby: isBaby,
      faceVector: faceVector,
    );
  }
}
