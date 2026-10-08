import 'package:flutter_test/flutter_test.dart';
import 'package:phone_vault_client/phone_vault_client.dart';

void main() {
  test('ServerSession parses authenticated session identity', () {
    final session = ServerSession.fromJson({
      'server_id': 'server-123',
      'version': '0.2.0',
      'device_id': 'device-456',
    });

    expect(session.serverId, 'server-123');
    expect(session.version, '0.2.0');
    expect(session.deviceId, 'device-456');
  });

  test('ServerSession rejects incomplete identity', () {
    expect(
      () => ServerSession.fromJson({
        'server_id': 'server-123',
        'version': '0.2.0',
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
