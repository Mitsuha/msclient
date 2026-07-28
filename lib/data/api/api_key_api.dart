import 'package:desktop/core/api/api_client.dart';
import 'package:desktop/data/models/api_key_models.dart';

class ApiKeyApi {
  const ApiKeyApi(this._client);

  final ApiClient _client;

  /// Every enabled key of the current account. The endpoint is paginated, but
  /// an account's key count is small enough to ask for all of them at once.
  Future<ApiKeyList> listEnabled({required String token}) async {
    final json = await _client.getJson(
      '/api-keys/',
      token: token,
      query: const {'page': '1', 'size': '999', 'status': '0'},
    );
    return ApiKeyList.fromJson(json);
  }
}
