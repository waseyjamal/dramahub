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

  // Latest episode info — set when you upload a new episode
  // Eliminates all episode fetches from home screen
  final int latestEpisodeNumber;
  final String latestEpisodeDate;

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
    this.latestEpisodeNumber = 0,
    this.latestEpisodeDate = '',
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
      latestEpisodeNumber: json['latest_episode_number'] ?? 0,
      latestEpisodeDate: json['latest_episode_date'] ?? '',
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
      'latest_episode_number': latestEpisodeNumber,
      'latest_episode_date': latestEpisodeDate,
    };
  }
}