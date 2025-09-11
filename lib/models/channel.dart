class Channel {
  final String name;
  final String url;
  final String group;
  final String logo;
  final String? catchupUrl;
  final Map<String, String> attributes;

  Channel({
    required this.name,
    required this.url,
    required this.group,
    required this.logo,
    this.catchupUrl,
    this.attributes = const {},
  });

  factory Channel.fromMap(Map<String, String> map) {
    return Channel(
      name: map['name'] ?? 'Unknown Channel',
      url: map['url'] ?? '',
      group: map['group'] ?? 'Ungrouped',
      logo: map['logo'] ?? '',
      catchupUrl: map['catchup-source'],
      attributes: Map<String, String>.from(map)..removeWhere((key, value) => 
        ['name', 'url', 'group', 'logo', 'catchup-source'].contains(key)),
    );
  }

  @override
  String toString() {
    return 'Channel{name: $name, url: $url, group: $group, logo: $logo}';
  }
}