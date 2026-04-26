import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import '../models/article_feed.dart';
import '../models/rss_article.dart';

class ArticleFeedService {
  static const String _enabledFeedIdsKey = 'enabled_article_feed_ids';
  static const String _customFeedsKey = 'custom_article_feeds';

  Future<List<ArticleFeed>> loadCustomFeeds() async {
    final prefs = await SharedPreferences.getInstance();
    final savedFeeds = prefs.getStringList(_customFeedsKey) ?? const [];

    final feeds = savedFeeds
        .map(ArticleFeed.decode)
        .whereType<ArticleFeed>()
        .where((feed) => feed.isCustom)
        .toList();

    feeds.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return feeds;
  }

  Future<Set<String>> loadEnabledFeedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIds = prefs.getStringList(_enabledFeedIdsKey);

    if (savedIds == null) {
      final customFeeds = await loadCustomFeeds();
      return {
        ...curatedArticleFeeds.map((feed) => feed.id),
        ...customFeeds.map((feed) => feed.id),
      };
    }

    return savedIds.toSet();
  }

  Future<void> saveEnabledFeedIds(Set<String> enabledFeedIds) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = enabledFeedIds.toList()..sort();
    await prefs.setStringList(_enabledFeedIdsKey, ids);
  }

  Future<ArticleFeed> validateAndBuildCustomFeed({
    required String name,
    required String feedUrl,
  }) async {
    final cleanUrl = feedUrl.trim();
    if (cleanUrl.isEmpty) {
      throw const ArticleFeedValidationException('Enter a feed URL.');
    }

    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      throw const ArticleFeedValidationException(
        'Feed URL must start with http:// or https://.',
      );
    }

    final uri = Uri.tryParse(cleanUrl);
    if (uri == null || uri.host.trim().isEmpty) {
      throw const ArticleFeedValidationException('Enter a valid feed URL.');
    }

    final probeFeed = ArticleFeed.custom(
      id: _customFeedId(cleanUrl),
      title: name.trim().isEmpty ? uri.host : name.trim(),
      feedUrl: cleanUrl,
    );

    List<RssArticle> articles;
    try {
      articles = await _fetchFeed(probeFeed);
    } on XmlParserException {
      throw const ArticleFeedValidationException(
        'This URL did not return a supported RSS or Atom feed.',
      );
    } catch (_) {
      throw const ArticleFeedValidationException(
        'Could not fetch this feed. Check the URL and try again.',
      );
    }

    if (articles.isEmpty) {
      throw const ArticleFeedValidationException(
        'This feed was parsed, but no articles were found.',
      );
    }

    return probeFeed;
  }

  Future<void> saveCustomFeed(ArticleFeed feed) async {
    if (!feed.isCustom) return;

    final prefs = await SharedPreferences.getInstance();
    final customFeeds = await loadCustomFeeds();
    final withoutDuplicate = customFeeds
        .where((savedFeed) => savedFeed.id != feed.id)
        .toList();

    withoutDuplicate.add(feed);
    withoutDuplicate.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );

    await prefs.setStringList(
      _customFeedsKey,
      withoutDuplicate.map((savedFeed) => savedFeed.encode()).toList(),
    );

    final enabledIds = await loadEnabledFeedIds();
    enabledIds.add(feed.id);
    await saveEnabledFeedIds(enabledIds);
  }

  Future<void> deleteCustomFeed(ArticleFeed feed) async {
    if (!feed.isCustom) return;

    final prefs = await SharedPreferences.getInstance();
    final customFeeds = await loadCustomFeeds();
    final remainingFeeds = customFeeds
        .where((savedFeed) => savedFeed.id != feed.id)
        .toList();

    await prefs.setStringList(
      _customFeedsKey,
      remainingFeeds.map((savedFeed) => savedFeed.encode()).toList(),
    );

    final enabledIds = await loadEnabledFeedIds();
    enabledIds.remove(feed.id);
    await saveEnabledFeedIds(enabledIds);
  }

  Future<ArticleFeedResult> fetchLatestArticles(
    Iterable<ArticleFeed> feeds,
  ) async {
    final articles = <RssArticle>[];
    final failures = <String, String>{};

    await Future.wait(
      feeds.map((feed) async {
        try {
          final fetched = await _fetchFeed(feed);
          articles.addAll(fetched);
        } catch (error) {
          failures[feed.title] = error.toString();
        }
      }),
    );

    articles.sort((a, b) {
      final aDate = a.publishedAt;
      final bDate = b.publishedAt;

      if (aDate == null && bDate == null) {
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    });

    return ArticleFeedResult(
      articles: _dedupeArticles(articles),
      failures: failures,
    );
  }

  Future<List<RssArticle>> _fetchFeed(ArticleFeed feed) async {
    final uri = Uri.parse(feed.feedUrl);
    final response = await http.get(uri).timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Feed returned HTTP ${response.statusCode}');
    }

    final document = XmlDocument.parse(response.body);
    final rssItems = document.findAllElements('item').toList();

    if (rssItems.isNotEmpty) {
      return rssItems
          .map((item) => _safeParseItem(() => _parseRssItem(item, feed)))
          .whereType<RssArticle>()
          .toList();
    }

    return document
        .findAllElements('entry')
        .map((entry) => _safeParseItem(() => _parseAtomEntry(entry, feed)))
        .whereType<RssArticle>()
        .toList();
  }

  RssArticle? _safeParseItem(RssArticle? Function() parser) {
    try {
      return parser();
    } catch (_) {
      return null;
    }
  }

  RssArticle? _parseRssItem(XmlElement item, ArticleFeed feed) {
    final title = _cleanText(_childText(item, 'title'));
    final link = _cleanText(_childText(item, 'link'));

    if (title.isEmpty || link.isEmpty) {
      return null;
    }

    final rawDescription = _childText(item, 'description');
    final rawContent = _childText(item, 'encoded');
    final summary = _cleanText(
      rawDescription.isNotEmpty ? rawDescription : _childText(item, 'summary'),
    );
    final publishedText = _cleanText(
      _childText(item, 'pubDate').isNotEmpty
          ? _childText(item, 'pubDate')
          : _childText(item, 'date'),
    );
    final authors = _rssAuthors(item);
    final imageUrl = _imageUrlFromElement(item, rawDescription, rawContent);

    return RssArticle(
      id: link,
      title: title,
      source: feed.title,
      summary: summary,
      link: link,
      authors: authors,
      primaryAuthor: authors.isNotEmpty ? authors.first : '',
      correspondingAuthor: _correspondingAuthor(item),
      imageUrl: imageUrl,
      tocGraphicUrl: imageUrl,
      thumbnailUrl: imageUrl,
      publishedAt: _parseDate(publishedText),
    );
  }

  RssArticle? _parseAtomEntry(XmlElement entry, ArticleFeed feed) {
    final title = _cleanText(_childText(entry, 'title'));
    final link = _atomLink(entry);

    if (title.isEmpty || link.isEmpty) {
      return null;
    }

    final rawSummary = _childText(entry, 'summary');
    final rawContent = _childText(entry, 'content');
    final summary = _cleanText(rawSummary.isNotEmpty ? rawSummary : rawContent);
    final publishedText = _cleanText(
      _childText(entry, 'published').isNotEmpty
          ? _childText(entry, 'published')
          : _childText(entry, 'updated'),
    );
    final authors = _atomAuthors(entry);
    final imageUrl = _imageUrlFromElement(entry, rawSummary, rawContent);

    return RssArticle(
      id: link,
      title: title,
      source: feed.title,
      summary: summary,
      link: link,
      authors: authors,
      primaryAuthor: authors.isNotEmpty ? authors.first : '',
      correspondingAuthor: _correspondingAuthor(entry),
      imageUrl: imageUrl,
      tocGraphicUrl: imageUrl,
      thumbnailUrl: imageUrl,
      publishedAt: _parseDate(publishedText),
    );
  }

  List<String> _rssAuthors(XmlElement item) {
    final authors = <String>[];
    for (final child in item.childElements) {
      final local = child.name.local.toLowerCase();
      if (local == 'creator' ||
          local == 'author' ||
          local == 'contributor' ||
          local == 'name') {
        final author = _cleanAuthor(child.innerText);
        if (author.isNotEmpty) {
          authors.add(author);
        }
      }
    }

    return _dedupeStrings(authors);
  }

  List<String> _atomAuthors(XmlElement entry) {
    final authors = <String>[];
    for (final authorElement in entry.findElements('author')) {
      final name = _cleanAuthor(_childText(authorElement, 'name'));
      if (name.isNotEmpty) {
        authors.add(name);
        continue;
      }

      final textAuthor = _cleanAuthor(authorElement.innerText);
      if (textAuthor.isNotEmpty) {
        authors.add(textAuthor);
      }
    }

    for (final contributorElement in entry.findElements('contributor')) {
      final name = _cleanAuthor(_childText(contributorElement, 'name'));
      if (name.isNotEmpty) {
        authors.add(name);
      }
    }

    return _dedupeStrings(authors);
  }

  String _correspondingAuthor(XmlElement element) {
    for (final child in element.descendants.whereType<XmlElement>()) {
      final local = child.name.local.toLowerCase();
      final text = _cleanText(child.innerText).toLowerCase();
      if ((local.contains('correspond') || text.contains('corresponding')) &&
          child.innerText.trim().isNotEmpty) {
        return _cleanAuthor(child.innerText);
      }
    }
    return '';
  }

  String _imageUrlFromElement(
    XmlElement element,
    String rawDescription,
    String rawContent,
  ) {
    final mediaUrl = _mediaImageUrl(element);
    if (mediaUrl.isNotEmpty) {
      return mediaUrl;
    }

    final enclosureUrl = _enclosureImageUrl(element);
    if (enclosureUrl.isNotEmpty) {
      return enclosureUrl;
    }

    final htmlImage = _firstImageFromHtml(rawDescription);
    if (htmlImage.isNotEmpty) {
      return htmlImage;
    }

    return _firstImageFromHtml(rawContent);
  }

  String _mediaImageUrl(XmlElement element) {
    for (final child in element.descendants.whereType<XmlElement>()) {
      final local = child.name.local.toLowerCase();
      if (local != 'thumbnail' && local != 'content') {
        continue;
      }

      final url = (child.getAttribute('url') ?? '').trim();
      final medium = (child.getAttribute('medium') ?? '').toLowerCase();
      final type = (child.getAttribute('type') ?? '').toLowerCase();
      final looksLikeImage =
          local == 'thumbnail' ||
          medium == 'image' ||
          type.startsWith('image/');

      if (url.isNotEmpty && looksLikeImage) {
        return url;
      }
    }
    return '';
  }

  String _enclosureImageUrl(XmlElement element) {
    for (final enclosure in element.findAllElements('enclosure')) {
      final url = (enclosure.getAttribute('url') ?? '').trim();
      final type = (enclosure.getAttribute('type') ?? '').toLowerCase();
      if (url.isNotEmpty && type.startsWith('image/')) {
        return url;
      }
    }
    return '';
  }

  String _firstImageFromHtml(String value) {
    final match = RegExp(
      r'''<img[^>]+src=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(value);
    return match?.group(1)?.trim() ?? '';
  }

  List<RssArticle> _dedupeArticles(List<RssArticle> articles) {
    final seen = <String>{};
    final deduped = <RssArticle>[];

    for (final article in articles) {
      final key = article.link.trim().isNotEmpty
          ? article.link.trim()
          : '${article.source}:${article.title}'.toLowerCase();

      if (seen.add(key)) {
        deduped.add(article);
      }
    }

    return deduped;
  }

  String _childText(XmlElement element, String localName) {
    for (final child in element.childElements) {
      if (child.name.local.toLowerCase() == localName.toLowerCase()) {
        return child.innerText;
      }
    }
    return '';
  }

  String _atomLink(XmlElement entry) {
    for (final linkElement in entry.findElements('link')) {
      final rel = linkElement.getAttribute('rel') ?? 'alternate';
      final href = linkElement.getAttribute('href') ?? '';

      if (href.isNotEmpty && rel == 'alternate') {
        return href;
      }
    }

    final firstHref = entry
        .findElements('link')
        .firstOrNull
        ?.getAttribute('href');
    return firstHref ?? '';
  }

  DateTime? _parseDate(String value) {
    if (value.trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value) ?? _parseRfc822Date(value);
  }

  DateTime? _parseRfc822Date(String value) {
    final match = RegExp(
      r'^(?:[A-Za-z]{3},\s*)?(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+'
      r'(\d{1,2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(value.trim());

    if (match == null) {
      return null;
    }

    const months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };

    final day = int.tryParse(match.group(1) ?? '');
    final month = months[(match.group(2) ?? '').toLowerCase()];
    final year = int.tryParse(match.group(3) ?? '');
    final hour = int.tryParse(match.group(4) ?? '');
    final minute = int.tryParse(match.group(5) ?? '');
    final second = int.tryParse(match.group(6) ?? '0') ?? 0;

    if (day == null ||
        month == null ||
        year == null ||
        hour == null ||
        minute == null) {
      return null;
    }

    return DateTime.utc(year, month, day, hour, minute, second);
  }

  String _cleanText(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _cleanAuthor(String value) {
    final clean = _cleanText(value)
        .replaceAll(
          RegExp(r'\s*\([^)]*corresponding[^)]*\)', caseSensitive: false),
          '',
        )
        .trim();

    if (clean.contains('@')) {
      return clean
          .split(RegExp(r'\s+'))
          .firstWhere((part) => !part.contains('@'), orElse: () => '');
    }

    return clean;
  }

  List<String> _dedupeStrings(List<String> values) {
    final seen = <String>{};
    final deduped = <String>[];

    for (final value in values) {
      final clean = value.trim();
      if (clean.isEmpty) continue;

      if (seen.add(clean.toLowerCase())) {
        deduped.add(clean);
      }
    }

    return deduped;
  }

  String _customFeedId(String feedUrl) {
    final encoded = feedUrl.codeUnits
        .map((codeUnit) => codeUnit.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'custom-$encoded';
  }
}

class ArticleFeedValidationException implements Exception {
  final String message;

  const ArticleFeedValidationException(this.message);

  @override
  String toString() => message;
}
