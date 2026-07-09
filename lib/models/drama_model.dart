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

  // Coming Soon fields
  final bool isComingSoon;
  final String? premiereDate;
  final String? addedOn;

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
    this.isComingSoon = false,
    this.premiereDate,
    this.addedOn,
  }) : posterImage = posterImage ?? imageUrl,
       bannerImage = bannerImage ?? imageUrl;

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
      isActive: json['isActive'] ?? true,
      order: json['order'] ?? 0,
      posterImage: json['posterImage'],
      bannerImage: json['bannerImage'],
      isComingSoon: json['isComingSoon'] ?? false,
      premiereDate: json['premiereDate'],
      addedOn: json['addedOn'],
    );
  }

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
      'isComingSoon': isComingSoon,
      'premiereDate': premiereDate,
      'addedOn': addedOn,
    };
  }
}