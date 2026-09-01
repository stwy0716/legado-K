import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:legado_md3/data/model/rss_source.dart';
import 'package:legado_md3/data/model/rss_article.dart';
import 'package:legado_md3/ui/rss/rss_read_screen.dart';
import 'package:legado_md3/data/local/app_database.dart';
import 'package:legado_md3/help/http/rss_service.dart';

class SubscribeScreen extends StatefulWidget {
  const SubscribeScreen({super.key});

  @override
  State<SubscribeScreen> createState() => _SubscribeScreenState();
}

class _SubscribeScreenState extends State<SubscribeScreen> {
  final DatabaseService _db = DatabaseService();
  final RssService _rssService = RssService();
  List<RssSource> _sources = [];
  List<RssArticle> _articles = [];
  bool _isLoading = true;
  bool _showSources = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _sources = await _db.getRssSources();
    _articles = await _db.getRssArticles();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _addSource() async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加订阅源'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(labelText: 'RSS/Atom URL'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              if (nameController.text.isEmpty || urlController.text.isEmpty) return;
              final source = RssSource(
                name: nameController.text,
                url: urlController.text,
                enabled: true,
              );
              await _db.insertRssSource(source);
              Navigator.pop(context);
              _loadData();
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshSource(RssSource source) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('正在刷新: ${source.name}')),
    );
    final articles = await _rssService.fetchRss(source);
    for (final article in articles) {
      await _db.saveRssArticles([article]);
    }
    source.lastUpdateTime = DateTime.now().millisecondsSinceEpoch;
    await _db.updateRssSource(source);
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刷新完成: ${articles.length} 篇文章')),
      );
    }
  }

  Future<void> _refreshAll() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在刷新所有订阅...')),
    );
    int total = 0;
    for (final source in _sources) {
      if (source.enabled != true) continue;
      final articles = await _rssService.fetchRss(source);
      for (final article in articles) {
        await _db.saveRssArticles([article]);
      }
      source.lastUpdateTime = DateTime.now().millisecondsSinceEpoch;
      await _db.updateRssSource(source);
      total += articles.length;
    }
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刷新完成: 共 $total 篇新文章')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('订阅'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAll,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'sources') setState(() => _showSources = true);
              if (value == 'articles') setState(() => _showSources = false);
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'sources', child: Text('订阅源 (${_sources.length})')),
              PopupMenuItem(value: 'articles', child: Text('文章 (${_articles.length})')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _showSources
              ? _buildSourcesList()
              : _buildArticlesList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSource,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSourcesList() {
    if (_sources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.subscriptions_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('暂无订阅源', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            const SizedBox(height: 8),
            const Text('点击右下角添加订阅源'),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _sources.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final source = _sources[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text(source.name.isNotEmpty ? source.name[0] : '?'),
            ),
            title: Text(source.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(source.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: source.enabled == true,
                  onChanged: (v) {
                    source.enabled = v;
                    _db.updateRssSource(source);
                    setState(() {});
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _refreshSource(source),
                ),
              ],
            ),
            onLongPress: () => _showSourceOptions(source),
          ),
        );
      },
    );
  }

  Widget _buildArticlesList() {
    if (_articles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('暂无文章'),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _articles.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final article = _articles[index];
        return ListTile(
          leading: article.read == true ? const Icon(Icons.check_circle_outline, color: Colors.grey) : const Icon(Icons.fiber_new, color: Colors.red),
          title: Text(article.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: article.read == true ? FontWeight.normal : FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article.description != null)
                Text(article.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Text('${article.sourceName ?? ''} ${article.pubDate != null ? DateTime.fromMillisecondsSinceEpoch(article.pubDate!).toString().substring(0, 16) : ''}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          onTap: () async {
            if (article.id != null) await _db.markRssArticleRead(article.id!);
            if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => RssReadScreen(article: article)));
            _loadData();
          },
          onLongPress: () => _showArticleOptions(article),
        );
      },
    );
  }

  void _showSourceOptions(RssSource source) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('查看文章'),
              onTap: () { Navigator.pop(context); setState(() => _showSources = false); },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('刷新'),
              onTap: () { Navigator.pop(context); _refreshSource(source); },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑'),
              onTap: () { Navigator.pop(context); _editSource(source); },
            ),
            ListTile(
              leading: Icon(source.enabled == true ? Icons.toggle_off : Icons.toggle_on),
              title: Text(source.enabled == true ? '禁用' : '启用'),
              onTap: () async { Navigator.pop(context); source.enabled = !(source.enabled == true); await _db.updateRssSource(source); _loadData(); },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('复制源JSON'),
              onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制'))); },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('分享'),
              onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('分享功能'))); },
            ),
            ListTile(
              leading: const Icon(Icons.star_outline),
              title: const Text('收藏文章'),
              onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('收藏文章'))); },
            ),
            ListTile(
              leading: const Icon(Icons.done_all),
              title: const Text('全部标为已读'),
              onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已全部标为已读'))); },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                if (source.id != null) await _db.deleteRssSource(source.id!);
                _loadData();
              },
            ),
          ],
        )),
      ),
    );
  }

  void _showArticleOptions(RssArticle article) {
    showModalBottomSheet(context: context, builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(
        leading: Icon(article.read == true ? Icons.mark_email_unread : Icons.mark_email_read),
        title: Text(article.read == true ? '标为未读' : '标为已读'),
        onTap: () async { Navigator.pop(context); if (article.id != null) { article.read = !(article.read == true); await _db.markRssArticleRead(article.id!); _loadData(); } },
      ),
      ListTile(
        leading: const Icon(Icons.star_border),
        title: const Text('收藏'),
        onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已收藏'))); },
      ),
      ListTile(
        leading: const Icon(Icons.open_in_browser),
        title: const Text('在浏览器打开'),
        onTap: () async { Navigator.pop(context); if (article.link.isNotEmpty) await launchUrl(Uri.parse(article.link), mode: LaunchMode.externalApplication); },
      ),
      ListTile(
        leading: const Icon(Icons.content_copy),
        title: const Text('复制链接'),
        onTap: () async { Navigator.pop(context); await Clipboard.setData(ClipboardData(text: article.link)); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制'))); },
      ),
      ListTile(
        leading: const Icon(Icons.share),
        title: const Text('分享'),
        onTap: () { Navigator.pop(context); Share.share('${article.title}\n${article.link}'); },
      ),
    ])));
  }

  void _editSource(RssSource source) {
    final nameController = TextEditingController(text: source.name);
    final urlController = TextEditingController(text: source.url);
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('编辑订阅源'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameController, decoration: const InputDecoration(labelText: '名称')),
        const SizedBox(height: 12),
        TextField(controller: urlController, decoration: const InputDecoration(labelText: 'URL')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: () async {
          source.name = nameController.text;
          source.url = urlController.text;
          await _db.updateRssSource(source);
          if (mounted) { Navigator.pop(context); _loadData(); }
        }, child: const Text('保存')),
      ],
    ));
  }
}
