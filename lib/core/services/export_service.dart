import 'package:photo_manager/photo_manager.dart';

class ExportService {
  /// Copies [imagePaths] into the device album "Pictures/BabySnap AI".
  ///
  /// Returns the number of images that were successfully saved.
  /// Only available to premium users — the caller is responsible for gating
  /// access behind a premium check before calling this method.
  Future<int> exportImages(List<String> imagePaths) async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess) return 0;

    var count = 0;
    for (final path in imagePaths) {
      try {
        await PhotoManager.editor.saveImageWithPath(
          path,
          title: 'BabySnap_${DateTime.now().millisecondsSinceEpoch}',
          relativePath: 'Pictures/BabySnap AI',
        );
        count++;
      } catch (_) {
        // Skip files that fail (e.g. file no longer exists).
      }
    }
    return count;
  }

  Future<bool> requestPhotosEditPermission() async {
    final permission = await PhotoManager.requestPermissionExtend();
    return permission.hasAccess;
  }
}
