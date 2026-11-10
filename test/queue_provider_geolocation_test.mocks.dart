// Mocks for tests
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i3;
import 'package:flutter/foundation.dart' as _i6;
import 'package:geolocator/geolocator.dart' as _i4;
import 'package:mockito/mockito.dart' as _i1;
import 'package:waiting_room_app/geolocation_service.dart' as _i2;
import 'package:waiting_room_app/models/queue_state.dart' as _i7;
import 'package:waiting_room_app/queue_provider.dart' as _i5;

/// A class which mocks [GeolocationService].
class MockGeolocationService extends _i1.Mock
    implements _i2.GeolocationService {
  MockGeolocationService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i3.Future<_i4.Position?> getCurrentPosition() => (super.noSuchMethod(
        Invocation.method(
          #getCurrentPosition,
          [],
        ),
        returnValue: _i3.Future<_i4.Position?>.value(),
      ) as _i3.Future<_i4.Position?>);
}

/// A class which mocks [QueueProvider].
class MockQueueProvider extends _i1.Mock implements _i5.QueueProvider {
  MockQueueProvider() {
    _i1.throwOnMissingStub(this);
  }

  @override
  List<dynamic> get clients => (super.noSuchMethod(
        Invocation.getter(#clients),
        returnValue: <dynamic>[],
      ) as List<dynamic>);

  @override
  _i7.QueueState get state => (super.noSuchMethod(
        Invocation.getter(#state),
        returnValue: _i7.QueueState.loaded,
      ) as _i7.QueueState);

  @override
  bool get hasMore => (super.noSuchMethod(
        Invocation.getter(#hasMore),
        returnValue: false,
      ) as bool);

  @override
  bool get isLoadingMore => (super.noSuchMethod(
        Invocation.getter(#isLoadingMore),
        returnValue: false,
      ) as bool);

  @override
  String? get errorMessage => (super.noSuchMethod(
        Invocation.getter(#errorMessage),
        returnValue: null,
      ) as String?);

  @override
  void addListener(_i6.VoidCallback? listener) => super.noSuchMethod(
        Invocation.method(#addListener, [listener]),
        returnValueForMissingStub: null,
      );

  @override
  void removeListener(_i6.VoidCallback? listener) => super.noSuchMethod(
        Invocation.method(#removeListener, [listener]),
        returnValueForMissingStub: null,
      );

  @override
  void dispose() => super.noSuchMethod(
        Invocation.method(#dispose, []),
        returnValueForMissingStub: null,
      );

  @override
  bool get hasListeners => (super.noSuchMethod(
        Invocation.getter(#hasListeners),
        returnValue: false,
      ) as bool);
}
