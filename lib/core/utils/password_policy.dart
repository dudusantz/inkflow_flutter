/// Politica minima de senha da plataforma.
///
/// Centralizada aqui porque cadastro, recuperacao e troca de senha precisam da
/// mesma regra — antes cada tela exigia apenas "6 caracteres", sem checar
/// composicao.
class PasswordPolicy {
  static const minLength = 8;

  /// Mensagem de erro pronta para o `validator` de um `TextFormField`, ou
  /// `null` quando a senha e aceitavel.
  static String? validate(String? password) {
    if (password == null || password.isEmpty) {
      return 'A senha é obrigatória';
    }
    if (password.length < minLength) {
      return 'A senha deve ter no mínimo $minLength caracteres';
    }
    if (!password.contains(RegExp('[A-Za-zÀ-ÿ]'))) {
      return 'A senha deve conter ao menos uma letra';
    }
    if (!password.contains(RegExp(r'\d'))) {
      return 'A senha deve conter ao menos um número';
    }
    return null;
  }

  static bool isValid(String? password) => validate(password) == null;
}
