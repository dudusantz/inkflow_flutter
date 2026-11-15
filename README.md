# InkFlow

Aplicativo Flutter para clientes e tatuadores. O cliente encontra profissionais,
conversa pelo chat e responde a propostas. Ao aceitar, preenche e assina a ficha
de anamnese. A confirmação inclui a sessão na agenda dos dois participantes.

Na área profissional, o tatuador configura o portfólio, acompanha a agenda e
gerencia recebimentos, despesas, recibos, relatórios e a DRE gerencial.

## Executar localmente

Tenha o Flutter instalado e acesso ao projeto Supabase do InkFlow. Para testar
no Android, configure também o SDK Android e confira o ambiente com
`flutter doctor`.

Na raiz do repositório, execute no PowerShell:

```powershell
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
flutter pub get
flutter devices
```

Preencha `SUPABASE_URL` e
`SUPABASE_ANON_KEY` com a URL e a chave pública do mesmo projeto Supabase
usado pela equipe. O Flutter empacota esse arquivo. Use apenas configurações
públicas nele.

**Android:** ative a depuração USB, conecte o celular e aceite a autorização
no aparelho. Use o identificador retornado por `flutter devices`.

```powershell
flutter run -d ID_DO_CELULAR
```

Com o aplicativo aberto, pressione `r` para recarregar, `R` para reiniciar
ou `d` para encerrar a sessão de debug e deixar o app instalado no celular.

**Web no Windows:** rode `flutter run -d edge`. Login, chat e fotos precisam
de acesso ao Supabase.

### Backend

O Supabase fornece autenticação, Postgres com políticas de acesso, Realtime
e Storage. Para desenvolver com o banco da equipe, use o projeto já configurado.
Ao provisionar outro ambiente, prepare o esquema-base do InkFlow antes de aplicar
as [migrations](supabase/migrations) em ordem numérica. Os primeiros scripts
alteram tabelas preexistentes, como `public.profiles`.

O envio de push tem configuração própria no servidor e usa a Edge Function
[`process-push`](supabase/functions/process-push). Veja o [DER](Docs/DER.md)
e o [índice da documentação](Docs/README.md).

## Onde está o código

| Área | Pasta |
| --- | --- |
| Cadastro, login e recuperação de senha | [`lib/features/auth`](lib/features/auth) |
| Conta profissional e portfólio | [`lib/features/profile`](lib/features/profile) |
| Busca e perfis públicos | [`lib/features/search`](lib/features/search) |
| Conversas e propostas | [`lib/features/chat`](lib/features/chat) |
| Agenda, anamnese e lembretes | [`lib/features/schedule`](lib/features/schedule) |
| Gestão do estúdio, recibos, relatórios e DRE | [`lib/features/finance`](lib/features/finance) |
| Indicadores financeiros | [`lib/features/dashboard`](lib/features/dashboard) |
| Rotas e controle de acesso | [`lib/router.dart`](lib/router.dart) |

## Verificações

```powershell
flutter analyze
flutter test
```
