import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:inkflow/core/data/supabase_providers.dart';
import 'package:inkflow/features/search/domain/artist_summary.dart';

/// Leitura da vitrine publica de tatuadores.
///
/// Consulta a view `artist_directory` (migration 002) em vez de `profiles`:
/// a view projeta somente colunas divulgaveis, entao nao ha como um `select`
/// aberto trazer CPF ou data de nascimento de volta por descuido.
class ArtistDirectoryRepository {
  final SupabaseClient _supabase;

  ArtistDirectoryRepository(this._supabase);

  Future<List<ArtistSummary>> listArtists() async {
    final rows = await _supabase.from('artist_directory').select();
    return _map(rows);
  }

  Future<List<ArtistSummary>> trending({int limit = 5}) async {
    final rows = await _supabase
        .from('artist_directory')
        .select()
        .order('rating', ascending: false)
        .limit(limit)
        .timeout(const Duration(seconds: 10));
    return _map(rows);
  }

  Future<ArtistSummary?> findById(String artistId) async {
    final row = await _supabase
        .from('artist_directory')
        .select()
        .eq('id', artistId)
        .maybeSingle()
        .timeout(const Duration(seconds: 10));

    if (row == null) return null;
    return ArtistSummary.fromRow(Map<String, dynamic>.from(row));
  }

  List<ArtistSummary> _map(List<dynamic> rows) {
    return rows
        .map((row) => ArtistSummary.fromRow(Map<String, dynamic>.from(row)))
        .toList();
  }
}

final artistDirectoryRepositoryProvider =
    Provider<ArtistDirectoryRepository>((ref) {
  return ArtistDirectoryRepository(ref.watch(supabaseClientProvider));
});
