class Playlist {
  final String id;
  final String title;
  final String image;
  final String description;
  final String videoId;

  Playlist({
    required this.id,
    required this.title,
    required this.image,
    required this.description,
    required this.videoId,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
    id: (json['id'] == null) ? '0' : json['id'],
    title: (json['snippet'] == null || json['snippet']['title'] == null) ? '' : json['snippet']['title'],
    image: (json['snippet'] == null || json['snippet']['thumbnails'] == null || json['snippet']['thumbnails']['high'] == null || json['snippet']['thumbnails']['high']['url'] == null) ? '' : json['snippet']['thumbnails']['high']['url'],
    description: (json['snippet'] == null || json['snippet']['description'] == null) ? '' : json['snippet']['description'],
    videoId: (json['snippet'] == null || json['snippet']['resourceId'] == null || json['snippet']['resourceId']['videoId'] == null) ? '' : json['snippet']['resourceId']['videoId'],
  );
}