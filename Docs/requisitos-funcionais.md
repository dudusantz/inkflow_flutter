# Requisitos Funcionais — InkFlow

Documento de referência para produto, QA e desenvolvimento. Cada RF descreve cenários no formato **Dado / Quando / Então**.

**Legenda de implementação (app Flutter):**

| Símbolo | Significado |
|---------|-------------|
| ✅ | Implementado na UI e/ou backend |
| ⚠️ | Parcial (mock, sem persistência ou automação server-side) |
| ❌ | Não implementado |

---

## RF01 — Cadastro de Conta de Usuário

**Tela:** `register_screen.dart` · **Backend:** Supabase Auth + tabela `profiles`

### Cenário positivo — Cadastro realizado com sucesso

| | |
|---|---|
| **Dado** | O visitante está na tela de cadastro de usuário |
| **Quando** | Ele preencher todos os campos obrigatórios com dados válidos, for maior de 18 anos e marcar o aceite dos termos |
| **Então** | O sistema deve criar a conta, autenticar o usuário e redirecioná-lo para a tela inicial |

**Status:** ✅ — `AuthRepository.signUp`, redirect para `/home` quando há sessão ativa; SnackBar + `/` se exigir confirmação de e-mail.

### Cenário negativo — Bloqueio por menoridade sem responsável legal

| | |
|---|---|
| **Dado** | O visitante está na tela de cadastro de usuário |
| **Quando** | Ele preencher a data de nascimento resultando em idade menor que 18 anos |
| **Então** | O sistema deve bloquear o botão de envio e exibir aviso exigindo o CPF de um responsável legal |

**Status:** ✅ — Campo "CPF do Responsável Legal", botão "Criar Conta" desabilitado até CPF válido.

### Cenário alternativo — E-mail ou CPF já existente

| | |
|---|---|
| **Dado** | O visitante está na tela de cadastro de usuário |
| **Quando** | Ele inserir um e-mail ou CPF que já consta no banco de dados |
| **Então** | O sistema deve impedir o cadastro e sugerir redirecionamento para "Recuperação de Senha" |

**Status:** ✅ — `DuplicateRegistrationException`, borda vermelha no campo, link "Ir para Recuperação de Senha"; login com `resetPasswordForEmail` em `splash_screen.dart`.

---

## RF02 — Configuração de Perfil Profissional (Onboarding)

**Tela:** `profile_setup_screen.dart` · **Rota:** `/profile-setup`

### Cenário positivo — Perfil profissional ativado com sucesso

| | |
|---|---|
| **Dado** | O usuário está na tela de configuração de perfil profissional |
| **Quando** | Ele adicionar pelo menos um estilo, preencher a tabela de preços base e enviar no mínimo 3 fotos ao portfólio |
| **Então** | O sistema deve alterar o status para "Tatuador" e torná-lo visível nas buscas públicas |

**Status:** ⚠️ — Atualiza `profiles.role = ARTIST`, estilos e preços via Supabase; upload opcional ao bucket `portfolio`. Visível em `search_screen` (`role = ARTIST`).

### Cenário negativo — Portfólio incompleto

| | |
|---|---|
| **Dado** | O usuário está na tela de configuração de perfil profissional |
| **Quando** | Ele preencher estilos e preços, mas não fizer upload de imagens de portfólio |
| **Então** | O sistema deve desabilitar o botão de ativação e exibir: *"É necessário enviar pelo menos 3 imagens para ativar seu portfólio"* |

**Status:** ✅ — Botão "Ativar Perfil" desabilitado; mensagem de rodapé com contador `(n/3)`.

---

## RF03 — Motor de Busca e Filtros

**Tela:** `search_screen.dart` · **Rota:** `/search`

### Cenário positivo — Busca com resultados precisos

| | |
|---|---|
| **Dado** | O cliente está na tela de busca |
| **Quando** | Ele aplicar filtros de estilo e localização válidos e clicar em buscar |
| **Então** | O sistema deve exibir tatuadores correspondentes, ordenados por relevância |

**Status:** ⚠️ — Filtros por estilo, estado, cidade e nome; ordenação por `rating` decrescente. Relevância completa depende de dados enriquecidos no `profiles`.

### Cenário negativo — Busca bloqueada por falta de parâmetros

| | |
|---|---|
| **Dado** | O cliente está na tela de busca |
| **Quando** | Ele tentar buscar sem filtro ou termo de pesquisa |
| **Então** | O sistema deve bloquear a ação e exibir: *"Por favor, selecione ao menos um estilo ou localização para buscar"* |

**Status:** ✅ — Botão "Buscar Tatuadores" + SnackBar com mensagem exata.

