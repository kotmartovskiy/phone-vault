import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'server_discovery.dart';

class TrustedServer {
  final String serverId;
  final Uri endpoint;
  final String? displayName;
  final DateTime trustedAt;

  const TrustedServer({
    required this.serverId,
    required this.endpoint,
    this.displayName,
    required this.trustedAt,
  });

  Map<String, dynamic> toJson() => {
        'server_id': serverId,
        'endpoint': endpoint.toString(),
        if (displayName != null) 'display_name': displayName,
        'trusted_at': trustedAt.toIso8601String(),
      };

  factory TrustedServer.fromJson(Map<String, dynamic> json) {
    final id = json['server_id'];
    final endpoint = json['endpoint'];
    final trustedAt = json['trusted_at'];
    if (id is! String || id.isEmpty ||
        endpoint is! String || endpoint.isEmpty ||
        trustedAt is! String) {
      throw const FormatException('Invalid trusted server');
    }
    return TrustedServer(
      serverId: id,
      endpoint: Uri.parse(endpoint),
      displayName: json['display_name'] is String ? json['display_name'] as String : null,
      trustedAt: DateTime.parse(trustedAt),
    );
  }
}

class TrustedServerRegistry {
  static const _key = 'phone_vault.trusted_servers.v1';
  final SharedPreferences _prefs;

  TrustedServerRegistry(this._prefs);

  List<TrustedServer> load() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => TrustedServer.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(TrustedServer server) async {
    final items = load().where((item) => item.serverId != server.serverId).toList();
    items.add(server);
    await _prefs.setString(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<void> remove(String serverId) async {
    final items = load().where((item) => item.serverId != serverId);
    await _prefs.setString(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  TrustedServer? findById(String serverId) {
    for (final item in load()) {
      if (item.serverId == serverId) return item;
    }
    return null;
  }

  TrustedServer? match(DiscoveredServer discovered) =>
      findById(discovered.identity.serverId);
}
