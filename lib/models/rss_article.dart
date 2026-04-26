class RssArticle {
  final String id;
  final String title;
  final String source;
  final String summary;
  final String link;
  final List<String> authors;
  final String primaryAuthor;
  final String correspondingAuthor;
  final String imageUrl;
  final String tocGraphicUrl;
  final String thumbnailUrl;
  final DateTime? publishedAt;

  const RssArticle({
    required this.id,
    required this.title,
    required this.source,
    required this.summary,
    required this.link,
    this.authors = const [],
    this.primaryAuthor = '',
    this.correspondingAuthor = '',
    this.imageUrl = '',
    this.tocGraphicUrl = '',
    this.thumbnailUrl = '',
    required this.publishedAt,
  });

  String get fullLink => link;
  String get firstAuthor {
    if (primaryAuthor.trim().isNotEmpty) {
      return primaryAuthor.trim();
    }
    if (authors.isNotEmpty) {
      return authors.first.trim();
    }
    return '';
  }

  String get displayImageUrl {
    if (tocGraphicUrl.trim().isNotEmpty) {
      return tocGraphicUrl.trim();
    }
    if (thumbnailUrl.trim().isNotEmpty) {
      return thumbnailUrl.trim();
    }
    return imageUrl.trim();
  }
}

class ArticleFeedResult {
  final List<RssArticle> articles;
  final Map<String, String> failures;

  const ArticleFeedResult({required this.articles, required this.failures});
}
