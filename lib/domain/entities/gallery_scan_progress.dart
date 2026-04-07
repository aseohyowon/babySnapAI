class GalleryScanProgress {
  const GalleryScanProgress({
    required this.processed,
    required this.total,
    required this.message,
  });

  final int processed;
  final int total;
  final String message;

  double get fraction {
    if (total == 0) {
      return 0;
    }

    return processed / total;
  }
}
