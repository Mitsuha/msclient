import 'package:desktop/core/api/api_client.dart';
import 'package:desktop/data/models/pack_models.dart';

class UserPackApi {
  const UserPackApi(this._client);

  final ApiClient _client;

  Future<UserPackList> listActive({required String token}) async {
    final json = await _client.getJson(
      '/user/pack',
      token: token,
      query: const {'status': '1'},
    );
    return UserPackList.fromJson(json);
  }
}
