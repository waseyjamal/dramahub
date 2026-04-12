/// Model class for Drama
class DramaModel {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final int totalEpisodes;
  final String genre;
  final double rating;
  final int releaseYear;

  final bool isActive;
  final int order;
  final String posterImage;
  final String bannerImage;

  DramaModel({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.totalEpisodes,
    required this.genre,
    required this.rating,
    required this.releaseYear,
    this.isActive = true,
    this.order = 0,
    String? posterImage,
    String? bannerImage,
  }) : posterImage = posterImage ?? imageUrl,
       bannerImage = bannerImage ?? imageUrl;

  /// Convert from JSON
  factory DramaModel.fromJson(Map<String, dynamic> json) {
    return DramaModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      totalEpisodes: json['totalEpisodes'] ?? 0,
      genre: json['genre'] ?? '',
      rating: (json['rating'] ?? 0.0).toDouble(),
      releaseYear: json['releaseYear'] ?? 0,
      isActive: json['isActive'] ?? true, // Default to true if missing
      order: json['order'] ?? 0,
      posterImage:
          json['posterImage'], // Constructor handles fallback to imageUrl
      bannerImage:
          json['bannerImage'], // Constructor handles fallback to imageUrl
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'totalEpisodes': totalEpisodes,
      'genre': genre,
      'rating': rating,
      'releaseYear': releaseYear,
      'isActive': isActive,
      'order': order,
      'posterImage': posterImage,
      'bannerImage': bannerImage,
    };
  }
}
