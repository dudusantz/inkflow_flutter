# InkFlow — Flutter App

Protótipo completo convertido de React/Figma para **Flutter + Dart**, pronto para rodar no VSCode.

---

## 🚀 Como Rodar

### Pré-requisitos
- Flutter SDK `>=3.0.0` instalado ([flutter.dev](https://flutter.dev/docs/get-started/install))
- Dart `>=3.0.0`
- VSCode com extensão **Flutter** e **Dart**

### Passos

```bash
# 1. Entre na pasta do projeto
cd inkflow_flutter

# 2. Instale as dependências
flutter pub get

# 3. Rode o app (emulador ou dispositivo físico)
flutter run
```

Para rodar no **Chrome** (web):
```bash
flutter run -d chrome
```

---

## 📁 Estrutura de Pastas

```
lib/
├── main.dart                  # Entrada do app
├── router.dart                # Configuração de rotas (go_router)
├── theme/
│   └── app_theme.dart         # Cores e tema global InkFlow
├── widgets/
│   └── shared_widgets.dart    # Widgets reutilizáveis (ScenarioSwitcher, BottomNav, etc.)
└── screens/
    ├── splash_screen.dart      # Login (tela inicial)
    ├── register_screen.dart    # RF01 — Cadastro de Conta
    ├── home_screen.dart        # RF08 — Agenda do Dia / Home
    ├── search_screen.dart      # RF03 — Buscar Tatuadores
    ├── chat_screen.dart        # RF04/RF05 — Chat + Propostas
    ├── schedule_screen.dart    # RF06/RF08 — Agenda completa
    ├── anamnesis_screen.dart   # RF07 — Ficha de Anamnese
    ├── reminders_screen.dart   # RF09 — Lembretes LGPD
    ├── dashboard_screen.dart   # RF10 — Dashboard Financeiro
    └── profile_setup_screen.dart # RF02 — Perfil do Tatuador
assets/
└── inkflow_logo.png
```

---

## 📋 Requisitos Funcionais

Documentação completa (cenários BDD RF01–RF10): **[Docs/requisitos-funcionais.md](Docs/requisitos-funcionais.md)**

## 🎨 Telas e Requisitos Funcionais (resumo)

| Tela | RF | Cenários |
|---|---|---|
| Login | — | — |
| Cadastro | RF01 | ✓ Positivo · ✗ Menor de Idade · ⚠ E-mail/CPF duplicado |
| Perfil Tatuador | RF02 | ✓ Ativação · ✗ Portfólio incompleto |
| Busca | RF03 | ✓ Com resultados · ✗ Sem filtros |
| Chat | RF04 | ✓ Proposta válida · ✗ Data passada |
| Aceite Proposta | RF05 | ✓ Aceite · ✗ Race condition |
| Agenda Manual | RF06 | ✓ Horário livre · ✗ Conflito |
| Anamnese | RF07 | ✓ OK · ✗ Sem aceite · ⚠ Condição de risco |
| Agenda Diária | RF08 | ✓ Sessões · ✗ Erro rede · ⚠ Dia livre |
| Lembretes | RF09 | ✓ Enviados · ✗ Sem contato · ⚠ Cancelamento manual |
| Dashboard | RF10 | ✓ Com dados · ✗ Período inválido |

---

## 🔧 Bugs Corrigidos vs. Protótipo Original

- **ScenarioSwitcher** desconectado das telas → integrado em todas as telas
- **Navegação quebrada** entre telas → go_router com rotas tipadas
- **Formulários sem validação** → validação real com feedback visual
- **Datas passadas não bloqueadas** no chat → validação `isPastDate` implementada
- **Botões sem estado** → todos os botões têm estados: loading, disabled, error
- **Menor de idade** não bloqueava o cadastro → lógica de cálculo de idade real
- **Portfólio** sem mínimo de fotos → validação de mínimo 3 fotos
- **Aceite de Termos** obrigatório na Anamnese → bloqueio de envio sem aceite
- **LGPD** nos lembretes não verificada → campo `consent` verificado antes de envio

---

## 📦 Dependências

| Pacote | Uso |
|---|---|
| `go_router` | Navegação declarativa entre telas |
| `fl_chart` | Gráfico de barras no Dashboard |
| `google_fonts` | Fonte Inter em todo o app |
| `intl` | Formatação de datas em pt_BR |
| `cached_network_image` | Cache de imagens da rede |
| `flutter_localizations` | Localização pt_BR (DatePicker, etc.) |
