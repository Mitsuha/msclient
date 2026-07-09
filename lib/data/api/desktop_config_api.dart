import 'package:desktop/core/api/api_client.dart';
import 'package:desktop/data/models/client_proxy_models.dart';

/// Desktop-facing app configs served by the dashboard; client proxy nodes are
/// one of them.
class DesktopConfigApi {
  const DesktopConfigApi(this._client);

  final ApiClient _client;

  /// Fetches the enabled proxy nodes, server-sorted so the first entry is the
  /// recommended default. Public endpoint — no token required.
  Future<List<ClientProxyOption>> clientProxies() async {
    final json = await _client.getJsonList('/app/configs/client-proxy');
    return ClientProxyOption.listFromJson(json);
  }
}
