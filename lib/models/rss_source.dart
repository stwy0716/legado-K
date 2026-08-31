import '../models/rss_article.dart';

/// RSS订阅源模型
class RssSource {
  int? id;
  String name;
  String url;
  String? group;
  bool? enabled;
  int? lastUpdateTime;
  int? unreadCount;
  String? icon;
  String? description;

  RssSource({
    this.id,
    required this.name,
    required this.url,
    this.group,
    this.enabled = true,
    this.lastUpdateTime,
    this.unreadCount = 0,
    this.icon,
    this.description,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'url': url,
    'group_name': group,
    'enabled': enabled == true ? 1 : 0,
    'lastUpdateTime': lastUpdateTime,
    'unreadCount': unreadCount,
    'icon': icon,
    'description': description,
  };

  factory RssSource.fromMap(Map<String, dynamic> map) => RssSource(
    id: map['id'] as int?,
    name: map['name'] as String,
    url: map['url'] as String,
    group: map['group_name'] as String?,
    enabled: (map['enabled'] as int?) == 1,
    lastUpdateTime: map['lastUpdateTime'] as int?,
    unreadCount: map['unreadCount'] as int? ?? 0,
    icon: map['icon'] as String?,
    description: map['description'] as String?,
  );
}
