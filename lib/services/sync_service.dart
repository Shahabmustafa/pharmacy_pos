import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/local/database/app_database.dart';
import '../data/repositories/settings_repository.dart';
import 'connectivity_service.dart';

enum SyncStatus { idle, syncing, success, error, offline }

class SyncState {
  final SyncStatus status;
  final String message;
  final int pendingCount;

  const SyncState({
    this.status = SyncStatus.idle,
    this.message = '',
    this.pendingCount = 0,
  });

  SyncState copyWith({SyncStatus? status, String? message, int? pendingCount}) {
    return SyncState(
      status: status ?? this.status,
      message: message ?? this.message,
      pendingCount: pendingCount ?? this.pendingCount,
    );
  }
}

class SyncService extends StateNotifier<SyncState> {
  final AppDatabase _db;
  final ConnectivityService _connectivity;
  final SettingsRepository _settings;
  Timer? _syncTimer;
  bool _isSyncing = false;

  SyncService(this._db, this._connectivity, this._settings)
      : super(const SyncState()) {
    _startAutoSync();
    _connectivity.onConnectivityChanged.listen((online) {
      if (online) _triggerSync();
    });
  }

  void _startAutoSync() {
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      final autoSync = await _settings.get('auto_sync') == 'true';
      if (autoSync) _triggerSync();
    });
  }

  Future<void> _triggerSync() async {
    if (_isSyncing) return;
    final online = await _connectivity.isConnected;
    if (!online) {
      state = state.copyWith(status: SyncStatus.offline, message: 'No internet connection');
      return;
    }

    final supabaseUrl = await _settings.get('supabase_url');
    final supabaseKey = await _settings.get('supabase_anon_key');
    if (supabaseUrl == null || supabaseUrl.isEmpty) return;

    _isSyncing = true;
    state = state.copyWith(status: SyncStatus.syncing, message: 'Syncing data...');

    try {
      await _processSyncQueue(supabaseUrl, supabaseKey ?? '');
      final pending = await _getPendingCount();
      state = state.copyWith(
        status: SyncStatus.success,
        message: 'Sync complete',
        pendingCount: pending,
      );
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        message: 'Sync failed: ${e.toString()}',
      );
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _processSyncQueue(String url, String key) async {
    final queue = await (_db.select(_db.syncQueue)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();

    final supabase = SupabaseClient(url, key);

    for (final item in queue) {
      try {
        final data = jsonDecode(item.data) as Map<String, dynamic>;
        switch (item.operation) {
          case 'insert':
            await supabase.from(item.targetTable).insert(data);
          case 'update':
            await supabase
                .from(item.targetTable)
                .update(data)
                .eq('server_id', data['server_id']);
          case 'delete':
            await supabase
                .from(item.targetTable)
                .delete()
                .eq('server_id', data['server_id']);
        }
        await (_db.delete(_db.syncQueue)
              ..where((t) => t.id.equals(item.id)))
            .go();
      } catch (e) {
        await (_db.update(_db.syncQueue)
              ..where((t) => t.id.equals(item.id)))
            .write(SyncQueueCompanion(
          retryCount: Value(item.retryCount + 1),
          lastError: Value(e.toString()),
        ));
      }
    }
  }

  Future<int> _getPendingCount() async {
    final result = await _db.customSelect(
      'SELECT COUNT(*) as cnt FROM sync_queue',
      readsFrom: {_db.syncQueue},
    ).getSingle();
    return (result.data['cnt'] as int?) ?? 0;
  }

  Future<void> syncNow() => _triggerSync();

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}

final syncServiceProvider = StateNotifierProvider<SyncService, SyncState>((ref) {
  final db = ref.watch(databaseProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  final settings = ref.watch(settingsRepositoryProvider);
  return SyncService(db, connectivity, settings);
});
