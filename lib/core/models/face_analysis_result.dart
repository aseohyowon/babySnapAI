class FaceAnalysisResult {
  const FaceAnalysisResult({
    required this.hasFace,
    required this.isBaby,
    required this.faceCount,
    this.faceVector,
  });

  final bool hasFace;
  final bool isBaby;
  final int faceCount;
  /// Normalized geometric landmark ratios for face matching (null if not computable).
  final List<double>? faceVector;
}