---

## RF04 — Chat Interno e Envio de Proposta

**Tela:** `chat_screen.dart` · **Rota:** `/chat`

### Cenário positivo — Envio de proposta de agendamento

| | |
|---|---|
| **Dado** | O tatuador está no chat com um cliente |
| **Quando** | Ele preencher valor, data e horário futuros e confirmar o envio |
| **Então** | O sistema deve enviar card interativo com "Aceitar" e "Recusar" |

**Status:** ⚠️ — Card de proposta na UI; envio ainda em memória local (sem Supabase Realtime).

### Cenário negativo — Proposta com horário no passado

| | |
|---|---|
| **Dado** | O tatuador está preenchendo a proposta |
| **Quando** | Ele selecionar data ou horário que já passou |
| **Então** | O sistema deve desabilitar o envio e exibir: *"A data do agendamento não pode ser no passado"* |

**Status:** ✅ — Botão desabilitado + mensagem de erro abaixo do formulário.

---

## RF05 — Aceite de Proposta e Agendamento Automático

**Tela:** `chat_screen.dart` (visão cliente)

### Cenário positivo — Aceite sem conflito de horário

| | |
|---|---|
| **Dado** | O cliente recebeu uma proposta no chat |
| **Quando** | Ele clicar em "Aceitar" e o horário estiver livre |
| **Então** | O sistema deve confirmar o agendamento, reservar o horário na agenda e notificar ambas as partes |

**Status:** ⚠️ — Status "PROPOSTA ACEITA" na UI; reserva de agenda e notificações ainda simuladas.

### Cenário negativo — Concorrência de horário (race condition)

| | |
|---|---|
| **Dado** | O cliente visualiza proposta pendente |
| **Quando** | Ele clicar em "Aceitar", mas o horário já foi preenchido |
| **Então** | O sistema deve abortar, alertar *"O horário não está mais disponível"* e cancelar a proposta |

**Status:** ⚠️ — Modal + status "CANCELADA / EXPIRADA" para slot simulado `09:00`; falta validação server-side.

---

## RF06 — Agendamento Manual (Bypass)

**Tela:** `schedule_screen.dart` · **Rota:** `/schedule`

### Cenário positivo — Inserção manual com sucesso

| | |
|---|---|
| **Dado** | O tatuador está na agenda |
| **Quando** | Ele usar "Novo Agendamento Manual", preencher dados e salvar em horário livre |
| **Então** | O sistema deve registrar a sessão e bloquear o horário para novas propostas |

**Status:** ⚠️ — FAB + formulário; persistência local em memória.

### Cenário negativo — Conflito com agendamento existente

| | |
|---|---|
| **Dado** | O tatuador cria agendamento manual |
| **Quando** | O intervalo se sobrepõe a sessão confirmada |
| **Então** | O sistema deve bloquear e alertar: *"Existe um conflito de horário com uma sessão já agendada"* |

**Status:** ✅ — Validação de sobreposição de intervalos + mensagem exata.

---

## RF07 — Preenchimento de Ficha de Anamnese Digital

**Tela:** `anamnesis_screen.dart` · **Rota:** `/anamnesis`

### Cenário positivo — Preenchimento e assinatura corretos

| | |
|---|---|
| **Dado** | O cliente acessou a ficha de anamnese |
| **Quando** | Ele preencher campos obrigatórios, aceitar termos e clicar em "Enviar" |
| **Então** | O sistema deve registrar a assinatura digital e liberar visualização para o tatuador |

**Status:** ⚠️ — Fluxo UI + tela de sucesso; persistência/criptografia no backend pendente.

### Cenário negativo — Envio bloqueado por falta de aceite legal

| | |
|---|---|
| **Dado** | O cliente preencheu os campos de saúde |
| **Quando** | Ele tentar enviar sem marcar o checkbox de declaração |
| **Então** | O sistema deve impedir o envio, destacar o checkbox em vermelho e exibir erro |

**Status:** ✅ — Borda/fundo vermelho no checkbox + mensagem de validação.

### Cenário alternativo — Condição médica de risco

| | |
|---|---|
| **Dado** | O cliente preenche a anamnese |
| **Quando** | Ele marcar "Sim" para condições críticas (anticoagulantes, gravidez, etc.) |
| **Então** | O sistema processa o envio, mas gera alerta visual (flag vermelha) no painel do tatuador |

**Status:** ✅ — Tela de alerta médico pós-envio; badge "Condição de Risco" em `artist_home_screen.dart`.

---

## RF08 — Visualização da Agenda Diária

**Tela:** `artist_home_screen.dart` · **Rota:** `/home` (role `ARTIST`)

