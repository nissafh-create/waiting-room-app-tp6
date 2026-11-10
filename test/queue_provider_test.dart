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
  final List<Client> registeredClients = [];

  @override
  Future<void> registerOnServer(Client client) async {
    registeredClients.add(client);
  }

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

  test('addClient saves locally and triggers remote sync', () async {
    final fakeRepo = FakeQueueRepository();
    final provider = QueueProvider(
      fakeRepo,
      FakeGeolocationService(),
    );

    await provider.addClient("Alice");

    expect(provider.clients.length, 1);
    expect(provider.clients.first['name'], 'Alice');
    expect(fakeRepo.registeredClients.length, 1);
    expect(fakeRepo.registeredClients.first.name, 'Alice');
  });
}
