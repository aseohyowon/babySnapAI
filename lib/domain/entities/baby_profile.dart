class BabyProfile {
  const BabyProfile({
    required this.id,
    required this.name,
    required this.referencePhotoPath,
    required this.faceVectors,
    this.birthDate,
  });

  final String id;
  final String name;
  final String referencePhotoPath;
  /// Multiple reference face vectors — matches improve when several angles are registered.
  final List<List<double>> faceVectors;
  /// Optional birth date — used for age labels and milestone detection in the timeline.
  final DateTime? birthDate;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'referencePhotoPath': referencePhotoPath,
        'faceVectors': faceVectors,
        if (birthDate != null) 'birthDate': birthDate!.toIso8601String(),
      };

  factory BabyProfile.fromJson(Map<String, dynamic> json) {
    final List<List<double>> vectors;
    if (json.containsKey('faceVectors')) {
      vectors = (json['faceVectors'] as List<dynamic>)
          .map((v) => (v as List<dynamic>)
              .map((e) => (e as num).toDouble())
              .toList())
          .toList();
    } else if (json.containsKey('faceVector')) {
      // Legacy: single vector saved under old key
      vectors = [
        (json['faceVector'] as List<dynamic>)
            .map((e) => (e as num).toDouble())
            .toList()
      ];
    } else {
      vectors = [];
    }
    final birthDateStr = json['birthDate'] as String?;
    return BabyProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      referencePhotoPath: json['referencePhotoPath'] as String,
      faceVectors: vectors,
      birthDate: birthDateStr != null ? DateTime.tryParse(birthDateStr) : null,
    );
  }

  BabyProfile copyWith({
    String? name,
    String? referencePhotoPath,
    List<List<double>>? faceVectors,
    Object? birthDate = _sentinel,
  }) {
    return BabyProfile(
      id: id,
      name: name ?? this.name,
      referencePhotoPath: referencePhotoPath ?? this.referencePhotoPath,
      faceVectors: faceVectors ?? this.faceVectors,
      birthDate: identical(birthDate, _sentinel)
          ? this.birthDate
          : birthDate as DateTime?,
    );
  }

  static const Object _sentinel = Object();
}
