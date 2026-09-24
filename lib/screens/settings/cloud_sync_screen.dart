import 'package:flutter/material.dart';

import '../../cloud/cloud_config.dart';
import '../../cloud/cloud_sync_service.dart';

class CloudSyncScreen extends StatefulWidget {
  const CloudSyncScreen({super.key});

  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends State<CloudSyncScreen> {
  bool _busy = false;
  DateTime? _lastCloudUpdate;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    try {
      final value = await CloudSyncService.instance.getLatestTimestamp();
      if (mounted) setState(() => _lastCloudUpdate = value);
    } catch (_) {}
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
        await _loadMetadata();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cloud error: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = CloudSyncService.instance.isConfigured;
    return Scaffold(
      appBar: AppBar(title: const Text('Cloud Sync')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(configured ? Icons.cloud_done : Icons.cloud_off,
                        color: configured ? Colors.green : Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        configured
                            ? 'Cloud sync is connected. Your local database can be uploaded and restored on another device.'
                            : 'Cloud sync is not configured yet. The app continues to work normally with its local database.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!configured) ...[
              const Text('One-time setup'),
              const SizedBox(height: 8),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Create a Firebase project, enable Anonymous Authentication and Cloud Storage, then run flutterfire configure for Android and Windows. The generated Firebase values are then placed in lib/cloud/cloud_config.dart.',
                  ),
                ),
              ),
            ] else ...[
              if (_lastCloudUpdate != null)
                Text('Latest cloud backup: ${_lastCloudUpdate!.toLocal()}'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _run(
                  () => CloudSyncService.instance.uploadLatest(),
                  'Latest database backup uploaded to the cloud.',
                ),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Upload Latest Backup'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _run(
                  () async {
                    final ok = await CloudSyncService.instance.downloadLatestAndRestore();
                    if (!ok) throw StateError('No cloud backup found.');
                  },
                  'Cloud backup restored. Restart the app to refresh all screens.',
                ),
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Restore Latest Cloud Backup'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Restore replaces the current local database. Use it when setting up another PC/phone or when you intentionally want to roll back to the cloud copy.',
              ),
            ],
            if (_busy) const Padding(padding: EdgeInsets.only(top: 24), child: Center(child: CircularProgressIndicator())),
            if (!CloudConfig.isConfigured) const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
