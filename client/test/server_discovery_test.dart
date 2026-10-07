import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:phone_vault_client/server_discovery.dart';

class _FakeClient extends http.BaseClient {
  final Map<String, http.Response> responses;
  final List<Uri> requests = [];

  _FakeClient(this.responses);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request.url);
    final response = responses[request.url.toString()] ??
        http.Response('not found', 404);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

void main() {
  test('endpoint discovery parses identity and deduplicates endpoints', () async {
    final client = _FakeClient({
      'http://server-a:8766/api/v1/identity':
          http.Response('{"server_id":"server-a","version":"0.2.0"}', 200),
    });
    final discovery = EndpointServerDiscovery(
      [
        Uri.parse('http://server-a:8766/'),
        Uri.parse('http://server-a:8766'),
      ],
      client: client,
    );

    final found = await discovery.discover();

    expect(found, hasLength(1));
    expect(found.single.identity.serverId, 'server-a');
    expect(client.requests, hasLength(1));
    discovery.close();
  });

  test('endpoint discovery ignores unavailable and malformed endpoints', () async {
    final client = _FakeClient({
      'http://good:8766/api/v1/identity':
          http.Response('{"server_id":"good","version":"0.2.0"}', 200),
      'http://bad-json:8766/api/v1/identity':
          http.Response('{"server_id":""}', 200),
      'http://error:8766/api/v1/identity':
          http.Response('server error', 500),
    });
    final discovery = EndpointServerDiscovery(
      [
        Uri.parse('http://good:8766/'),
        Uri.parse('http://bad-json:8766/'),
        Uri.parse('http://error:8766/'),
      ],
      client: client,
    );

    final found = await discovery.discover();

    expect(found.map((e) => e.identity.serverId), ['good']);
    discovery.close();
  });
}
