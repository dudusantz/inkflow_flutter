import 'package:supabase_flutter/supabase_flutter.dart';

/// Perfil do usuario autenticado.
///
/// Substitui o `Map<String, dynamic>` que circulava entre providers e telas,
/// onde um erro de digitacao em nome de coluna so aparecia em runtime.
class UserProfile {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String role;
  final String? phone;
  final String? cpf;
  final String? dateOfBirth;
  final String? guardianCpf;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.phone,
    this.cpf,
    this.dateOfBirth,
    this.guardianCpf,
  });

  bool get isArtist => role == 'ARTIST';

  String get firstName => name.split(' ').first;

  /// Perfil vindo da tabela `profiles`, complementado com o e-mail da sessao
  /// (a coluna nao existe na tabela: o e-mail e propriedade do Auth).
  factory UserProfile.fromRow(Map<String, dynamic> row, User user) {
    return UserProfile(
      id: user.id,
      name: _nameOrFallback(row['name'], user),
      email: user.email ?? '',
      avatarUrl: _nonEmpty(row['avatar_url']),
      role: row['role']?.toString() ?? 'CLIENT',
      phone: _nonEmpty(row['phone']),
      cpf: _nonEmpty(row['cpf']),
      dateOfBirth: _nonEmpty(row['date_of_birth']),
      guardianCpf: _nonEmpty(row['guardian_cpf']),
    );
  }

  /// Fallback offline: monta o perfil a partir dos metadados do Auth quando a
  /// tabela `profiles` esta inacessivel.
  ///
  /// Os metadados sao editaveis pelo proprio usuario, entao campos de
  /// identidade (`cpf`, `guardian_cpf`) nao sao lidos daqui — apenas o que e
  /// puramente cosmetico.
  factory UserProfile.fromAuthUser(User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    return UserProfile(
      id: user.id,
      name: _nameOrFallback(metadata['name'], user),
      email: user.email ?? '',
      avatarUrl: _nonEmpty(metadata['avatar_url']),
      role: 'CLIENT',
      phone: _nonEmpty(metadata['phone']),
      dateOfBirth: _nonEmpty(metadata['date_of_birth']),
    );
  }

  static String _nameOrFallback(dynamic value, User user) {
    final name = _nonEmpty(value);
    if (name != null) return name;
    return user.email?.split('@').first ?? 'Usuário';
  }

  static String? _nonEmpty(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
