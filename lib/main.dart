import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/client.dart';
import 'providers/connectivity_provider.dart';
import 'providers/queue_provider.dart';
import 'repositories/queue_repository.dart';
import 'screens/queue_screen.dart';
import 'services/connectivity_service.dart';
import 'services/geolocation_service.dart';
import 'services/sync_service.dart';
import 'storage/local_queue_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite FFI for desktop (Windows / Linux)
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 1. Load the .env file
  await dotenv.load(fileName: ".env");

  // 2. Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  final supabase = Supabase.instance.client;
  final localStorage = LocalQueueStorage();
  final repository = QueueRepository(supabase);
  final geoService = GeolocationService();
  final syncService = SyncService(localStorage, repository);
  final connectivityService = ConnectivityService(supabase);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ConnectivityProvider(connectivityService)..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) {
            final queueProvider = QueueProvider(
              repository,
              geoService,
              storage: localStorage,
              syncService: syncService,
            )..fetchInitialQueue();

            // Set up Realtime listener to reconcile events without duplicates
            try {
              supabase
                  .channel('public:clients')
                  .onPostgresChanges(
                    event: PostgresChangeEvent.insert,
                    schema: 'public',
                    table: 'clients',
                    callback: (payload) {
                      final client = Client.fromSupabaseMap(payload.newRecord);
                      queueProvider.handleRealtimeInsert(client);
                    },
                  )
                  .onPostgresChanges(
                    event: PostgresChangeEvent.delete,
                    schema: 'public',
                    table: 'clients',
                    callback: (payload) {
                      final deletedId = payload.oldRecord['id']?.toString();
                      if (deletedId != null) {
                        queueProvider.handleRealtimeDelete(deletedId);
                      }
                    },
                  )
                  .subscribe();
            } catch (e) {
              debugPrint('Realtime channel subscription error: $e');
            }

            return queueProvider;
          },
        ),
      ],
      child: const WaitingRoomApp(),
    ),
  );
}

class WaitingRoomApp extends StatelessWidget {
  const WaitingRoomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waiting Room',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const QueueScreen(),
    );
  }
}

// Backward-compatibility alias for tests
typedef WaitingRoomScreen = QueueScreen;
