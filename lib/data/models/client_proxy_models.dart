/// A proxy node the user can pick in settings; the selected [url] is written
/// into the local tool configs during initialization.
class ClientProxyOption {
  const ClientProxyOption({required this.name, required this.url});

  final String name;
  final String url;

  factory ClientProxyOption.fromJson(Map<String, dynamic> json) {
    return ClientProxyOption(
      name: json['name']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }

  static List<ClientProxyOption> listFromJson(List<dynamic> json) {
    return json
        .whereType<Map<String, dynamic>>()
        .map(ClientProxyOption.fromJson)
        .where((option) => option.url.isNotEmpty)
        .toList();
  }
}
