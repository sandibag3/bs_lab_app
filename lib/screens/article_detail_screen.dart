import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/rss_article.dart';

class ArticleDetailScreen extends StatefulWidget {
  final RssArticle article;
  final List<RssArticle> articles;
  final int initialIndex;

  const ArticleDetailScreen({
    super.key,
    required this.article,
    this.articles = const [],
    this.initialIndex = 0,
  });

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  late final List<RssArticle> _articles;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _articles = widget.articles.isEmpty ? [widget.article] : widget.articles;
    final boundedIndex =
        widget.initialIndex.clamp(0, _articles.length - 1) as int;
    _currentIndex = boundedIndex;
  }

  RssArticle get _article {
    final resolvedIndex = _currentIndex;
    return _articles[resolvedIndex];
  }

  bool get _hasPrevious => _currentIndex > 0;
  bool get _hasNext => _currentIndex < _articles.length - 1;

  Future<void> _openFullArticle(BuildContext context) async {
    final uri = Uri.tryParse(_article.fullLink);
    if (uri == null) return;

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open article link')),
      );
    }
  }

  Future<void> _shareArticle(BuildContext context) async {
    final article = _article;
    final buffer = StringBuffer()..writeln(article.title.trim());

    if (article.source.trim().isNotEmpty) {
      buffer.writeln(article.source.trim());
    }

    if (article.fullLink.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..write(article.fullLink.trim());
    }

    try {
      await Share.share(buffer.toString().trim(), subject: article.title.trim());
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not share article')),
      );
    }
  }

  void _goPrevious() {
    if (!_hasPrevious) return;
    setState(() {
      _currentIndex -= 1;
    });
  }

  void _goNext() {
    if (!_hasNext) return;
    setState(() {
      _currentIndex += 1;
    });
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    final article = _article;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Article Details',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: 'Share article',
            onPressed: () => _shareArticle(context),
            icon: const Icon(Icons.share_rounded, color: Colors.white),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ArticleImage(article: article, height: 270),
            const SizedBox(height: 18),
            Text(
              article.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaPill(text: article.source),
                if (article.publishedAt != null)
                  _MetaPill(text: _formatDate(article.publishedAt!)),
              ],
            ),
            if (article.authors.isNotEmpty) ...[
              const SizedBox(height: 20),
              const _SectionTitle('Authors'),
              Text(
                article.authors.join(', '),
                style: const TextStyle(color: Colors.white70, height: 1.45),
              ),
            ],
            if (article.correspondingAuthor.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              const _SectionTitle('Corresponding Author'),
              Text(
                article.correspondingAuthor,
                style: const TextStyle(color: Colors.white70, height: 1.45),
              ),
            ],
            if (article.summary.trim().isNotEmpty) ...[
              const SizedBox(height: 20),
              const _SectionTitle('Summary'),
              Text(
                article.summary,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openFullArticle(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                icon: const Icon(
                  Icons.open_in_new_rounded,
                  color: Colors.white,
                ),
                label: const Text(
                  'Open Full Article',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _hasPrevious ? _goPrevious : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white38,
                      side: BorderSide(
                        color: _hasPrevious ? Colors.white24 : Colors.white12,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _hasNext ? _goNext : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white38,
                      side: BorderSide(
                        color: _hasNext ? Colors.white24 : Colors.white12,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Next'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleImage extends StatelessWidget {
  final RssArticle article;
  final double height;

  const _ArticleImage({required this.article, required this.height});

  @override
  Widget build(BuildContext context) {
    final imageUrl = article.displayImageUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: height,
        width: double.infinity,
        color: const Color(0xFF1E293B),
        child: imageUrl.isEmpty
            ? const _ImagePlaceholder()
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const _ImagePlaceholder();
                },
              ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.article_rounded, color: Colors.white30, size: 54),
          SizedBox(height: 10),
          Text(
            'No article graphic available',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String text;

  const _MetaPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF14B8A6),
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
