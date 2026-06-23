# Rota de Preview Temporária — ArtistHomeScreen

Este documento registra a alteração realizada para possibilitar a visualização direta da tela `ArtistHomeScreen` (`artist_home_screen.dart`).

## Lógica e Implementação

### Antes da Alteração:
O aplicativo inicializava na rota `/` (`SplashScreen`) e qualquer tentativa de acessar outras rotas sem uma sessão de login ativa no Supabase redirecionava o usuário de volta para `/`.

### Atualização Realizada:
1. Adicionada a importação de `screens/artist_home_screen.dart` no `lib/router.dart`.
2. Configurado o `initialLocation: '/artist-home'` no `GoRouter`.
3. Adicionado o bypass `isGoingToPreview` no método `redirect` para que a rota `/artist-home` seja renderizada mesmo sem autenticação ativa.
4. Adicionada a definição da rota `GoRoute(path: '/artist-home', ...)` retornando a `ArtistHomeScreen()`.

---

## Captura de Telas do Aplicativo

Foi gerado um conjunto completo de screenshots de todas as telas em formato mobile (375x812), salvo na pasta `/telas`:

1. `01_splash.png` — Tela de login e abertura
2. `02_register.png` — Tela de cadastro
3. `03_client_home.png` — Home do cliente (estúdios em alta, próxima sessão)
4. `04_artist_home.png` — Home do tatuador (agenda, faturamento e anamneses)
5. `05_search.png` — Tela de busca e filtros
6. `06_inbox.png` — Caixa de entrada/mensagens
7. `07_chat.png` — Tela de chat e envio de proposta
8. `08_schedule.png` — Agenda do tatuador
9. `09_anamnesis.png` — Ficha de anamnese do cliente
10. `10_reminders.png` — Configuração de lembretes LGPD
11. `11_dashboard.png` — Gráficos e faturamento do tatuador
12. `12_profile.png` — Tela de perfil
13. `13_profile_setup.png` — Onboarding / Configuração de perfil
14. `14_care.png` — Cuidados pós-tatuagem (Care)
15. `15_favorites.png` — Tatuadores e estúdios favoritos

---

## Check List

- [x] Importar `ArtistHomeScreen` no arquivo de rotas.
- [x] Adicionar rota de desvio `/artist-home` livre de autenticação.
- [x] Configurar localização inicial do app para `/artist-home`.
- [x] Iniciar o app em modo de desenvolvimento local para visualização do usuário.
- [x] Gerar screenshots de todas as 15 telas do aplicativo na pasta `/telas`.
- [x] Reverter as rotas temporárias mantendo a validação de sessão ativa para segurança do app.
