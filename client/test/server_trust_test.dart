import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phone_vault_client/server_discovery.dart';
import 'package:phone_vault_client/trusted_server_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('trusted server registry round trips and matches by stable server id', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final registry = TrustedServerRegistry(prefs);
    final server = TrustedServer(
      serverId: 'server-123',
      endpoint: Uri.parse('http://192.168.3.236:8766/'),
      displayName: 'Lenovo server',
      trustedAt: DateTime.utc(2026, 10, 7),
    );
    await registry.save(server);

    final loaded = registry.findById('server-123');
    expect(loaded?.endpoint.toString(), 'http://192.168.3.236:8766/');
    expect(loaded?.displayName, 'Lenovo server');

    final discovered = DiscoveredServer(
      endpoint: Uri.parse('http://192.168.3.237:8766/'),
      identity: const ServerIdentity(serverId: 'server-123', version: '0.2.0'),
    );
    expect(registry.match(discovered)?.serverId, 'server-123');
  });

  test('malformed trusted server registry is ignored safely', () async {
    SharedPreferences.setMockInitialValues({
      'phone_vault.trusted_servers.v1': '{bad json',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(TrustedServerRegistry(prefs).load(), isEmpty);
  });
}
