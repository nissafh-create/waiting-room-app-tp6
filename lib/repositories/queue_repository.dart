import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/client.dart';

class QueueRepository {
  final SupabaseClient _supabase;

  QueueRepository(this._supabase);

  SupabaseClient get supabaseClient => _supabase;

  Future<List<Client>> fetchPage({required int offset, required int limit}) async {
    try {
      final response = await _supabase
          .from('clients')
          .select()
          .order('created_at', ascending: true)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((data) => Client.fromSupabaseMap(data as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Re-throw so callers (e.g. QueueProvider) handle errors and update QueueState
      rethrow;
    }
  }

  Future<void> registerOnServer(Client client) async {
    try {
      // First attempt using the Postgres RPC function specified in Workshop 6
      await _supabase.rpc('register_queue_client', params: {
        'p_id': client.id,
        'p_name': client.name,
        'p_lat': client.lat,
        'p_lng': client.lng,
        'p_accuracy': client.locationAccuracy,
        'p_created_at': client.createdAt.toIso8601String(),
      });
    } catch (rpcError) {
      // Fallback to direct upsert/insert if RPC is not defined on Supabase instance
      try {
        await _supabase.from('clients').upsert(client.toSupabaseMap());
      } catch (upsertError) {
        final err = upsertError.toString();
        if (err.contains('column') || err.contains('bigint') || err.contains('22P02')) {
          final payload = <String, dynamic>{'name': client.name};
          if (int.tryParse(client.id) != null) {
            payload['id'] = int.parse(client.id);
          }
          await _supabase.from('clients').insert(payload);
        } else {
          rethrow;
        }
      }
    }
  }

  Future<void> deleteOnServer(String id) async {
    try {
      if (int.tryParse(id) != null) {
        await _supabase.from('clients').delete().match({'id': int.parse(id)});
      } else {
        await _supabase.from('clients').delete().match({'id': id});
      }
    } catch (_) {
      // Ignore or log error
    }
  }
}

