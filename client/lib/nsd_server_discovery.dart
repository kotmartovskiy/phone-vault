import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'server_discovery.dart';

class AndroidNsdServerDiscovery implements ServerDiscovery {
  static const _channel = MethodChannel('phone_vault/nsd');
  final Duration timeout;
  final http.Client _http;
  final String serviceType;

  AndroidNsdServerDiscovery({
    this.timeout = const Duration(seconds: 2),
    this.serviceType = '_phone-vault._tcp',
    http.Client? client,
  }) : _http = client ?? http.Client();

  @override
  Future<List<DiscoveredServer>> discover() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('discover', {
      'serviceType': serviceType,
      'timeoutMs': timeout.inMilliseconds,
    });
    final results = <DiscoveredServer>[];
    final seen = <String>{};
    for (final item in raw ?? const []) {
      if (item is! Map) continue;
      final host = item['host'];
      final port = item['port'];
      if (host is! String || host.isEmpty || port is! int || port <= 0) continue;
      final endpoint = Uri(scheme: 'http', host: host, port: port);
      final key = endpoint.toString();
      if (!seen.add(key)) continue;
      try {
        final response = await _http
            .get(endpoint.resolve('api/v1/identity'))
            .timeout(timeout);
        if (response.statusCode != 200) continue;
        final json = jsonDecode(response.body);
        if (json is! Map<String, dynamic>) continue;
        results.add(DiscoveredServer(
          endpoint: endpoint,
          identity: ServerIdentity.fromJson(json),
        ));
      } catch (_) {}
    }
    return results;
  }

  void close() => _http.close();
}
