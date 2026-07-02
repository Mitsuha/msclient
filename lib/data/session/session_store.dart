import 'dart:convert';

import 'package:desktop/data/models/account_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionState {
  const SessionState({required this.token, required this.user});

  final String token;
  final UserProfile user;
}

class SessionStore {
  const SessionStore();

  static const _tokenKey = 'mirrorstages.session.token';
  static const _userKey = 'mirrorstages.session.user';

  Future<SessionState?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    final userJson = preferences.getString(_userKey);
    if (token == null || token.isEmpty || userJson == null) {
      return null;
    }

    try {
      final user = UserProfile.fromJson(
        jsonDecode(userJson) as Map<String, dynamic>,
      );
      return SessionState(token: token, user: user);
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> save(SessionState session) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, session.token);
    await preferences.setString(_userKey, jsonEncode(session.user.toJson()));
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    await preferences.remove(_userKey);
  }
}
