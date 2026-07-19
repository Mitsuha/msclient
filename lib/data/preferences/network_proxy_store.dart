import 'package:shared_preferences/shared_preferences.dart';

/// Persists the optional upstream HTTP proxy the user configured in settings
/// (the target for traffic that would otherwise dial out directly), plus a
/// one-shot flag marking whether the first-launch auto-detection has run.
class NetworkProxyStore {
  const NetworkProxyStore();

  static const _urlKey = 'mirrorstages.proxy.network_url';
  static const _autofilledKey = 'mirrorstages.proxy.network_autofilled';

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

  /// Whether the first-launch port probe has already run, so it never fires
  /// again after the first start.
  Future<bool> isAutofillDone() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_autofilledKey) ?? false;
  }

  Future<void> markAutofillDone() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_autofilledKey, true);
  }
}
