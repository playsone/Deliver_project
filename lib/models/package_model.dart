// file: lib/models/package_model.dart

class Package {
  final String id;
  final String title;
  final String location;
  final String destination;
  final String? imageUrl;

  Package({
    required this.id,
    required this.title,
    required this.location,
    required this.destination,
    this.imageUrl,
  });
}
