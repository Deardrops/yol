class WallpaperPost {
  final String title;
  final String imageUrl;
  final String author;

  const WallpaperPost({
    required this.title,
    required this.imageUrl,
    required this.author,
  });

  @override
  String toString() => 'WallpaperPost(author: $author, url: $imageUrl)';
}