### Cenário positivo — Carregamento da agenda do dia

| | |
|---|---|
| **Dado** | O tatuador acessou a tela inicial |
| **Quando** | O sistema requisitar dados do dia atual (D-0) com sucesso |
| **Então** | Deve exibir lista cronológica com cliente, horário e status da anamnese |

**Status:** ⚠️ — Lista cronológica na UI; dados ainda mock (integração Supabase pendente).

### Cenário negativo — Falha de comunicação

| | |
|---|---|
| **Dado** | O tatuador acessou a tela inicial |
| **Quando** | Houver falha de conexão ou timeout |
| **Então** | Exibir *"Não foi possível carregar sua agenda"* e botão *"Tentar novamente"* |

**Status:** ✅ — Estado de erro + retry em `_fetchAgendaHoje`.

### Cenário alternativo — Dia sem agendamentos

| | |
|---|---|
| **Dado** | O tatuador acessou a tela inicial |
| **Quando** | Não houver sessões para o dia |
| **Então** | Exibir empty state: *"Sua agenda está livre hoje"* |

**Status:** ✅ — `_buildEmpty()` implementado.

---

## RF09 — Automação e Cancelamento de Lembrete

**Telas:** `schedule_screen.dart` (toggle) · `reminders_screen.dart` (painel)

### Cenário positivo — Disparo automático bem-sucedido

| | |
|---|---|
| **Dado** | A rotina de automação está ativa |
| **Quando** | Faltarem 24 horas para sessão confirmada |
| **Então** | Disparar notificação de lembrete padronizada ao cliente |

**Status:** ❌ — Requer job/cron server-side (Edge Function ou worker); UI documenta regra em `reminders_screen`.

### Cenário negativo — Falha por falta de dados do cliente

| | |
|---|---|
| **Dado** | A rotina tentou disparar lembrete |
| **Quando** | Cliente sem conta ou sem meio de contato válido |
| **Então** | Abortar disparo, registrar log e avisar tatuador no painel |

**Status:** ⚠️ — Cenário demonstrado via `ScenarioSwitcher` (sem consentimento LGPD).

### Cenário alternativo — Cancelamento manual pelo tatuador

| | |
|---|---|
| **Dado** | Faltam mais de 24 h para a sessão |
| **Quando** | Tatuador cancelar lembrete nos detalhes do agendamento |
| **Então** | Remover tarefa da fila e não disparar mensagem |

**Status:** ⚠️ — Toggle "Enviar lembrete automático de 24h" no bottom sheet da agenda; fila real pendente.

---

## RF10 — Dashboard de Métricas e Faturamento

**Tela:** `dashboard_screen.dart` · **Rota:** `/dashboard`

### Cenário positivo — Relatórios com dados consistentes

| | |
|---|---|
| **Dado** | O tatuador acessou o Dashboard |
| **Quando** | Selecionar período com sessões concluídas |
| **Então** | Renderizar gráficos de faturamento e ticket médio corretamente |

**Status:** ⚠️ — KPIs + gráfico de barras com dados mock; filtro por chips e intervalo personalizado.

### Cenário negativo — Intervalo de datas inválido

| | |
|---|---|
| **Dado** | O tatuador configura filtro do Dashboard |
| **Quando** | Data inicial for maior que data final |
| **Então** | Bloquear pesquisa e exibir: *"O período selecionado é inválido"* |

**Status:** ✅ — Validação em `_isPeriodInvalid` + alerta vermelho.

---

## Mapa tela ↔ RF

| RF | Tela(s) | Arquivo(s) |
|----|---------|------------|
| RF01 | Cadastro | `register_screen.dart`, `auth_repository.dart` |
| RF02 | Perfil profissional | `profile_setup_screen.dart` |
| RF03 | Busca | `search_screen.dart` |
| RF04 | Chat / proposta | `chat_screen.dart` |
| RF05 | Aceite proposta | `chat_screen.dart` |
| RF06 | Agenda manual | `schedule_screen.dart` |
| RF07 | Anamnese | `anamnesis_screen.dart` |
| RF08 | Home tatuador | `artist_home_screen.dart`, `home_screen.dart` |
| RF09 | Lembretes | `reminders_screen.dart`, `schedule_screen.dart` |
| RF10 | Dashboard | `dashboard_screen.dart` |

---

## Backlog técnico (fora do escopo UI)

1. Persistência de chat, propostas e agendamentos no Supabase  
2. Edge Function para lembretes 24 h (RF09)  
3. Bucket `portfolio` + RLS para RF02  
4. API criptografada de anamnese (RF07 / LGPD)  
5. Validação de race condition server-side (RF05)

*Última atualização: jun/2026*
