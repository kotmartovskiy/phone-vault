import 'package:flutter_test/flutter_test.dart';
import 'package:phone_vault_client/nsd_server_discovery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Android NSD discovery has stable service type', () {
    final discovery = AndroidNsdServerDiscovery();
    expect(discovery.serviceType, '_phone-vault._tcp');
    discovery.close();
  });
}
