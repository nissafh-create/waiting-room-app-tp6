import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:waiting_room_app/models/client.dart';
import 'package:waiting_room_app/providers/queue_provider.dart';
import 'package:waiting_room_app/repositories/queue_repository.dart';
import 'package:waiting_room_app/services/geolocation_service.dart';

class FakeGeolocationService extends Fake implements GeolocationService {
  @override
  Future<Position?> getCurrentPosition() async => null;
}

class FakeQueueRepository extends Fake implements QueueRepository {
  @override
  Future<void> registerOnServer(Client client) async {}

  @override
  Future<void> deleteOnServer(String id) async {}

  @override
  Future<List<Client>> fetchPage({required int offset, required int limit}) async => [];
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    databaseFactory = databaseFactoryFfi;
  });

  test('should add a client to the waiting list', () async {
    final manager = QueueProvider(
      FakeQueueRepository(),
      FakeGeolocationService(),
    );

    await manager.addClient('Ahmed haddad');

    expect(manager.clients.length, 1);
    expect(manager.clients.first['name'], 'Ahmed haddad');
  });

  test('should remove a client from the waiting list', () async {
    final manager = QueueProvider(
      FakeQueueRepository(),
      FakeGeolocationService(),
    );
    await manager.addClient('Client 1');
    await manager.addClient('Client 2');

    final clientId = manager.clients.first['id'].toString();
    await manager.removeClient(clientId);

    expect(manager.clients.length, 1);
    expect(manager.clients.first['name'], 'Client 2');
  });

  test('should remove the first client when nextClient() is called', () async {
    final manager = QueueProvider(
      FakeQueueRepository(),
      FakeGeolocationService(),
    );
    await manager.addClient('Client 1');
    await manager.addClient('Client 2');

    await manager.nextClient();

    expect(manager.clients.length, 1);
    expect(manager.clients.first['name'], 'Client 2');
  });
}
