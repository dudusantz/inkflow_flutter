import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
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

  Future<Map<String, dynamic>?> fetchProfessionalSettings() async {
    final user = _requireUser();
    return _supabase
        .from('profiles')
        .select('styles,min_price,hourly_rate,bio,career_start_year,'
            'experience_years,city,state,studio_name,instagram,'
            'portfolio_urls,portfolio_url')
        .eq('id', user.id)
        .eq('role', 'ARTIST')
        .maybeSingle()
        .timeout(const Duration(seconds: 10));
  }

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
    final contentType = lookupMimeType('', headerBytes: bytes);
    final extension = const {
      'image/jpeg': 'jpg',
      'image/png': 'png',
      'image/webp': 'webp',
      'image/gif': 'gif',
    }[contentType];
    if (extension == null) {
      throw const FormatException('Use uma imagem JPEG, PNG, WebP ou GIF.');
    }
    final path = '${user.id}/portfolio_${DateTime.now().microsecondsSinceEpoch}'
        '_$index.$extension';

    await _supabase.storage.from('portfolio').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
          ),
        );

    return _supabase.storage.from('portfolio').getPublicUrl(path);
  }

  Future<void> activateArtistProfile({
    required List<String> styles,
    required double minPrice,
    required double hourlyRate,
    required List<String> portfolioUrls,
    required String bio,
    required int careerStartYear,
    required String city,
    required String state,
    String? studioName,
    String? instagram,
  }) async {
    final user = _requireUser();

    await _supabase.from('profiles').update({
      'role': 'ARTIST',
      'styles': styles,
      'min_price': minPrice,
      'hourly_rate': hourlyRate,
      'portfolio_urls': portfolioUrls,
      'portfolio_url': portfolioUrls.isEmpty ? null : portfolioUrls.first,
      'bio': bio.trim(),
      'career_start_year': careerStartYear,
      // Mantido para compatibilidade com versões anteriores do app.
      'experience_years': DateTime.now().year - careerStartYear,
      'city': city.trim(),
      'state': state.trim().toUpperCase(),
      'studio_name':
          studioName?.trim().isEmpty == true ? null : studioName?.trim(),
      'instagram': instagram?.trim().isEmpty == true ? null : instagram?.trim(),
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
