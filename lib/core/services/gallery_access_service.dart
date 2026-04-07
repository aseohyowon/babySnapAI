import 'package:photo_manager/photo_manager.dart';

class GalleryAccessService {
  Future<bool> requestPermission() async {
    final permission = await PhotoManager.requestPermissionExtend();
    return permission.hasAccess;
  }

  Future<List<AssetEntity>> fetchImageAssets() async {
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

    return allAlbum.getAssetListRange(start: 0, end: totalAssets);
  }
}
