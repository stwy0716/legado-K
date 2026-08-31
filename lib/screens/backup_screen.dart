import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final BackupService _backupService = BackupService();
  bool _includeBooks = true;
  bool _includeSources = true;
  bool _includeRules = true;
  bool _includeRecords = true;
  bool _isWorking = false;
  List<File> _backupFiles = [];

  @override
  void initState() {
    super.initState();
    _loadBackupFiles();
  }

  Future<void> _loadBackupFiles() async {
    final files = await _backupService.getBackupFiles();
    if (mounted) setState(() => _backupFiles = files);
  }

  Future<void> _createBackup() async {
    setState(() => _isWorking = true);
    try {
      final path = await _backupService.exportBackupToFile(
        includeBooks: _includeBooks,
        includeSources: _includeSources,
        includeReplaceRules: _includeRules,
        includeReadRecords: _includeRecords,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份已保存: $path')),
        );
        await _loadBackupFiles();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份失败: $e')),
        );
      }
    }
    if (mounted) setState(() => _isWorking = false);
  }

  Future<void> _restoreBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return;

      setState(() => _isWorking = true);
      final backupResult = await _backupService.restoreFromFile(result.files.first.path!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(backupResult.summary)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('恢复失败: $e')),
        );
      }
    }
    if (mounted) setState(() => _isWorking = false);
  }

  Future<void> _importSources() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
      );
      if (result == null || result.files.isEmpty) return;

      final content = await File(result.files.first.path!).readAsString();
      final count = await _backupService.importSources(content);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功导入 $count 个书源')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }

  Future<void> _exportSources() async {
    try {
      final content = await _backupService.exportSources();
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/book_sources.json');
      await file.writeAsString(content);
      await Share.shareXFiles([XFile(file.path)], text: '书源导出');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteBackup(File file) async {
    await _backupService.deleteBackup(file.path);
    await _loadBackupFiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('备份与恢复')),
      body: _isWorking
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 备份选项
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('备份内容', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SwitchListTile(title: const Text('书籍'), value: _includeBooks, onChanged: (v) => setState(() => _includeBooks = v)),
                        SwitchListTile(title: const Text('书源'), value: _includeSources, onChanged: (v) => setState(() => _includeSources = v)),
                        SwitchListTile(title: const Text('替换规则'), value: _includeRules, onChanged: (v) => setState(() => _includeRules = v)),
                        SwitchListTile(title: const Text('阅读记录'), value: _includeRecords, onChanged: (v) => setState(() => _includeRecords = v)),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _createBackup,
                            icon: const Icon(Icons.backup),
                            label: const Text('创建备份'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 恢复
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.restore),
                        title: const Text('从文件恢复'),
                        subtitle: const Text('选择备份文件恢复数据'),
                        onTap: _restoreBackup,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.file_download),
                        title: const Text('导入书源'),
                        subtitle: const Text('从JSON/TXT文件导入书源'),
                        onTap: _importSources,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.file_upload),
                        title: const Text('导出书源'),
                        subtitle: const Text('导出所有书源为JSON文件'),
                        onTap: _exportSources,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 备份文件列表
                if (_backupFiles.isNotEmpty) ...[
                  Text('本地备份', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._backupFiles.map((file) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.description),
                      title: Text(file.path.split('/').last),
                      subtitle: Text('${file.lengthSync() ~/ 1024} KB'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteBackup(file),
                      ),
                      onTap: () async {
                        final result = await _backupService.restoreFromFile(file.path);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.summary)));
                        }
                      },
                    ),
                  )),
                ],
              ],
            ),
    );
  }
}
