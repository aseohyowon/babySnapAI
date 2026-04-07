import '../services/admob_service.dart';
import '../services/export_service.dart';
import '../services/face_detection_service.dart';
import '../services/gallery_access_service.dart';
import '../services/gallery_cache_service.dart';
import '../services/in_app_purchase_service.dart';
import '../../data/datasources/device_gallery_data_source.dart';
import '../../data/repositories/baby_profile_repository_impl.dart';
import '../../data/repositories/favorites_repository_impl.dart';
import '../../data/repositories/image_repository_impl.dart';
import '../../data/repositories/premium_repository_impl.dart';
import '../../domain/repositories/baby_profile_repository.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../../domain/repositories/image_repository.dart';
import '../../domain/repositories/premium_repository.dart';
import '../../domain/usecases/get_favorites_usecase.dart';
import '../../domain/usecases/get_images_with_faces_usecase.dart';
import '../../domain/usecases/get_premium_status_usecase.dart';
import '../../domain/usecases/manage_baby_profiles_usecase.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();

  late GalleryAccessService _galleryAccessService;
  late FaceDetectionService _faceDetectionService;
  late GalleryCacheService _galleryCacheService;
  late ExportService _exportService;
  late AdMobService _adMobService;
  late InAppPurchaseService _inAppPurchaseService;

  late ImageRepository _imageRepository;
  late FavoritesRepository _favoritesRepository;
  late PremiumRepository _premiumRepository;
  late BabyProfileRepository _babyProfileRepository;

  late GetImagesWithFacesUseCase _getImagesWithFacesUsecase;
  late GetFavoritesUseCase _getFavoritesUsecase;
  late GetPremiumStatusUseCase _getPremiumStatusUsecase;
  late ManageBabyProfilesUseCase _manageBabyProfilesUsecase;

  ServiceLocator._internal();

  factory ServiceLocator() {
    return _instance;
  }

  static Future<void> initialize() async {
    final instance = ServiceLocator();

    instance._galleryAccessService = GalleryAccessService();
    instance._faceDetectionService = FaceDetectionService();
    instance._galleryCacheService = GalleryCacheService();
    instance._exportService = ExportService();
    instance._adMobService = AdMobService();
    instance._inAppPurchaseService = InAppPurchaseService()
      ..initialize();

    final dataSource = DeviceGalleryDataSource(instance._galleryAccessService);
    instance._imageRepository = ImageRepositoryImpl(
      dataSource: dataSource,
      faceDetectionService: instance._faceDetectionService,
      cacheService: instance._galleryCacheService,
    );

    instance._favoritesRepository = FavoritesRepositoryImpl();
    instance._premiumRepository = PremiumRepositoryImpl(instance._inAppPurchaseService);
    instance._babyProfileRepository = BabyProfileRepositoryImpl();

    instance._getImagesWithFacesUsecase =
        GetImagesWithFacesUseCase(instance._imageRepository);
    instance._getFavoritesUsecase =
        GetFavoritesUseCase(instance._favoritesRepository);
    instance._getPremiumStatusUsecase =
        GetPremiumStatusUseCase(instance._premiumRepository);
    instance._manageBabyProfilesUsecase = ManageBabyProfilesUseCase(
      instance._babyProfileRepository,
      instance._faceDetectionService,
    );
  }

  GalleryAccessService get galleryAccessService => _galleryAccessService;
  FaceDetectionService get faceDetectionService => _faceDetectionService;
  GalleryCacheService get galleryCacheService => _galleryCacheService;
  ExportService get exportService => _exportService;
  AdMobService get adMobService => _adMobService;

  ImageRepository get imageRepository => _imageRepository;
  FavoritesRepository get favoritesRepository => _favoritesRepository;
  PremiumRepository get premiumRepository => _premiumRepository;

  GetImagesWithFacesUseCase get getImagesWithFacesUsecase =>
      _getImagesWithFacesUsecase;
  GetFavoritesUseCase get getFavoritesUsecase => _getFavoritesUsecase;
  GetPremiumStatusUseCase get getPremiumStatusUsecase =>
      _getPremiumStatusUsecase;
  ManageBabyProfilesUseCase get manageBabyProfilesUsecase =>
      _manageBabyProfilesUsecase;
}
