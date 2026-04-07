import '../../domain/entities/gallery_image.dart';

class GallerySection {
  const GallerySection({required this.title, required this.images});

  final String title;
  final List<GalleryImage> images;
}
