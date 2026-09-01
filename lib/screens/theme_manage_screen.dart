import 'package:flutter/material.dart';

class CustomTheme {
  final String id;
  final String name;
  final int primaryColor;
  final int secondaryColor;
  final int backgroundColor;
  final int surfaceColor;
  final bool isDark;

  CustomTheme({required this.id, required this.name, required this.primaryColor, required this.secondaryColor, required this.backgroundColor, required this.surfaceColor, this.isDark = false});

  factory CustomTheme.fromJson(Map<String, dynamic> json) => CustomTheme(
    id: json['id'] ?? '', name: json['name'] ?? '',
    primaryColor: json['primaryColor'] ?? 0xFF6750A4,
    secondaryColor: json['secondaryColor'] ?? 0xFF625B71,
    backgroundColor: json['backgroundColor'] ?? 0xFFFFFBFE,
    surfaceColor: json['surfaceColor'] ?? 0xFFFFFBFE,
    isDark: json['isDark'] ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'primaryColor': primaryColor,
    'secondaryColor': secondaryColor, 'backgroundColor': backgroundColor,
    'surfaceColor': surfaceColor, 'isDark': isDark,
  };
}

class ThemeManageScreen extends StatefulWidget {
  const ThemeManageScreen({super.key});

  @override
  State<ThemeManageScreen> createState() => _ThemeManageScreenState();
}

class _ThemeManageScreenState extends State<ThemeManageScreen> {
  final List<CustomTheme> _themes = [
    CustomTheme(id: 'default', name: '默认主题', primaryColor: 0xFF6750A4, secondaryColor: 0xFF625B71, backgroundColor: 0xFFFFFBFE, surfaceColor: 0xFFFFFBFE),
    CustomTheme(id: 'blue', name: '蓝色主题', primaryColor: 0xFF1976D2, secondaryColor: 0xFF0288D1, backgroundColor: 0xFFF5F9FF, surfaceColor: 0xFFFFFFFF),
    CustomTheme(id: 'green', name: '绿色主题', primaryColor: 0xFF2E7D32, secondaryColor: 0xFF00796B, backgroundColor: 0xFFF1F8E9, surfaceColor: 0xFFFFFFFF),
    CustomTheme(id: 'orange', name: '橙色主题', primaryColor: 0xFFE64A19, secondaryColor: 0xFFF57C00, backgroundColor: 0xFFFFF3E0, surfaceColor: 0xFFFFFFFF),
    CustomTheme(id: 'dark', name: '深色主题', primaryColor: 0xFFBB86FC, secondaryColor: 0xFF03DAC6, backgroundColor: 0xFF121212, surfaceColor: 0xFF1E1E1E, isDark: true),
  ];

  String _selectedThemeId = 'default';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('主题管理')),
      body: ListView.builder(
        itemCount: _themes.length,
        itemBuilder: (context, index) {
          final theme = _themes[index];
          final selected = _selectedThemeId == theme.id;
          return Card(
            color: selected ? Color(theme.primaryColor).withOpacity(0.1) : null,
            child: ListTile(
              leading: CircleAvatar(backgroundColor: Color(theme.primaryColor), child: Icon(theme.isDark ? Icons.dark_mode : Icons.light_mode, color: Colors.white, size: 20)),
              title: Text(theme.name),
              subtitle: Text('主色: #${theme.primaryColor.toRadixString(16).toUpperCase().padLeft(8, '0')}'),
              trailing: selected ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.radio_button_unchecked),
              onTap: () => setState(() => _selectedThemeId = theme.id),
              onLongPress: () => _showThemeEdit(theme, index),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTheme,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddTheme() {
    final nameController = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('新建主题'),
      content: TextField(controller: nameController, decoration: const InputDecoration(labelText: '主题名称', border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: () {
          if (nameController.text.isNotEmpty) {
            setState(() => _themes.add(CustomTheme(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: nameController.text, primaryColor: 0xFF6750A4,
              secondaryColor: 0xFF625B71, backgroundColor: 0xFFFFFBFE, surfaceColor: 0xFFFFFBFE,
            )));
          }
          Navigator.pop(context);
        }, child: const Text('创建')),
      ],
    ));
  }

  void _showThemeEdit(CustomTheme theme, int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('编辑主题: ${theme.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildColorRow('主色调', theme.primaryColor, (c) => setState(() => _themes[index] = CustomTheme(id: theme.id, name: theme.name, primaryColor: c, secondaryColor: theme.secondaryColor, backgroundColor: theme.backgroundColor, surfaceColor: theme.surfaceColor, isDark: theme.isDark))),
          _buildColorRow('背景色', theme.backgroundColor, (c) => setState(() => _themes[index] = CustomTheme(id: theme.id, name: theme.name, primaryColor: theme.primaryColor, secondaryColor: theme.secondaryColor, backgroundColor: c, surfaceColor: theme.surfaceColor, isDark: theme.isDark))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('完成'))),
        ]),
      ),
    );
  }

  Widget _buildColorRow(String label, int color, ValueChanged<int> onChanged) {
    final colors = [0xFF6750A4, 0xFF1976D2, 0xFF2E7D32, 0xFFE64A19, 0xFFC62828, 0xFF00838F, 0xFF6A1B9A, 0xFF37474F];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        SizedBox(width: 60, child: Text(label)),
        Expanded(child: Wrap(spacing: 8, children: colors.map((c) => GestureDetector(
          onTap: () => onChanged(c),
          child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle, border: c == color ? Border.all(color: Colors.white, width: 2) : null)),
        )).toList())),
      ]),
    );
  }
}
