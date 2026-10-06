import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'phone_vault_client.dart';
import 'file_explorer.dart';
import 'native_file_index.dart';

void main() => runApp(const PhoneVaultApp());

class PhoneVaultApp extends StatelessWidget {
  const PhoneVaultApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'Phone Vault',
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true),
      home: const VaultHome());
}

class VaultHome extends StatefulWidget {
  const VaultHome({super.key});
  @override
  State<VaultHome> createState() => _VaultHomeState();
}

class _VaultHomeState extends State<VaultHome> {
  final _server = TextEditingController(text: 'http://192.168.3.236:8766');
  final _name = TextEditingController(text: 'My Phone');
  PhoneVaultClient? _client;
  String? _deviceId, _token, _fileName;
  String _status = 'Not connected';
  double? _progress;
  bool _busy = false;
  bool _cancelRequested = false;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    final savedServer = p.getString('server');
    final savedDevice = p.getString('device_id');
    final savedToken = p.getString('token');
    if (mounted) {
      setState(() {
        if (savedServer != null && savedServer.isNotEmpty)
          _server.text = savedServer;
        if (savedDevice != null && savedDevice.isNotEmpty)
          _deviceId = savedDevice;
        if (savedToken != null && savedToken.isNotEmpty) {
          _token = savedToken;
          _status = 'Saved pairing available';
        }
      });
    }
  }

  @override
  void dispose() {
    _client?.close();
    _server.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _status = 'Checking server...';
    });
    try {
      final url = _server.text.trim();
      final client = PhoneVaultClient(url, token: _token, deviceId: _deviceId);
      if (!await client.health())
        throw StateError('Server health check failed');
      _client?.close();
      _client = client;
      await _prefs?.setString('server', url);
      setState(() => _status = 'Server is reachable');
    } catch (e) {
      setState(() => _status = 'Connection error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pair() async {
    final client = _client;
    if (client == null) {
      setState(() => _status = 'Connect to the server first');
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Pairing...';
    });
    try {
      final pair = await client
          .pair(_name.text.trim().isEmpty ? 'My Phone' : _name.text.trim());
      _token = pair.token;
      _deviceId = pair.deviceId;
      client.token = pair.token;
      client.deviceId = pair.deviceId;
      await _prefs?.setString('device_id', pair.deviceId);
      await _prefs?.setString('token', pair.token);
      setState(() {
        _deviceId = pair.deviceId;
        _status = 'Paired successfully; token saved locally';
      });
    } catch (e) {
      setState(() => _status = 'Pairing error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _sha256(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  Future<void> _pickAndUpload() async {
    final client = _client, deviceId = _deviceId;
    if (client == null || deviceId == null) {
      setState(() => _status = 'Connect and pair first');
      return;
    }
    final selected = await Navigator.of(context).push<List<PhoneFile>>(
      MaterialPageRoute(builder: (_) => const FileExplorerPage()),
    );
    if (selected == null || selected.isEmpty) return;
    _cancelRequested = false;
    setState(() {
      _busy = true;
      _progress = 0;
      _status = 'Uploading ${selected.length} selected file(s)...';
    });
    try {
      for (var i = 0; i < selected.length; i++) {
        if (_cancelRequested) break;
        final item = selected[i];
        final file = File(item.path);
        setState(() => _fileName = item.name);
        final digest = await _sha256(file);
        if (_cancelRequested) break;
        await client.uploadFile(
          deviceId: deviceId,
          file: file,
          sha256: digest,
          onProgress: (sent, total) {
            if (mounted)
              setState(() => _progress = total == 0 ? 1 : sent / total);
          },
          isCancelled: () => _cancelRequested,
        );
      }
      if (_cancelRequested) {
        setState(() =>
            _status = 'Upload interrupted; partial data was kept for resume');
      } else {
        setState(() {
          _progress = 1;
          _status = 'All selected files uploaded; originals were not modified';
        });
      }
    } catch (e) {
      setState(() => _status = 'Upload error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _cancelUpload() {
    if (!_busy) return;
    _cancelRequested = true;
    setState(() => _status = 'Stopping after current operation...');
  }

  @override
  Widget build(BuildContext context) {
    final pct =
        _progress == null ? null : (_progress! * 100).toStringAsFixed(0);
    return Scaffold(
        appBar: AppBar(title: const Text('Phone Vault')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          TextField(
              controller: _server,
              decoration: const InputDecoration(
                  labelText: 'Server URL', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Device name', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: FilledButton(
                    onPressed: _busy ? null : _connect,
                    child: const Text('Connect'))),
            const SizedBox(width: 12),
            Expanded(
                child: FilledButton(
                    onPressed: _busy ? null : _pair, child: const Text('Pair')))
          ]),
          const SizedBox(height: 12),
          if (_busy) ...[
            FilledButton.icon(
              onPressed: _cancelUpload,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Interrupt upload'),
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError),
            ),
            const SizedBox(height: 8),
          ] else
            FilledButton.icon(
              onPressed: _pickAndUpload,
              icon: const Icon(Icons.upload_file),
              label: const Text('Select file and upload'),
            ),
          const SizedBox(height: 20),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_status),
                        if (_deviceId != null) ...[
                          const SizedBox(height: 8),
                          Text('Device: $_deviceId',
                              style: Theme.of(context).textTheme.bodySmall)
                        ],
                        if (_fileName != null) ...[
                          const SizedBox(height: 12),
                          Text(_fileName!,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600))
                        ],
                        if (_progress != null) ...[
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: _progress),
                          const SizedBox(height: 4),
                          Text('$pct%')
                        ]
                      ]))),
          const SizedBox(height: 12),
          const Text(
              'Safety: the app only reads the selected file. It does not delete, move, or overwrite files on the phone. Uploads use resumable chunks and SHA-256 verification.',
              style: TextStyle(fontSize: 13))
        ]));
  }
}
