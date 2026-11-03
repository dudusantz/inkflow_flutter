import { createClient } from "npm:@supabase/supabase-js@2";
import webpush from "npm:web-push@3.6.7";

type PushNotification = {
  id: string;
  user_id: string;
  title: string;
  body: string;
  route: string;
  attempts: number;
};

Deno.serve(async (request) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  };
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  const publicKey = Deno.env.get("WEB_PUSH_VAPID_PUBLIC_KEY") ?? "";
  if (request.method === "GET") {
    return Response.json({ publicKey }, { headers: corsHeaders });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const secret = request.headers.get("x-cron-secret") ?? "";
  const { data: authorized, error: authError } = await supabase.rpc(
    "verify_push_cron_secret",
    { p_secret: secret },
  );
  if (authError || !authorized) return new Response("Unauthorized", { status: 401 });

  const privateKey = Deno.env.get("WEB_PUSH_VAPID_PRIVATE_KEY") ?? "";
  const subject = Deno.env.get("WEB_PUSH_VAPID_SUBJECT") ??
    "mailto:inkflow.apps@gmail.com";
  if (!publicKey || !privateKey) {
    return new Response("Web Push is not configured", { status: 503 });
  }
  webpush.setVapidDetails(subject, publicKey, privateKey);

  await supabase.rpc("enqueue_due_appointment_reminders");
  const { data, error } = await supabase
    .from("push_notifications")
    .select("id, user_id, title, body, route, attempts")
    .in("status", ["pending", "retry"])
    .lte("next_attempt_at", new Date().toISOString())
    .order("created_at")
    .limit(100);
  if (error) throw error;

  const notifications = (data ?? []) as PushNotification[];
  if (notifications.length === 0) {
    return Response.json({ processed: 0, sent: 0, failed: 0 });
  }

  let sent = 0;
  let failed = 0;

  for (const notification of notifications) {
    const { data: subscriptions } = await supabase
      .from("push_subscriptions")
      .select("endpoint, p256dh, auth_key")
      .eq("user_id", notification.user_id);
    const devices = subscriptions ?? [];
    let delivered = false;
    let lastError = devices.length === 0 ? "Nenhum dispositivo registrado" : "";

    for (const device of devices) {
      try {
        await webpush.sendNotification(
          {
            endpoint: device.endpoint,
            keys: { p256dh: device.p256dh, auth: device.auth_key },
          },
          JSON.stringify({
            title: notification.title,
            body: notification.body,
            route: notification.route,
          }),
        );
        delivered = true;
      } catch (error) {
        const pushError = error as { statusCode?: number; message?: string };
        lastError = (pushError.message ?? String(error)).slice(0, 1000);
        if (pushError.statusCode === 404 || pushError.statusCode === 410) {
          await supabase.from("push_subscriptions").delete()
            .eq("endpoint", device.endpoint);
        }
      }
    }

    const attempts = notification.attempts + 1;
    if (delivered) {
      sent++;
      await supabase.from("push_notifications").update({
        status: "sent",
        attempts,
        sent_at: new Date().toISOString(),
        last_error: null,
      }).eq("id", notification.id);
    } else {
      failed++;
      const finalFailure = attempts >= 5 || devices.length === 0;
      await supabase.from("push_notifications").update({
        status: finalFailure ? "failed" : "retry",
        attempts,
        last_error: lastError,
        next_attempt_at: new Date(Date.now() + attempts * 60_000).toISOString(),
      }).eq("id", notification.id);
    }
  }

  return Response.json(
    { processed: notifications.length, sent, failed },
    { headers: corsHeaders },
  );
});
