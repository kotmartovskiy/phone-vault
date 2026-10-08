import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phone_vault_client/phone_vault_client.dart';
import 'package:phone_vault_client/server_discovery.dart';
import 'package:phone_vault_client/trusted_server_discovery_coordinator.dart';
import 'package:phone_vault_client/trusted_server_registry.dart';

class _Discovery implements ServerDiscovery {
  final List<DiscoveredServer> servers;
  _Discovery(this.servers);
  @override
  Future<List<DiscoveredServer>> discover() async => servers;
}

class TestHttpClient extends http.BaseClient {
  final Map<String, http.Response> responses;
  final List<Uri> requested = [];
  TestHttpClient(this.responses);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requested.add(request.url);
    final r = responses[request.url.toString()];
    if (r == null) return http.StreamedResponse(Stream.value(<int>[]), 503);
    return http.StreamedResponse(Stream.value(r.bodyBytes), r.statusCode, headers: r.headers);
  }
}

TrustedServer trusted() => TrustedServer(
  serverId: 'server-1',
  endpoint: Uri.parse('http://192.168.3.236:8766/'),
  trustedAt: DateTime.utc(2026, 10, 8),
);

DiscoveredServer discovered(String host) => DiscoveredServer(
  endpoint: Uri.parse('http://$host:8766/'),
  identity: const ServerIdentity(serverId: 'server-1', version: '0.2.0'),
);

Future<TrustedServerRegistry> registry() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final r = TrustedServerRegistry(prefs);
  await r.save(trusted());
  return r;
}

PhoneVaultClient client(TestHttpClient http) => PhoneVaultClient(
  'http://192.168.3.236:8766/',
  client: http,
  token: 'test-token',
  deviceId: 'device-1',
);

http.Response session(String serverId) => http.Response(
  '{"server_id":"$serverId","version":"0.2.0","device_id":"device-1"}', 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('same endpoint becomes ready', () async {
    final r = await registry();
    final h = TestHttpClient({'http://192.168.3.236:8766/api/v1/session': session('server-1')});
    final c = TrustedServerDiscoveryCoordinator(
      discovery: _Discovery([discovered('192.168.3.236')]), registry: r);
    final result = (await c.discoverAndVerify(client(h))).single;
    expect(result.state, TrustedServerDiscoveryState.ready);
    expect(result.isTrustedReady, isTrue);
  });

  test('changed discovered endpoint never receives credentials', () async {
    final r = await registry();
    final h = TestHttpClient({'http://192.168.3.236:8766/api/v1/session': session('server-1')});
    final c = TrustedServerDiscoveryCoordinator(
      discovery: _Discovery([discovered('192.168.3.99')]), registry: r);
    final result = (await c.discoverAndVerify(client(h))).single;
    expect(result.state, TrustedServerDiscoveryState.endpointChanged);
    expect(result.trustedServer!.endpoint.toString(), 'http://192.168.3.236:8766/');
    expect(h.requested.single.host, '192.168.3.236');
  });

  test('unknown server is untrusted and is not contacted with token', () async {
    final r = await registry();
    final h = TestHttpClient({});
    final unknown = DiscoveredServer(
      endpoint: Uri.parse('http://192.168.3.99:8766/'),
      identity: const ServerIdentity(serverId: 'unknown', version: '0.2.0'));
    final c = TrustedServerDiscoveryCoordinator(
      discovery: _Discovery([unknown]), registry: r);
    final results = await c.discoverAndVerify(client(h));
    final result = results.firstWhere((e) => e.state == TrustedServerDiscoveryState.untrusted);
    expect(result.state, TrustedServerDiscoveryState.untrusted);
    expect(result.trustedServer, isNull);
    expect(h.requested, isNotEmpty);
    expect(h.requested, everyElement(predicate<Uri>((uri) => uri.host == '192.168.3.236')));
  });

  test('trusted server is verified even when discovery finds nothing', () async {
    final r = await registry();
    final h = TestHttpClient({'http://192.168.3.236:8766/api/v1/session': session('server-1')});
    final c = TrustedServerDiscoveryCoordinator(
      discovery: _Discovery(const []), registry: r);
    final result = (await c.discoverAndVerify(client(h))).single;
    expect(result.discovered, isNull);
    expect(result.state, TrustedServerDiscoveryState.ready);
  });

  test('identity mismatch is surfaced without migration', () async {
    final r = await registry();
    final h = TestHttpClient({'http://192.168.3.236:8766/api/v1/session': session('other')});
    final c = TrustedServerDiscoveryCoordinator(
      discovery: _Discovery([discovered('192.168.3.236')]), registry: r);
    final result = (await c.discoverAndVerify(client(h))).single;
    expect(result.state, TrustedServerDiscoveryState.identityMismatch);
    expect(result.isTrustedReady, isFalse);
  });
}
