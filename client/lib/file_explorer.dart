import 'dart:io';
import 'package:flutter/material.dart';
import 'native_file_index.dart';

class FileExplorerPage extends StatefulWidget {
  const FileExplorerPage({super.key});
  @override State<FileExplorerPage> createState() => _FileExplorerPageState();
}

class _FileExplorerPageState extends State<FileExplorerPage> {
  List<PhoneFile> _all = [];
  final Set<String> _selected = {};
  String _category = 'All';
  String _time = 'All time';
  String _query = '';
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (!await NativeFileIndex.requestPermission()) {
        throw StateError('Storage access was not granted');
      }
      final files = await NativeFileIndex.listFiles();
      if (mounted) setState(() { _all = files; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<PhoneFile> get _filtered {
    final now = DateTime.now();
    return _all.where((f) {
      if (_category != 'All' && f.category != _category) return false;
      if (_query.isNotEmpty && !f.name.toLowerCase().contains(_query.toLowerCase())) return false;
      if (_time == 'Today' && f.modified.isBefore(DateTime(now.year, now.month, now.day))) return false;
      if (_time == '7 days' && f.modified.isBefore(now.subtract(const Duration(days: 7)))) return false;
      if (_time == '30 days' && f.modified.isBefore(now.subtract(const Duration(days: 30)))) return false;
      return true;
    }).toList()..sort((a, b) => b.modified.compareTo(a.modified));
  }

  Future<void> _chooseTime() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => Column(mainAxisSize: MainAxisSize.min, children: [
        for (final x in ['All time', 'Today', '7 days', '30 days'])
          ListTile(title: Text(x), onTap: () => Navigator.pop(c, x)),
      ]),
    );
    if (value != null) setState(() => _time = value);
  }

  Future<void> _preview(PhoneFile f) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(f.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: SizedBox(width: 320, child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (f.category == 'Images')
            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(f.path), height: 260, fit: BoxFit.contain))
          else Icon(f.icon, size: 90),
          const SizedBox(height: 12),
          Text(f.humanSize + ' • ' + f.modified.toLocal().toString()),
          const SizedBox(height: 6),
          Text(f.path, maxLines: 3, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  @override Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: Text('Files (' + _selected.length.toString() + ')'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: () => setState(() => _selected.clear()), icon: const Icon(Icons.clear_all)),
        ],
      ),
      floatingActionButton: _selected.isEmpty ? null : FloatingActionButton.extended(
        onPressed: () => Navigator.pop(context, _all.where((f) => _selected.contains(f.path)).toList()),
        icon: const Icon(Icons.cloud_upload_outlined),
        label: Text('Upload ' + _selected.length.toString()),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) :
        _error != null ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!), const SizedBox(height: 12),
          FilledButton(onPressed: _load, child: const Text('Grant access / retry')),
        ]))) :
        Column(children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(children: [
              for (final c in ['All', 'Images', 'Video', 'Audio', 'Documents', 'Archives'])
                Padding(padding: const EdgeInsets.only(right: 6), child: FilterChip(
                  label: Text(c), selected: _category == c,
                  onSelected: (_) => setState(() => _category = c),
                )),
            ]),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
            Expanded(child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search files'),
            )),
            IconButton(onPressed: _chooseTime, icon: const Icon(Icons.schedule), tooltip: _time),
            IconButton(onPressed: () => setState(() => _selected.addAll(list.map((f) => f.path))), icon: const Icon(Icons.select_all)),
          ])),
          Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 4), child: Align(
            alignment: Alignment.centerLeft,
            child: Text(list.length.toString() + ' files • ' + _time, style: Theme.of(context).textTheme.bodySmall),
          )),
          Expanded(child: list.isEmpty ? const Center(child: Text('No matching files')) : ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final f = list[i];
              final checked = _selected.contains(f.path);
              return ListTile(
                leading: CircleAvatar(child: Icon(f.icon)),
                title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(f.humanSize + ' • ' + f.folderLabel + ' • ' + f.modified.toLocal().toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(onPressed: () => _preview(f), icon: const Icon(Icons.visibility_outlined)),
                  Checkbox(value: checked, onChanged: (v) => setState(() => v == true ? _selected.add(f.path) : _selected.remove(f.path))),
                ]),
                onTap: () => setState(() => checked ? _selected.remove(f.path) : _selected.add(f.path)),
              );
            },
          )),
        ]),
    );
  }
}
