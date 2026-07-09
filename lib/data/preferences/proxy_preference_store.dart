import 'package:shared_preferences/shared_preferences.dart';

/// Persists the proxy node url the user picked in settings.
class ProxyPreferenceStore {
  const ProxyPreferenceStore();

  static const _urlKey = 'mirrorstages.proxy.url';

  Future<String?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final url = preferences.getString(_urlKey);
    return (url == null || url.isEmpty) ? null : url;
  }

  Future<void> save(String url) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_urlKey, url);
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_urlKey);
  }
}
