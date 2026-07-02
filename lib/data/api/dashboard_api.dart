import 'package:desktop/core/api/api_client.dart';
import 'package:desktop/data/models/dashboard_models.dart';

class DashboardApi {
  const DashboardApi(this._client);

  final ApiClient _client;

  Future<DashboardOverview> overview({required String token}) async {
    final json = await _client.getJson('/dashboard/overview', token: token);
    return DashboardOverview.fromJson(json);
  }
}
