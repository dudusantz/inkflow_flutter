# Controle de Alterações e Guia de Banco de Dados

## Checklist de Ações

- [x] Implementação de segurança de navegação nas rotas com `context.canPop()`
- [ ] Execução da migration `supabase/migrations/001_rf02_artist_profile.sql` no painel do Supabase

---

## 🛠️ Alterações Implementadas (Navegação Segura)

### Motivação
Quando o aplicativo era aberto diretamente em uma sub-rota (por exemplo, `/care` ou `/search`) e a pilha do navegador estava vazia, clicar no botão de "Voltar" chamava `context.pop()`, disparando o erro `GoError: There is nothing to pop` e travando a navegação.

### Lógica Utilizada
Substituímos o retorno direto `context.pop()` por uma verificação condicional:
```dart
onPressed: () {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/home'); // Fallback para a tela principal
  }
}
```

### Antes vs. Depois da Atualização

#### care_screen.dart
**Antes:**
```dart
leading: IconButton(
  icon: const Icon(Icons.arrow_back_ios_new,
      color: Colors.white, size: 20),
  onPressed: () => context.pop(),
),
```
**Depois:**
```dart
leading: IconButton(
  icon: const Icon(Icons.arrow_back_ios_new,
      color: Colors.white, size: 20),
  onPressed: () {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  },
),
```

#### favorites_screen.dart
**Antes:**
```dart
leading: IconButton(
  icon: const Icon(Icons.arrow_back_ios_new,
      color: Colors.white, size: 20),
  onPressed: () => context.pop(),
),
```
**Depois:**
```dart
leading: IconButton(
  icon: const Icon(Icons.arrow_back_ios_new,
      color: Colors.white, size: 20),
  onPressed: () {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  },
),
```

#### inbox_screen.dart
**Antes:**
```dart
leading: IconButton(
  icon:
      const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
  onPressed: () => context.pop(),
),
```
**Depois:**
```dart
leading: IconButton(
  icon:
      const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
  onPressed: () {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  },
),
```

#### chat_screen.dart
**Antes:**
```dart
leading: IconButton(
  icon:
      const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
  onPressed: () => context.pop(),
),
```
**Depois:**
```dart
leading: IconButton(
  icon:
      const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
  onPressed: () {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  },
),
```

#### profile_setup_screen.dart
**Antes:**
```dart
leading: IconButton(
  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
  onPressed: () => context.pop(),
),
```
**Depois:**
```dart
leading: IconButton(
  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
  onPressed: () {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  },
),
```

#### search_screen.dart
**Antes:**
```dart
IconButton(
  icon: const Icon(Icons.arrow_back_ios_new,
      color: Colors.white, size: 20),
  onPressed: () => context.pop(),
  padding: const EdgeInsets.all(8),
  constraints: const BoxConstraints(),
),
```
**Depois:**
```dart
IconButton(
  icon: const Icon(Icons.arrow_back_ios_new,
      color: Colors.white, size: 20),
  onPressed: () {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  },
  padding: const EdgeInsets.all(8),
  constraints: const BoxConstraints(),
),
```

---

## 🗄️ Guia de Banco de Dados (Supabase Setup)

### Motivação do Erro 400
A chamada de API do Supabase falhava com o status `400 Bad Request` indicando que a coluna `profiles.styles` não existia no banco de dados. Similarmente, os carregamentos de imagens da pasta de portfólio no storage resultavam em 400 porque o bucket `portfolio` e suas políticas de segurança RLS não foram criados.

### Solução
Executar as seguintes definições no painel do Supabase (SQL Editor):
Consulte o arquivo de migração completo em: [001_rf02_artist_profile.sql](file:///m:/dev3/inkflow_flutter/supabase/migrations/001_rf02_artist_profile.sql)
