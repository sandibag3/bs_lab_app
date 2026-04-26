import 'package:flutter/material.dart';

import '../models/article_feed.dart';
import '../models/rss_article.dart';
import '../services/article_feed_service.dart';
import 'article_detail_screen.dart';

class LatestArticlesScreen extends StatefulWidget {
  const LatestArticlesScreen({super.key});

  @override
  State<LatestArticlesScreen> createState() => _LatestArticlesScreenState();
}

class _LatestArticlesScreenState extends State<LatestArticlesScreen> {
  final ArticleFeedService _feedService = ArticleFeedService();
  final TextEditingController _searchController = TextEditingController();

  Set<String> _enabledFeedIds = {};
  List<ArticleFeed> _customFeeds = [];
  List<RssArticle> _articles = [];
  Map<String, String> _failures = {};
  bool _isLoading = true;

  List<ArticleFeed> get _allFeeds {
    return [...curatedArticleFeeds, ..._customFeeds];
  }

  List<ArticleFeed> get _enabledFeeds {
    return _allFeeds
        .where((feed) => _enabledFeedIds.contains(feed.id))
        .toList();
  }

  List<RssArticle> get _filteredArticles {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _articles;

    return _articles.where((article) {
      return article.title.toLowerCase().contains(query) ||
          article.summary.toLowerCase().contains(query) ||
          article.source.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadFeedsAndArticles();
  }

  Future<void> _loadFeedsAndArticles() async {
    final customFeeds = await _feedService.loadCustomFeeds();
    final enabledIds = await _feedService.loadEnabledFeedIds();

    if (!mounted) return;

    setState(() {
      _customFeeds = customFeeds;
      _enabledFeedIds = enabledIds;
    });

    await _refreshArticles();
  }

  Future<void> _refreshArticles() async {
    if (_enabledFeeds.isEmpty) {
      setState(() {
        _articles = [];
        _failures = {};
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await _feedService.fetchLatestArticles(_enabledFeeds);

    if (!mounted) return;

    setState(() {
      _articles = result.articles;
      _failures = result.failures;
      _isLoading = false;
    });
  }

  Future<void> _toggleFeed(ArticleFeed feed, bool isEnabled) async {
    setState(() {
      if (isEnabled) {
        _enabledFeedIds.add(feed.id);
      } else {
        _enabledFeedIds.remove(feed.id);
      }
    });

    await _feedService.saveEnabledFeedIds(_enabledFeedIds);
    await _refreshArticles();
  }

  Future<void> _deleteCustomFeed(ArticleFeed feed) async {
    await _feedService.deleteCustomFeed(feed);
    final customFeeds = await _feedService.loadCustomFeeds();
    final enabledIds = await _feedService.loadEnabledFeedIds();

    if (!mounted) return;

    setState(() {
      _customFeeds = customFeeds;
      _enabledFeedIds = enabledIds;
    });

    await _refreshArticles();
  }

  Future<void> _addCustomFeed(ArticleFeed feed) async {
    await _feedService.saveCustomFeed(feed);
    final customFeeds = await _feedService.loadCustomFeeds();
    final enabledIds = await _feedService.loadEnabledFeedIds();

    if (!mounted) return;

    setState(() {
      _customFeeds = customFeeds;
      _enabledFeedIds = enabledIds;
    });

    await _refreshArticles();
  }

  void _openArticle(RssArticle article) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article)),
    );
  }

  void _openFeedSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final groupedFeeds = <String, List<ArticleFeed>>{};
            for (final feed in _allFeeds) {
              groupedFeeds.putIfAbsent(feed.area, () => []).add(feed);
            }

            return SafeArea(
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.82,
                maxChildSize: 0.95,
                minChildSize: 0.45,
                builder: (context, scrollController) {
                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Article Feeds',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  _openAddFeedSheet();
                                }
                              });
                            },
                            icon: const Icon(
                              Icons.add_rounded,
                              color: Color(0xFF14B8A6),
                            ),
                            label: const Text(
                              'Add Feed',
                              style: TextStyle(color: Color(0xFF14B8A6)),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final entry in groupedFeeds.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 8),
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              color: Color(0xFF14B8A6),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        for (final feed in entry.value)
                          Row(
                            children: [
                              Expanded(
                                child: SwitchListTile(
                                  value: _enabledFeedIds.contains(feed.id),
                                  activeThumbColor: const Color(0xFF14B8A6),
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    feed.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    feed.isCustom ? feed.feedUrl : feed.source,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                    ),
                                  ),
                                  onChanged: (value) async {
                                    setSheetState(() {
                                      if (value) {
                                        _enabledFeedIds.add(feed.id);
                                      } else {
                                        _enabledFeedIds.remove(feed.id);
                                      }
                                    });
                                    await _toggleFeed(feed, value);
                                  },
                                ),
                              ),
                              if (feed.isCustom)
                                IconButton(
                                  tooltip: 'Delete feed',
                                  onPressed: () async {
                                    await _deleteCustomFeed(feed);
                                    if (context.mounted) {
                                      setSheetState(() {});
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Color(0xFFFCA5A5),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  void _openAddFeedSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      builder: (context) {
        return _AddFeedSheet(
          feedService: _feedService,
          onFeedAdded: _addCustomFeed,
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredArticles = _filteredArticles;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refreshArticles,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _buildToolbar(),
            const SizedBox(height: 12),
            _buildSearchField(),
            const SizedBox(height: 12),
            if (_failures.isNotEmpty) _buildFailureNotice(),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_enabledFeeds.isEmpty)
              _buildEmptyState(
                icon: Icons.rss_feed_rounded,
                title: 'No feeds enabled',
                message: 'Enable at least one chemistry feed to load articles.',
              )
            else if (filteredArticles.isEmpty)
              _buildEmptyState(
                icon: Icons.search_off_rounded,
                title: 'No articles found',
                message: 'Try another keyword or refresh the enabled feeds.',
              )
            else
              for (final article in filteredArticles)
                _buildArticleCard(article),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${_enabledFeeds.length} feeds enabled',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Add feed',
          onPressed: _openAddFeedSheet,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
        ),
        IconButton(
          tooltip: 'Manage feeds',
          onPressed: _openFeedSettings,
          icon: const Icon(Icons.tune_rounded, color: Colors.white),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _isLoading ? null : _refreshArticles,
          icon: Icon(
            Icons.refresh_rounded,
            color: _isLoading ? Colors.white30 : Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search titles and summaries',
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
        suffixIcon: _searchController.text.trim().isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: _searchController.clear,
                icon: const Icon(Icons.close_rounded, color: Colors.white54),
              ),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildFailureNotice() {
    final failedNames = _failures.keys.join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF3B1D1D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFCA5A5)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Some feeds could not be loaded: $failedNames',
              style: const TextStyle(color: Colors.white70, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleCard(RssArticle article) {
    return InkWell(
      onTap: () => _openArticle(article),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ArticleThumbnail(article: article),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                      if (article.firstAuthor.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          article.firstAuthor,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF14B8A6),
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetaPill(article.source),
                if (article.publishedAt != null)
                  _buildMetaPill(_formatDate(article.publishedAt!)),
              ],
            ),
            if (article.summary.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                article.summary,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white60,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetaPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(icon, color: Colors.white30, size: 44),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _ArticleThumbnail extends StatelessWidget {
  final RssArticle article;

  const _ArticleThumbnail({required this.article});

  @override
  Widget build(BuildContext context) {
    final imageUrl = article.displayImageUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 76,
        height: 76,
        color: const Color(0xFF0F172A),
        child: imageUrl.isEmpty
            ? const _ThumbnailPlaceholder()
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const _ThumbnailPlaceholder();
                },
              ),
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.article_rounded, color: Colors.white30, size: 30),
    );
  }
}

class _AddFeedSheet extends StatefulWidget {
  final ArticleFeedService feedService;
  final Future<void> Function(ArticleFeed feed) onFeedAdded;

  const _AddFeedSheet({required this.feedService, required this.onFeedAdded});

  @override
  State<_AddFeedSheet> createState() => _AddFeedSheetState();
}

class _AddFeedSheetState extends State<_AddFeedSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  String _error = '';
  bool _isSaving = false;

  Future<void> _submit() async {
    final feedUrl = _urlController.text.trim();

    if (feedUrl.isEmpty) {
      setState(() {
        _error = 'Enter a feed URL.';
      });
      return;
    }

    if (!feedUrl.startsWith('http://') && !feedUrl.startsWith('https://')) {
      setState(() {
        _error = 'Feed URL must start with http:// or https://.';
      });
      return;
    }

    setState(() {
      _error = '';
      _isSaving = true;
    });

    try {
      final feed = await widget.feedService.validateAndBuildCustomFeed(
        name: _nameController.text,
        feedUrl: feedUrl,
      );
      await widget.onFeedAdded(feed);

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Feed added')));
    } on ArticleFeedValidationException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not add this feed. Check the URL and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Add Feed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _nameController,
              label: 'Feed Name optional',
              icon: Icons.rss_feed_rounded,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _urlController,
              label: 'Feed URL required',
              icon: Icons.link_rounded,
              keyboardType: TextInputType.url,
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(_error, style: const TextStyle(color: Color(0xFFFCA5A5))),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded, color: Colors.white),
                label: Text(
                  _isSaving ? 'Checking Feed' : 'Add Feed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: !_isSaving,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
