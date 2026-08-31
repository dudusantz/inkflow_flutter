-- Anexos privados de imagem, vídeo e áudio no chat.

ALTER TABLE public.messages
  ALTER COLUMN content DROP NOT NULL,
  ADD COLUMN IF NOT EXISTS attachment_path text,
  ADD COLUMN IF NOT EXISTS attachment_type text,
  ADD COLUMN IF NOT EXISTS attachment_name text,
  ADD COLUMN IF NOT EXISTS duration_seconds integer;

ALTER TABLE public.messages
  DROP CONSTRAINT IF EXISTS messages_content_or_attachment;
ALTER TABLE public.messages
  ADD CONSTRAINT messages_content_or_attachment CHECK (
    NULLIF(btrim(content), '') IS NOT NULL
    OR attachment_path IS NOT NULL
  );

ALTER TABLE public.messages
  DROP CONSTRAINT IF EXISTS messages_attachment_type_valid;
ALTER TABLE public.messages
  ADD CONSTRAINT messages_attachment_type_valid CHECK (
    attachment_type IS NULL OR attachment_type IN ('image', 'video', 'audio')
  );

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'chat-media',
  'chat-media',
  false,
  52428800,
  ARRAY[
    'image/jpeg', 'image/png', 'image/webp', 'image/gif',
    'video/mp4', 'video/quicktime',
    'audio/mp4', 'audio/m4a', 'audio/aac'
  ]
)
ON CONFLICT (id) DO UPDATE SET
  public = false,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "chat_media_upload_own" ON storage.objects;
CREATE POLICY "chat_media_upload_own"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'chat-media'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

DROP POLICY IF EXISTS "chat_media_read_participants" ON storage.objects;
CREATE POLICY "chat_media_read_participants"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'chat-media'
  AND EXISTS (
    SELECT 1 FROM public.messages m
    WHERE m.attachment_path = name
      AND (m.sender_id = auth.uid() OR m.receiver_id = auth.uid())
  )
);

DROP POLICY IF EXISTS "chat_media_delete_own" ON storage.objects;
CREATE POLICY "chat_media_delete_own"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'chat-media'
  AND auth.uid()::text = (storage.foldername(name))[1]
);
