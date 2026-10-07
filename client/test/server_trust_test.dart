import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phone_vault_client/server_discovery.dart';
import 'package:phone_vault_client/trusted_server_registry.dart';
import 'package:phone_vault_client/trusted_server_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resolves only a known trusted server identity', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final registry = TrustedServerRegistry(prefs);
    await registry.save(TrustedServer(
      serverId: 'trusted-123',
      endpoint: Uri.parse('http://192.168.3.236:8766/'),
      displayName: 'Lenovo server',
      trustedAt: DateTime.utc(2026, 10, 7),
    ));

    final serverResolver = TrustedServerResolver(TrustedServerRegistry(prefs));

    final unknown = DiscoveredServer(
      endpoint: Uri.parse('http://192.168.3.237:8766/'),
      identity: const ServerIdentity(serverId: 'unknown-456', version: '0.2.0'),
    );
    expect(serverResolver.resolve(unknown), isNull);

    final trustedAtNewEndpoint = DiscoveredServer(
      endpoint: Uri.parse('http://192.168.3.99:8766/'),
      identity: const ServerIdentity(serverId: 'trusted-123', version: '0.2.0'),
    );
    expect(serverResolver.resolve(trustedAtNewEndpoint)?.serverId, 'trusted-123');
    expect(
      serverResolver.resolve(trustedAtNewEndpoint)?.endpoint.toString(),
      'http://192.168.3.236:8766/',
    );
  });

  test('filters discovered servers to trusted identities', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final registry = TrustedServerRegistry(prefs);
    await registry.save(TrustedServer(
      serverId: 'trusted-123',
      endpoint: Uri.parse('http://192.168.3.236:8766/'),
      trustedAt: DateTime.utc(2026, 10, 7),
    ));

    final resolver = TrustedServerResolver(registry);
    final discovered = [
      DiscoveredServer(
        endpoint: Uri.parse('http://192.168.3.236:8766/'),
        identity: const ServerIdentity(serverId: 'trusted-123', version: '0.2.0'),
      ),
      DiscoveredServer(
        endpoint: Uri.parse('http://192.168.3.240:8766/'),
        identity: const ServerIdentity(serverId: 'other-456', version: '0.2.0'),
      ),
    ];

    expect(resolver.trusted(discovered).map((e) => e.identity.serverId), ['trusted-123']);
  });

  test('malformed trusted server registry is ignored safely', () async {
    SharedPreferences.setMockInitialValues({
      'phone_vault.trusted_servers.v1': '{bad json',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(TrustedServerRegistry(prefs).load(), isEmpty);
  });
}
