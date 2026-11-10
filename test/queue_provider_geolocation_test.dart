import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:waiting_room_app/models/client.dart';
import 'package:waiting_room_app/providers/queue_provider.dart';
import 'package:waiting_room_app/repositories/queue_repository.dart';

import 'queue_provider_geolocation_test.mocks.dart';

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

  test('addClient saves client with geolocation', () async {
    final mockGeo = MockGeolocationService();
    final mockPos = Position(
      latitude: 37.7749,
      longitude: -122.4194,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );

    when(mockGeo.getCurrentPosition()).thenAnswer((_) async => mockPos);

    final provider = QueueProvider(
      FakeQueueRepository(),
      mockGeo,
    );

    await provider.addClient('Test User');

    final client = provider.clients.first;
    expect(client['lat'], 37.7749);
    expect(client['lng'], -122.4194);
  });
}
