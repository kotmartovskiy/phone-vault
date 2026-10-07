import 'package:flutter_test/flutter_test.dart';
import 'package:phone_vault_client/sync_policy.dart';

void main() {
  const policy = SyncPolicy(automatic: true);

  test('automatic transfer requires trusted server', () {
    expect(
      policy.canTransfer(
        trustedServer: false,
        network: SyncNetwork.wifi,
        batteryPercent: 80,
        charging: false,
      ),
      isFalse,
    );
  });

  test('wifi is allowed above battery floor', () {
    expect(
      policy.canTransfer(
        trustedServer: true,
        network: SyncNetwork.wifi,
        batteryPercent: 20,
        charging: false,
      ),
      isTrue,
    );
  });

  test('mobile data is denied by default', () {
    expect(
      policy.canTransfer(
        trustedServer: true,
        network: SyncNetwork.mobile,
        batteryPercent: 90,
        charging: true,
      ),
      isFalse,
    );
  });

  test('charging requirement is enforced', () {
    const chargingOnly = SyncPolicy(automatic: true, requireCharging: true);
    expect(
      chargingOnly.canTransfer(
        trustedServer: true,
        network: SyncNetwork.wifi,
        batteryPercent: 90,
        charging: false,
      ),
      isFalse,
    );
  });

  test('low battery blocks transfer', () {
    expect(
      policy.canTransfer(
        trustedServer: true,
        network: SyncNetwork.wifi,
        batteryPercent: 19,
        charging: true,
      ),
      isFalse,
    );
  });
}
