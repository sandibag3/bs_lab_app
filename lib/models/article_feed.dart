import 'dart:convert';

class ArticleFeed {
  final String id;
  final String title;
  final String source;
  final String area;
  final String feedUrl;
  final bool isCustom;

  const ArticleFeed({
    required this.id,
    required this.title,
    required this.source,
    required this.area,
    required this.feedUrl,
    this.isCustom = false,
  });

  factory ArticleFeed.custom({
    required String id,
    required String title,
    required String feedUrl,
  }) {
    return ArticleFeed(
      id: id,
      title: title,
      source: 'Custom Feed',
      area: 'Custom Feeds',
      feedUrl: feedUrl,
      isCustom: true,
    );
  }

  factory ArticleFeed.fromJson(Map<String, dynamic> json) {
    return ArticleFeed(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      source: (json['source'] ?? 'Custom Feed').toString(),
      area: (json['area'] ?? 'Custom Feeds').toString(),
      feedUrl: (json['feedUrl'] ?? '').toString(),
      isCustom: json['isCustom'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'source': source,
      'area': area,
      'feedUrl': feedUrl,
      'isCustom': isCustom,
    };
  }

  String encode() => jsonEncode(toJson());

  static ArticleFeed? decode(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final feed = ArticleFeed.fromJson(decoded);
      if (feed.id.trim().isEmpty ||
          feed.title.trim().isEmpty ||
          feed.feedUrl.trim().isEmpty) {
        return null;
      }

      return feed;
    } catch (_) {
      return null;
    }
  }
}

const List<ArticleFeed> curatedArticleFeeds = [
  ArticleFeed(
    id: 'acs-editors-choice',
    title: 'ACS Editors Choice',
    source: 'ACS Publications',
    area: 'General Chemistry',
    feedUrl: 'https://pubs.acs.org/editorschoice/feed/rss',
  ),
  ArticleFeed(
    id: 'acs-jacs',
    title: 'Journal of the American Chemical Society',
    source: 'ACS Publications',
    area: 'General Chemistry',
    feedUrl:
        'https://pubs.acs.org/action/showFeed?type=axatoc&feed=rss&jc=jacsat',
  ),
  ArticleFeed(
    id: 'acs-organic-letters',
    title: 'Organic Letters',
    source: 'ACS Publications',
    area: 'Organic Chemistry',
    feedUrl:
        'https://pubs.acs.org/action/showFeed?type=axatoc&feed=rss&jc=orlef7',
  ),
  ArticleFeed(
    id: 'acs-joc',
    title: 'The Journal of Organic Chemistry',
    source: 'ACS Publications',
    area: 'Organic Chemistry',
    feedUrl:
        'https://pubs.acs.org/action/showFeed?type=axatoc&feed=rss&jc=joceah',
  ),
  ArticleFeed(
    id: 'rsc-chemical-science',
    title: 'Chemical Science',
    source: 'Royal Society of Chemistry',
    area: 'General Chemistry',
    feedUrl: 'https://feeds.rsc.org/rss/sc',
  ),
  ArticleFeed(
    id: 'rsc-obc',
    title: 'Organic and Biomolecular Chemistry',
    source: 'Royal Society of Chemistry',
    area: 'Organic Chemistry',
    feedUrl: 'https://feeds.rsc.org/rss/ob',
  ),
  ArticleFeed(
    id: 'rsc-green-chemistry',
    title: 'Green Chemistry',
    source: 'Royal Society of Chemistry',
    area: 'Sustainable Chemistry',
    feedUrl: 'https://feeds.rsc.org/rss/gc',
  ),
  ArticleFeed(
    id: 'nature-chemistry-aop',
    title: 'Nature Chemistry AOP',
    source: 'Nature Portfolio',
    area: 'General Chemistry',
    feedUrl: 'https://www.nature.com/nchem/journal/vaop/ncurrent/rss.rdf',
  ),
  ArticleFeed(
    id: 'nature-chemical-biology-aop',
    title: 'Nature Chemical Biology AOP',
    source: 'Nature Portfolio',
    area: 'Chemical Biology',
    feedUrl: 'https://www.nature.com/nchembio/journal/vaop/ncurrent/rss.rdf',
  ),
  ArticleFeed(
    id: 'wiley-chem-eur-j',
    title: 'Chemistry - A European Journal',
    source: 'Chemistry Europe / Wiley',
    area: 'General Chemistry',
    feedUrl:
        'https://chemistry-europe.onlinelibrary.wiley.com/feed/15213765/most-recent',
  ),
  ArticleFeed(
    id: 'wiley-ejoc',
    title: 'European Journal of Organic Chemistry',
    source: 'Chemistry Europe / Wiley',
    area: 'Organic Chemistry',
    feedUrl:
        'https://chemistry-europe.onlinelibrary.wiley.com/feed/10990690/most-recent',
  ),
  // TODO: Add ChemRxiv when a stable public RSS feed endpoint is available.
];
