import 'package:desktop/core/api/api_client.dart';
import 'package:desktop/features/models/account_models.dart';

class AuthApi {
  const AuthApi(this._client);

  final ApiClient _client;

  Future<LoginResult> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    final payload = <String, String>{
      'password': password,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    };
    final json = await _client.postJson('/auth/login', body: payload);
    return LoginResult.fromJson(json);
  }
}
