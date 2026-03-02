class WallpaperPost {
  final String title;
  final String imageUrl;
  final String author;
  /// Source image dimensions from Reddit's preview metadata.
  /// Both are 0 if the metadata is unavailable.
  final int sourceWidth;
  final int sourceHeight;

  const WallpaperPost({
    required this.title,
    required this.imageUrl,
    required this.author,
    this.sourceWidth = 0,
    this.sourceHeight = 0,
  });

  /// Returns true when the image is landscape (wider than tall).
  bool get isLandscape => sourceWidth >= sourceHeight;

  @override
  String toString() => 'WallpaperPost(author: $author, url: $imageUrl)';
}
