import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/client.dart';
import '../models/queue_state.dart';
import '../models/sync_status.dart';
import '../repositories/queue_repository.dart';
import '../services/geolocation_service.dart';
import '../services/sync_service.dart';
import '../storage/local_queue_storage.dart';

class QueueProvider extends ChangeNotifier {
  final QueueRepository _repository;
  final GeolocationService _geolocationService;
  final LocalQueueStorage? _storage;
  final SyncService? _syncService;

  final List<Client> _clients = [];
  QueueState _state = QueueState.initial;
  String? _errorMessage;

  int _page = 0;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  QueueProvider(
    this._repository,
    this._geolocationService, {
    LocalQueueStorage? storage,
    SyncService? syncService,
  })  : _storage = storage,
        _syncService = syncService;

  List<dynamic> get clients => List.unmodifiable(_clients);
  QueueState get state => _state;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;

  Future<void> fetchInitialQueue() async {
    _state = QueueState.loading;
    _page = 0;
    _hasMore = true;
    notifyListeners();

    try {
      final data = await _repository.fetchPage(offset: 0, limit: _pageSize);
      _clients.clear();
      _clients.addAll(data);
      _state = _clients.isEmpty ? QueueState.empty : QueueState.loaded;
      if (data.length < _pageSize) _hasMore = false;
    } catch (e) {
      _errorMessage = 'Failed to load queue';
      _state = QueueState.error;
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      _page++;
      final newClients = await _repository.fetchPage(
        offset: _page * _pageSize,
        limit: _pageSize,
      );

      final existingIds = _clients.map((c) => c.id).toSet();
      final uniqueNewClients =
          newClients.where((c) => !existingIds.contains(c.id));

      _clients.addAll(uniqueNewClients);
      if (newClients.length < _pageSize) _hasMore = false;
    } catch (_) {
      _page--;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void handleRealtimeInsert(Client client) {
    final exists = _clients.any((c) => c.id == client.id);
    if (!exists) {
      _clients.insert(0, client);
      if (_state == QueueState.empty) _state = QueueState.loaded;
      notifyListeners();
    }
  }

  void handleRealtimeDelete(String id) {
    _clients.removeWhere((c) => c.id == id);
    if (_clients.isEmpty) _state = QueueState.empty;
    notifyListeners();
  }

  Future<void> addClient(String name) async {
    if (name.trim().isEmpty) return;

    final position = await _geolocationService.getCurrentPosition();
    final client = Client(
      id: const Uuid().v4(),
      name: name.trim(),
      lat: position?.latitude,
      lng: position?.longitude,
      locationAccuracy: position?.accuracy,
      createdAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );

    // Persist locally
    final storage = _storage ?? LocalQueueStorage();
    await storage.saveClient(client.toLocalMap());

    // Update UI immediately
    _clients.add(client);
    if (_state == QueueState.empty || _state == QueueState.initial) {
      _state = QueueState.loaded;
    }
    notifyListeners();

    // Trigger sync
    if (_syncService != null) {
      unawaited(_syncService.synchronize());
    } else {
      try {
        await _repository.registerOnServer(client);
        await storage.updateSyncStatus(client.id, SyncStatus.synced);
      } catch (_) {
        await storage.updateSyncStatus(client.id, SyncStatus.failed);
      }
    }
  }

  Future<void> removeClient(String id) async {
    _clients.removeWhere((c) => c.id == id);
    if (_clients.isEmpty) {
      _state = QueueState.empty;
    }
    notifyListeners();

    final storage = _storage ?? LocalQueueStorage();
    await storage.deleteClient(id);
    await _repository.deleteOnServer(id);
  }

  Future<void> nextClient() async {
    if (_clients.isNotEmpty) {
      await removeClient(_clients.first.id);
    }
  }
}
