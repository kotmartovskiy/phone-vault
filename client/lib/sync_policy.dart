enum SyncNetwork { wifi, ethernet, mobile, unknown }

class SyncPolicy {
  final bool automatic;
  final bool allowWifi;
  final bool allowEthernet;
  final bool allowMobile;
  final bool requireCharging;
  final int minimumBatteryPercent;

  const SyncPolicy({
    this.automatic = false,
    this.allowWifi = true,
    this.allowEthernet = true,
    this.allowMobile = false,
    this.requireCharging = false,
    this.minimumBatteryPercent = 20,
  }) : assert(minimumBatteryPercent >= 0 && minimumBatteryPercent <= 100);

  bool canTransfer({
    required bool trustedServer,
    required SyncNetwork network,
    required int batteryPercent,
    required bool charging,
  }) {
    if (!automatic || !trustedServer) return false;
    if (batteryPercent < minimumBatteryPercent) return false;
    if (requireCharging && !charging) return false;

    switch (network) {
      case SyncNetwork.wifi:
        return allowWifi;
      case SyncNetwork.ethernet:
        return allowEthernet;
      case SyncNetwork.mobile:
        return allowMobile;
      case SyncNetwork.unknown:
        return false;
    }
  }
}
