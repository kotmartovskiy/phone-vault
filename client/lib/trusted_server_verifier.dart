import 'phone_vault_client.dart';
import 'trusted_server_registry.dart';

class TrustedServerVerificationStatus {
  final TrustedServer trustedServer;
  final ServerSession? session;
  final String state;

  const TrustedServerVerificationStatus({
    required this.trustedServer,
    required this.state,
    this.session,
  });

  bool get isTrusted => state == 'trusted';
}

/// Verifies only the endpoint already stored in the trust registry.
/// Discovery is never allowed to replace that endpoint or receive its token.
class TrustedServerVerifier {
  const TrustedServerVerifier();

  Future<TrustedServerVerificationStatus> verify({
    required TrustedServer trustedServer,
    required PhoneVaultClient client,
  }) async {
    try {
      final session = await client.session();
      if (session.serverId != trustedServer.serverId) {
        return TrustedServerVerificationStatus(
          trustedServer: trustedServer,
          session: session,
          state: 'identity-mismatch',
        );
      }
      if (session.deviceId != client.deviceId) {
        return TrustedServerVerificationStatus(
          trustedServer: trustedServer,
          session: session,
          state: 'device-mismatch',
        );
      }
      return TrustedServerVerificationStatus(
        trustedServer: trustedServer,
        session: session,
        state: 'trusted',
      );
    } catch (_) {
      return TrustedServerVerificationStatus(
        trustedServer: trustedServer,
        state: 'offline',
      );
    }
  }
}
