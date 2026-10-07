import 'server_discovery.dart';
import 'trusted_server_registry.dart';

class TrustedServerResolver {
  final TrustedServerRegistry registry;

  const TrustedServerResolver(this.registry);

  TrustedServer? resolve(DiscoveredServer discovered) =>
      registry.match(discovered);

  List<DiscoveredServer> trusted(List<DiscoveredServer> discovered) =>
      discovered.where((server) => resolve(server) != null).toList(growable: false);
}
