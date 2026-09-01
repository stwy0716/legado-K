import 'package:flutter/material.dart';
import '../models/book.dart';
import 'character_detail_screen.dart';

class BookCharacter {
  final String name;
  final String? avatar;
  final String? description;
  final String? gender;
  final List<String>? relations;
  final List<String>? quotes;
  final int? color;

  BookCharacter({required this.name, this.avatar, this.description, this.gender, this.relations, this.quotes, this.color});

  factory BookCharacter.fromJson(Map<String, dynamic> json) => BookCharacter(
    name: json['name'] ?? '',
    avatar: json['avatar'],
    description: json['description'],
    gender: json['gender'],
    relations: json['relations'] != null ? List<String>.from(json['relations']) : null,
    quotes: json['quotes'] != null ? List<String>.from(json['quotes']) : null,
    color: json['color'],
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'avatar': avatar,
    'description': description,
    'gender': gender,
    'relations': relations,
    'quotes': quotes,
    'color': color,
  };
}

class CharacterListScreen extends StatefulWidget {
  final Book book;
  const CharacterListScreen({super.key, required this.book});

  @override
  State<CharacterListScreen> createState() => _CharacterListScreenState();
}

class _CharacterListScreenState extends State<CharacterListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<BookCharacter> _characters = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCharacters();
  }

  Future<void> _loadCharacters() async {
    // 模拟加载角色数据
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _characters.addAll([
        BookCharacter(name: '主角', gender: '男', description: '故事的主人公', relations: ['朋友', '敌人'], quotes: ['我命由我不由天'], color: 0xFF6750A4),
        BookCharacter(name: '女主角', gender: '女', description: '故事的女主角', relations: ['主角'], quotes: ['我会一直陪着你'], color: 0xFFE91E63),
        BookCharacter(name: '反派', gender: '男', description: '主要反派角色', relations: ['主角'], quotes: ['这个世界是我的'], color: 0xFFF44336),
      ]);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.book.name} - 角色'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: '角色列表'), Tab(text: '关系网')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildCharacterList(), _buildCharacterNetwork()],
      ),
    );
  }

  Widget _buildCharacterList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_characters.isEmpty) return const Center(child: Text('暂无角色信息'));
    return ListView.builder(
      itemCount: _characters.length,
      itemBuilder: (context, index) {
        final char = _characters[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Color(char.color ?? 0xFF6750A4),
            child: Text(char.name.isNotEmpty ? char.name[0] : '?', style: const TextStyle(color: Colors.white)),
          ),
          title: Text(char.name),
          subtitle: Text('${char.gender ?? ''} ${char.description ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CharacterDetailScreen(character: char, bookName: widget.book.name))),
        );
      },
    );
  }

  Widget _buildCharacterNetwork() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_characters.isEmpty) return const Center(child: Text('暂无角色关系'));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: _characters.map((char) => Card(
          child: ExpansionTile(
            leading: CircleAvatar(backgroundColor: Color(char.color ?? 0xFF6750A4), child: Text(char.name[0], style: const TextStyle(color: Colors.white))),
            title: Text(char.name),
            subtitle: Text(char.description ?? ''),
            children: [
              if (char.relations != null) Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('关系:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: char.relations!.map((r) => Chip(label: Text(r))).toList()),
                ]),
              ),
              if (char.quotes != null) Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('名言:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...char.quotes!.map((q) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('"$q"', style: const TextStyle(fontStyle: FontStyle.italic)))),
                ]),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}
