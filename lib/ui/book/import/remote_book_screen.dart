import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:legado_md3/help/storage/webdav_service.dart';

/// 远程书籍导入（WebDAV），对齐原版 import/remote/RemoteBookScreen
class RemoteBookScreen extends StatefulWidget {
  const RemoteBookScreen({super.key});

  @override
  State<RemoteBookScreen> createState() => _RemoteBookScreenState();
}

class _RemoteBookScreenState extends State<RemoteBookScreen> {
  final WebDavService _webDav = WebDavService();
  List<String> _files = [];
  bool _loading = false;
  String? _error;
  int _sortKey = 0; // 0 默认 1 名称
  String? _baseUrl, _user, _pass, _dir;

  static const _bookExt = ['txt', 'epub', 'zip', 'mobi', 'umd'];

  @override
  void initState() { super.initState(); _initAndLoad(); }

  Future<void> _initAndLoad() async {
    final p = await SharedPreferences.getInstance();
    _baseUrl = p.getString('webdav_url');
    _user = p.getString('webdav_user');
    _pass = p.getString('webdav_pass');
    _dir = p.getString('webdav_dir') ?? 'Legado/backup';
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    if (_baseUrl == null || _baseUrl!.isEmpty) {
      setState(() => _error = '尚未配置 WebDAV，请先在 备份与恢复 中填写');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      _webDav.configure(baseUrl: _baseUrl!, username: _user, password: _pass);
      final all = await _webDav.listBackups();
      final books = all.where((f) {
        final ext = f.contains('.') ? f.split('.').last.toLowerCase() : '';
        return _bookExt.contains(ext);
      }).toList();
      if (_sortKey == 1) books.sort();
      if (mounted) setState(() { _files = books; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '连接失败: $e'; _loading = false; });
    }
  }

  Future<void> _downloadAndImport(String file) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('下载 $file ...')));
    try {
      final data = await _webDav.downloadBackup(file);
      if (data == null) throw Exception('下载为空');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('《$file》已下载，可在本地导入中打开')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('下载失败: $e')));
    }
  }

  void _configServer() {
    final urlCtl = TextEditingController(text: _baseUrl);
    final userCtl = TextEditingController(text: _user);
    final passCtl = TextEditingController(text: _pass);
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text('服务器配置'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: urlCtl, decoration: const InputDecoration(labelText: 'WebDAV 地址', isDense: true)),
        const SizedBox(height: 8),
        TextField(controller: userCtl, decoration: const InputDecoration(labelText: '账号', isDense: true)),
        const SizedBox(height: 8),
        TextField(controller: passCtl, obscureText: true, decoration: const InputDecoration(labelText: '密码', isDense: true)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
        FilledButton(onPressed: () async {
          final p = await SharedPreferences.getInstance();
          await p.setString('webdav_url', urlCtl.text);
          await p.setString('webdav_user', userCtl.text);
          await p.setString('webdav_pass', passCtl.text);
          _baseUrl = urlCtl.text; _user = userCtl.text; _pass = passCtl.text;
          if (mounted) { Navigator.pop(c); _loadFiles(); }
        }, child: const Text('保存')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('远程书籍'),
        actions: [
          IconButton(icon: const Icon(Icons.dns_outlined), tooltip: '服务器配置', onPressed: _configServer),
          PopupMenuButton<int>(
            initialValue: _sortKey,
            onSelected: (v) { setState(() => _sortKey = v); _loadFiles(); },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 0, child: Text('默认排序')),
              PopupMenuItem(value: 1, child: Text('按名称排序')),
            ],
            child: const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.sort)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(onPressed: _configServer, icon: const Icon(Icons.settings), label: const Text('配置服务器')),
                ])))
              : _files.isEmpty
                  ? const Center(child: Text('远程没有可导入的书籍文件'))
                  : RefreshIndicator(onRefresh: _loadFiles, child: ListView.separated(
                      itemCount: _files.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (c, i) {
                        final f = _files[i];
                        final ext = f.contains('.') ? f.split('.').last.toLowerCase() : '';
                        return ListTile(
                          leading: Icon(ext == 'epub' ? Icons.menu_book : Icons.description_outlined),
                          title: Text(f),
                          subtitle: Text('目录: $_dir', style: const TextStyle(fontSize: 11)),
                          trailing: const Icon(Icons.download),
                          onTap: () => _downloadAndImport(f),
                        );
                      },
                    )),
    );
  }
}
