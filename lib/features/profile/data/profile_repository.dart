import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:inkflow/core/data/supabase_providers.dart';
import 'package:inkflow/features/profile/domain/user_profile.dart';

/// Colunas do proprio perfil. A lista e explicita de proposito: `select()` sem
/// argumentos devolve a tabela inteira e ja vazou PII na tela de busca.
const _profileColumns =
    'id, name, avatar_url, role, phone, cpf, date_of_birth, guardian_cpf';

class ProfileRepository {
  final SupabaseClient _supabase;

  ProfileRepository(this._supabase);

  User? get _user => _supabase.auth.currentUser;

  /// Perfil do usuario logado, ou `null` se nao houver sessao.
  ///
  /// Em falha de rede cai para os metadados do Auth, para que a tela de perfil
  /// continue utilizavel offline.
  Future<UserProfile?> fetchMyProfile() async {
    final user = _user;
    if (user == null) return null;

    try {
      final row = await _supabase
          .from('profiles')
          .select(_profileColumns)
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (row != null) {
        return UserProfile.fromRow(Map<String, dynamic>.from(row), user);
      }
    } on TimeoutException {
      return UserProfile.fromAuthUser(user);
    }

    return UserProfile.fromAuthUser(user);
  }

  /// Troca o e-mail de login. O Supabase so efetiva apos a confirmacao no novo
  /// endereco.
  Future<void> updateEmail(String email) async {
    _requireUser();
    await _supabase.auth.updateUser(UserAttributes(email: email));
  }

  Future<void> updatePersonalData({
    required String name,
    String? phone,
    String? dateOfBirth,
    String? guardianCpf,
  }) async {
    final user = _requireUser();

    await _supabase.from('profiles').update({
      'name': name,
      'phone': phone,
      'date_of_birth': dateOfBirth,
      'guardian_cpf': guardianCpf,
    }).eq('id', user.id);
  }

  /// Sobe uma imagem do portfolio e devolve a URL publica.
  ///
  /// Erros sobem para o chamador: um upload parcial silencioso deixava o
  /// tatuador com o perfil ativo e o portfolio incompleto.
  Future<String> uploadPortfolioImage(Uint8List bytes, int index) async {
    final user = _requireUser();
    final path = '${user.id}/portfolio_$index.jpg';

    await _supabase.storage.from('portfolio').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    return _supabase.storage.from('portfolio').getPublicUrl(path);
  }

  Future<void> activateArtistProfile({
    required List<String> styles,
    required double minPrice,
    required double hourlyRate,
    required List<String> portfolioUrls,
  }) async {
    final user = _requireUser();

    await _supabase.from('profiles').update({
      'role': 'ARTIST',
      'styles': styles,
      'min_price': minPrice,
      'hourly_rate': hourlyRate,
      'portfolio_urls': portfolioUrls,
      'portfolio_url': portfolioUrls.isEmpty ? null : portfolioUrls.first,
    }).eq('id', user.id);
  }

  User _requireUser() {
    final user = _user;
    if (user == null) {
      throw const AuthException('Sessão expirada. Entre novamente.');
    }
    return user;
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});
