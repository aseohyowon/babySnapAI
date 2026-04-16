import 'package:photo_manager/photo_manager.dart';

class GalleryAccessService {
  Future<bool> requestPermission() async {
    final permission = await PhotoManager.requestPermissionExtend();
    return permission.hasAccess;
  }

  Future<List<AssetEntity>> fetchImageAssets({
    int? limit,
    DateTime? newerThan,
  }) async {
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      return <AssetEntity>[];
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (albums.isEmpty) {
      return <AssetEntity>[];
    }

    final allAlbum = albums.first;
    final totalAssets = await allAlbum.assetCountAsync;
    if (totalAssets == 0) {
      return <AssetEntity>[];
    }

    if (limit != null) {
      final end = limit.clamp(0, totalAssets);
      return allAlbum.getAssetListRange(start: 0, end: end);
    }

    if (newerThan != null) {
      const pageSize = 500;
      final results = <AssetEntity>[];
      for (var start = 0; start < totalAssets; start += pageSize) {
        final end = (start + pageSize).clamp(0, totalAssets);
        final page = await allAlbum.getAssetListRange(start: start, end: end);
        if (page.isEmpty) break;

        results.addAll(
          page.where((asset) => asset.createDateTime.toLocal().isAfter(newerThan)),
        );

        final oldestInPage = page.last.createDateTime.toLocal();
        if (!oldestInPage.isAfter(newerThan)) {
          break;
        }
      }
      return results;
    }

    return allAlbum.getAssetListRange(start: 0, end: totalAssets);
  }
}
