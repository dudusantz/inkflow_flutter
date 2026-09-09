# Diagrama Entidade–Relacionamento — InkFlow

Esta DER representa o schema atualmente versionado nas migrations do Supabase. As views `artist_directory` e `chat_directory` são projeções de leitura e não armazenam dados próprios.

```mermaid
erDiagram
    AUTH_USERS ||--|| PROFILES : "possui"
    AUTH_USERS ||--o{ MESSAGES : "envia"
    AUTH_USERS ||--o{ MESSAGES : "recebe"
    AUTH_USERS ||--o{ APPOINTMENTS : "atua como tatuador"
    AUTH_USERS o|--o{ APPOINTMENTS : "participa como cliente"
    MESSAGES o|--o| STORAGE_OBJECTS : "referencia anexo"
    PROFILES ||--o{ STORAGE_OBJECTS : "publica portfolio"

    AUTH_USERS {
        uuid id PK
        text email UK
        jsonb raw_user_meta_data
        timestamptz created_at
    }

    PROFILES {
        uuid id PK,FK
        text name
        text role
        text phone
        text cpf UK
        date date_of_birth
        text guardian_cpf
        text avatar_url
        text_array styles
        text city
        text state
        numeric rating
        numeric min_price
        numeric hourly_rate
        text_array portfolio_urls
        text portfolio_url
    }

    MESSAGES {
        uuid id PK
        uuid sender_id FK
        uuid receiver_id FK
        text conversation_key "gerada"
        text content "opcional com anexo"
        text attachment_path
        text attachment_type
        text attachment_name
        int duration_seconds
        timestamptz created_at
    }

    APPOINTMENTS {
        uuid id PK
        uuid artist_id FK
        uuid client_id FK "opcional"
        text client_name
        date date
        time time
        time end_time
        text style
        numeric price
        text status
        text anamnesis_status
        boolean reminder_enabled
        timestamptz created_at
    }

    STORAGE_OBJECTS {
        uuid id PK
        text bucket_id FK
        text name "caminho do arquivo"
        text metadata
        timestamptz created_at
    }
```

## Cardinalidades principais

- Cada usuário autenticado possui exatamente um perfil em `profiles`.
- Um usuário pode enviar e receber várias mensagens; cada mensagem possui um remetente e um destinatário.
- Um tatuador pode ter vários agendamentos. Um cliente também pode participar de vários agendamentos, mas `client_id` pode ser nulo para registros legados ou clientes ainda não vinculados.
- Uma mensagem pode não possuir anexo ou referenciar um objeto do bucket privado `chat-media` por `attachment_path`.
- Um perfil pode publicar várias imagens no bucket público `portfolio`; as URLs são mantidas em `portfolio_urls`.

## Views de leitura

- `artist_directory`: expõe somente os dados públicos de perfis com `role = 'ARTIST'`.
- `chat_directory`: expõe `id`, nome e avatar apenas de usuários que já possuem histórico de conversa com o usuário autenticado.

## Regras relevantes do banco

- `messages.conversation_key` é gerada pela ordenação dos IDs dos dois participantes.
- `appointments_no_overlap` impede horários sobrepostos para o mesmo tatuador e data.
- `appointments_time_order` exige que `end_time` seja posterior a `time`.
- `messages_content_or_attachment` exige texto preenchido ou anexo.
- `messages_attachment_type_valid` aceita apenas `image`, `video` ou `audio`.
- RLS restringe perfis, mensagens, agendamentos e mídias privadas aos usuários autorizados.

> Observação: as colunas básicas de `profiles` (`id`, `name`, `role`, `phone`, `cpf`, `date_of_birth` e `guardian_cpf`) já existiam antes das migrations versionadas atuais. Elas foram confirmadas pelo trigger, pelas policies e pelos modelos do aplicativo.
