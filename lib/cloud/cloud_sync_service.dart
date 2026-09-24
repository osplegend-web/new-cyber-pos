import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/db/db_helper.dart';
import 'cloud_config.dart';

/// Cloud backup/sync foundation.
///
/// The app stays offline-first: SQLite remains the local working database.
/// When Firebase is configured, the complete database is uploaded as a
/// timestamped cloud snapshot. Another Windows/Android installation can then
/// download the latest snapshot and restore it.
///
/// This intentionally avoids pretending that two devices can safely edit the
/// same SQLite file concurrently. A future true multi-device live-sync layer
/// can be built on top of the same Firebase project without throwing away the
/// current local database.
class CloudSyncService {
  CloudSyncService._();
  static final instance = CloudSyncService._();

  final _db = DBHelper.instance;
  final _uuid = const Uuid();
  bool _initialized = false;
  String? _shopId;

  bool get isConfigured => CloudConfig.isConfigured && _initialized;
  String? get shopId => _shopId;

  Future<void> initialize() async {
    if (_initialized) return;
    if (!CloudConfig.isConfigured) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: CloudConfig.options);
      }
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      final prefs = await SharedPreferences.getInstance();
      _shopId = prefs.getString('cloud_shop_id');
      _shopId ??= _uuid.v4();
      await prefs.setString('cloud_shop_id', _shopId!);
      _initialized = true;
    } catch (_) {
      // Cloud is optional. A bad/missing Firebase configuration must never
      // prevent the local POS from starting.
      _initialized = false;
    }
  }

  Reference _latestRef() {
    if (!isConfigured) {
      throw StateError('Cloud sync is not configured yet.');
    }
    return FirebaseStorage.instance.ref('shops/$_shopId/latest/cybercafe_pos.db');
  }

  Future<File> _makeSnapshot() async {
    await _db.closeDb();
    final sourcePath = await _db.getDbPath();
    final source = File(sourcePath);
    final dir = await getTemporaryDirectory();
    final snapshot = File(p.join(dir.path, 'cybercafe_pos_cloud_snapshot.db'));
    await source.copy(snapshot.path);
    await _db.database;
    return snapshot;
  }

  Future<void> uploadLatest() async {
    await initialize();
    if (!isConfigured) {
      throw StateError(
        'Firebase is not configured. Run flutterfire configure and enable cloud settings first.',
      );
    }

    final snapshot = await _makeSnapshot();
    try {
      await _latestRef().putFile(
        snapshot,
        SettableMetadata(contentType: 'application/x-sqlite3'),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cloud_last_upload', DateTime.now().toIso8601String());
    } finally {
      if (await snapshot.exists()) await snapshot.delete();
    }
  }

  Future<DateTime?> getLatestTimestamp() async {
    await initialize();
    if (!isConfigured) return null;
    final metadata = await _latestRef().getMetadata();
    return metadata.updated;
  }

  Future<bool> downloadLatestAndRestore() async {
    await initialize();
    if (!isConfigured) {
      throw StateError(
        'Firebase is not configured. Run flutterfire configure and enable cloud settings first.',
      );
    }

    final dir = await getTemporaryDirectory();
    final downloaded = File(p.join(dir.path, 'cybercafe_pos_cloud_restore.db'));
    await _latestRef().writeToFile(downloaded);

    await _db.closeDb();
    final target = await _db.getDbPath();
    await downloaded.copy(target);
    await _db.database;
    if (await downloaded.exists()) await downloaded.delete();
    return true;
  }
}
