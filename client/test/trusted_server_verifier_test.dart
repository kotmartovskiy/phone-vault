import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:phone_vault_client/phone_vault_client.dart';
import 'package:phone_vault_client/trusted_server_registry.dart';
import 'package:phone_vault_client/trusted_server_verifier.dart';

class _FakeClient extends http.BaseClient {
  final Map<String, http.Response> responses;
  final List<Uri> requested = [];

  _FakeClient(this.responses);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requested.add(request.url);
    final response = responses[request.url.toString()];
    if (response == null) {
      return http.StreamedResponse(Stream.value(<int>[]), 503);
    }
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

TrustedServer _trusted() => TrustedServer(
      serverId: 'server-1',
      endpoint: Uri.parse('http://192.168.3.236:8766/'),
      trustedAt: DateTime.utc(2026, 10, 8),
    );

PhoneVaultClient _client(_FakeClient httpClient) => PhoneVaultClient(
      _trusted().endpoint.toString(),
      client: httpClient,
      token: 'secret',
      deviceId: 'device-1',
    );

void main() {
  test('accepts matching authenticated server and device identity', () async {
    final fake = _FakeClient({
      'http://192.168.3.236:8766/api/v1/session': http.Response(
        '{"server_id":"server-1","version":"0.2.0","device_id":"device-1"}',
        200,
      ),
    });
    final result = await const TrustedServerVerifier().verify(
      trustedServer: _trusted(),
      client: _client(fake),
    );
    expect(result.state, 'trusted');
    expect(result.isTrusted, isTrue);
  });

  test('does not trust endpoint when authenticated server identity changes', () async {
    final fake = _FakeClient({
      'http://192.168.3.236:8766/api/v1/session': http.Response(
        '{"server_id":"attacker","version":"0.2.0","device_id":"device-1"}',
        200,
      ),
    });
    final result = await const TrustedServerVerifier().verify(
      trustedServer: _trusted(),
      client: _client(fake),
    );
    expect(result.state, 'identity-mismatch');
    expect(result.isTrusted, isFalse);
  });

  test('does not trust endpoint for a different device identity', () async {
    final fake = _FakeClient({
      'http://192.168.3.236:8766/api/v1/session': http.Response(
        '{"server_id":"server-1","version":"0.2.0","device_id":"other-device"}',
        200,
      ),
    });
    final result = await const TrustedServerVerifier().verify(
      trustedServer: _trusted(),
      client: _client(fake),
    );
    expect(result.state, 'device-mismatch');
  });

  test('keeps trusted server offline instead of changing its endpoint', () async {
    final fake = _FakeClient({});
    final trusted = _trusted();
    final result = await const TrustedServerVerifier().verify(
      trustedServer: trusted,
      client: _client(fake),
    );
    expect(result.state, 'offline');
    expect(result.trustedServer.endpoint, trusted.endpoint);
  });
}
