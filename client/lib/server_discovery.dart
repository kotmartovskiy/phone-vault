import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ServerIdentity {
  final String serverId;
  final String version;
  const ServerIdentity({required this.serverId, required this.version});

  factory ServerIdentity.fromJson(Map<String, dynamic> json) {
    final id = json['server_id'];
    final version = json['version'];
    if (id is! String || id.isEmpty || version is! String || version.isEmpty) {
      throw const FormatException('Invalid server identity');
    }
    return ServerIdentity(serverId: id, version: version);
  }
}

class DiscoveredServer {
  final Uri endpoint;
  final ServerIdentity identity;
  const DiscoveredServer({required this.endpoint, required this.identity});
}

abstract interface class ServerDiscovery {
  Future<List<DiscoveredServer>> discover();
}

/// Bounded discovery over caller-supplied endpoints.
/// LAN scanning/mDNS remains a platform adapter and is deliberately not
/// implemented in the platform-neutral core.
class EndpointServerDiscovery implements ServerDiscovery {
  final Iterable<Uri> endpoints;
  final Duration timeout;
  final http.Client _http;

  EndpointServerDiscovery(
    this.endpoints, {
    this.timeout = const Duration(seconds: 2),
    http.Client? client,
  }) : _http = client ?? http.Client();

  @override
  Future<List<DiscoveredServer>> discover() async {
    final results = <DiscoveredServer>[];
    final seen = <String>{};
    for (final endpoint in endpoints) {
      final normalized = endpoint.toString().replaceFirst(RegExp(r'/*$'), '');
      if (!seen.add(normalized)) continue;
      try {
        final base = Uri.parse('$normalized/');
        final response = await _http
            .get(base.resolve('api/v1/identity'))
            .timeout(timeout);
        if (response.statusCode != 200) continue;
        final json = jsonDecode(response.body);
        if (json is! Map<String, dynamic>) continue;
        results.add(DiscoveredServer(
          endpoint: base,
          identity: ServerIdentity.fromJson(json),
        ));
      } catch (_) {
        // Discovery is best-effort: unavailable or malformed endpoints are ignored.
      }
    }
    return results;
  }

  void close() => _http.close();
}
