# InkFlow — Flutter App

Plataforma que conecta tatuadores e clientes: busca de profissionais, chat, agenda,
anamnese e dashboard. Frontend em **Flutter + Dart**, backend em **Supabase**
(Auth, Postgres com RLS, Realtime e Storage).

---

## Como rodar

### Pré-requisitos

- Flutter SDK `>=3.0.0` ([flutter.dev](https://flutter.dev/docs/get-started/install))
- Dart `>=3.0.0`
- Um projeto Supabase

### Passos

```bash
# 1. Dependências
flutter pub get

# 2. Credenciais
cp .env.example .env      # e preencha SUPABASE_URL e SUPABASE_ANON_KEY

# 3. Banco de dados — execute na ordem, no SQL Editor do Supabase:
#    supabase/migrations/001_rf02_artist_profile.sql
#    supabase/migrations/002_rls_policies.sql

# 4. Rodar
flutter run
```

> **A migration `002` não é opcional.** Ela cria as políticas de RLS, as views
> `artist_directory` e `chat_directory` e a constraint que impede conflito de
> horário. O código do app pressupõe que elas existam: sem isso o banco fica
> aberto e a agenda perde a proteção contra agendamento duplo.

Verificação local:

```bash
flutter analyze lib test
flutter test
```

---

## Estrutura de pastas

Organização por *feature*, cada uma com suas próprias camadas:

```
lib/
├── main.dart                       # Bootstrap: .env, Supabase, locale pt_BR
├── router.dart                     # go_router + guards de autenticação
├── core/
│   ├── data/supabase_providers.dart   # Cliente e sessão (injetáveis em teste)
│   ├── errors/error_utils.dart        # Tradução de erros para o usuário
│   ├── theme/app_theme.dart           # Cores e tema global
│   ├── utils/                         # TimeSlot, PasswordPolicy
│   └── widgets/shared_widgets.dart    # Componentes reutilizáveis
└── features/
    ├── auth/          # RF01 — login, cadastro, recuperação de senha
    ├── chat/          # RF04/RF05 — inbox e conversa
    ├── dashboard/     # RF10 — métricas e faturamento
    ├── home/          # RF08 — home de cliente e de tatuador
    ├── profile/       # RF02 — perfil, portfólio, notificações, privacidade
    ├── schedule/      # RF06/RF07/RF09 — agenda, anamnese, lembretes
    └── search/        # RF03 — busca de tatuadores

supabase/migrations/    # Schema e políticas de acesso
Docs/                   # Documentação do projeto
test/                   # 63 testes
tool/docs_pdf.js        # Gera o PDF da documentação
```

Cada feature segue `domain/` (modelos tipados) → `data/` (repositórios que falam
com o Supabase) → `providers/` → `presentation/` (telas). Nenhuma tela chama o
cliente do Supabase diretamente; é isso que torna as regras testáveis.

---

## Requisitos funcionais

Cenários BDD completos (RF01–RF10): **[Docs/requisitos-funcionais.md](Docs/requisitos-funcionais.md)**

| RF | Tela | Situação |
|---|---|---|
| RF01 — Cadastro | `auth/register_screen` | Implementado (CPF, menoridade com responsável, duplicidade) |
| RF02 — Perfil profissional | `profile/profile_setup_screen` | Implementado (estilos, preços, portfólio no Storage) |
| RF03 — Busca | `search/search_screen` | Implementado sobre a view `artist_directory` |
| RF04/RF05 — Chat e propostas | `chat/chat_screen` | Chat em tempo real implementado; **propostas em desenvolvimento** |
| RF06 — Agenda manual | `schedule/schedule_screen` | Implementado, com conflito de horário barrado no banco |
| RF07 — Anamnese | `schedule/anamnesis_screen` | **Pré-visualização** — não persiste nada |
| RF08 — Agenda do dia | `home/artist_home_screen` | Implementado |
| RF09 — Lembretes | `schedule/reminders_screen` | Preferência gravada; **disparo automático em desenvolvimento** |
| RF10 — Dashboard | `dashboard/dashboard_screen` | **Dados de demonstração** |

As telas ainda não concluídas exibem um aviso `UnderDevelopmentBanner`, para não
apresentarem dados de demonstração como se fossem informação de produção.

---

## Estado técnico

A análise completa do código — segurança e LGPD, bugs, arquitetura, testes e
infraestrutura — está em **[Docs/analise-tecnica.md](Docs/analise-tecnica.md)**
([PDF](Docs/analise-tecnica.pdf)), com o que já foi corrigido e o que continua em
aberto.

Pontos em aberto de maior impacto:

1. O projeto **não está sob controle de versão** (não existe `.git`).
2. Não há CI rodando `flutter analyze` e `flutter test`.
3. Arquivos de protótipo ainda no repositório (`telas.rar`, `telas/`,
   `package.json` com `puppeteer-core`, `.idea/`, `inkflow.iml`).
4. Acessibilidade (`Semantics`, escala de texto, contraste) e internacionalização.

---

## Dependências

| Pacote | Uso |
|---|---|
| `supabase_flutter` | Auth, Postgres, Realtime e Storage |
| `flutter_riverpod` | Providers e injeção de dependências |
| `go_router` | Navegação declarativa e guards de rota |
| `flutter_dotenv` | Leitura de `SUPABASE_URL` e `SUPABASE_ANON_KEY` |
| `cached_network_image` | Cache e fallback de imagens de rede |
| `image_picker` | Seleção de fotos do portfólio |
| `mask_text_input_formatter` | Máscaras de CPF, telefone e data |
| `fl_chart` | Gráfico de barras do dashboard |
| `google_fonts` | Fonte Inter |
| `intl` + `flutter_localizations` | Formatação e componentes em pt-BR |
