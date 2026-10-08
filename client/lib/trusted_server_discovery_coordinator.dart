import 'package:phone_vault_client/phone_vault_client.dart';
import 'package:phone_vault_client/server_discovery.dart';
import 'package:phone_vault_client/trusted_server_registry.dart';
import 'package:phone_vault_client/trusted_server_resolver.dart';
import 'package:phone_vault_client/trusted_server_verifier.dart';

enum TrustedServerDiscoveryState {
  found,
  untrusted,
  endpointChanged,
  ready,
  identityMismatch,
  deviceMismatch,
  offline,
}

class TrustedServerDiscoveryResult {
  final DiscoveredServer? discovered;
  final TrustedServer? trustedServer;
  final TrustedServerVerificationStatus? verification;
  final TrustedServerDiscoveryState state;

  const TrustedServerDiscoveryResult({
    this.discovered,
    this.trustedServer,
    this.verification,
    required this.state,
  });

  bool get isTrustedReady => verification?.isTrusted == true;
  bool get endpointChanged => state == TrustedServerDiscoveryState.endpointChanged;
}

class TrustedServerDiscoveryCoordinator {
  final ServerDiscovery discovery;
  final TrustedServerRegistry registry;
  final TrustedServerVerifier verifier;

  const TrustedServerDiscoveryCoordinator({
    required this.discovery,
    required this.registry,
    this.verifier = const TrustedServerVerifier(),
  });

  Future<List<TrustedServerDiscoveryResult>> discoverAndVerify(
    PhoneVaultClient authenticatedClient,
  ) async {
    final discovered = await discovery.discover();
    final resolver = TrustedServerResolver(registry);
    final results = <TrustedServerDiscoveryResult>[];
    final seenTrustedIds = <String>{};

    for (final server in discovered) {
      final trusted = resolver.resolve(server);
      if (trusted == null) {
        results.add(TrustedServerDiscoveryResult(
          discovered: server,
          state: TrustedServerDiscoveryState.untrusted,
        ));
        continue;
      }

      seenTrustedIds.add(trusted.serverId);
      final verification = await _verifyStoredEndpoint(trusted, authenticatedClient);
      final endpointMatches = _sameEndpoint(server.endpoint, trusted.endpoint);
      final state = endpointMatches
          ? _stateFromVerification(verification)
          : verification.isTrusted
              ? TrustedServerDiscoveryState.endpointChanged
              : _stateFromVerification(verification);

      results.add(TrustedServerDiscoveryResult(
        discovered: server,
        trustedServer: trusted,
        verification: verification,
        state: state,
      ));
    }

    for (final trusted in registry.load()) {
      if (seenTrustedIds.contains(trusted.serverId)) continue;
      final verification = await _verifyStoredEndpoint(trusted, authenticatedClient);
      results.add(TrustedServerDiscoveryResult(
        trustedServer: trusted,
        verification: verification,
        state: _stateFromVerification(verification),
      ));
    }

    return results;
  }

  Future<TrustedServerVerificationStatus> _verifyStoredEndpoint(
    TrustedServer trusted,
    PhoneVaultClient client,
  ) {
    return verifier.verify(
      trustedServer: trusted,
      client: client.forEndpoint(trusted.endpoint),
    );
  }

  static bool _sameEndpoint(Uri a, Uri b) =>
      _normalizeEndpoint(a) == _normalizeEndpoint(b);

  static String _normalizeEndpoint(Uri endpoint) =>
      endpoint.replace(path: '', query: '', fragment: '').toString();

  static TrustedServerDiscoveryState _stateFromVerification(
    TrustedServerVerificationStatus verification,
  ) {
    switch (verification.state) {
      case 'trusted':
        return TrustedServerDiscoveryState.ready;
      case 'identity-mismatch':
        return TrustedServerDiscoveryState.identityMismatch;
      case 'device-mismatch':
        return TrustedServerDiscoveryState.deviceMismatch;
      default:
        return TrustedServerDiscoveryState.offline;
    }
  }
}
