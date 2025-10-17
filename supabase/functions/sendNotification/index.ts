import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.5";

const supabase = createClient(
  Deno.env.get("MY_SUPABASE_URL")!,
  Deno.env.get("MY_SUPABASE_SERVICE_ROLE_KEY")!
);

serve(async (req) => {
  try {
    const { table, record } = await req.json();

    let title = "";
    let body = "";

    if (table === "posts") {
      title = "🆕 Nouveau post";
      body = `${record.title} par ${record.user_name}`;
    } else if (table === "comments") {
      title = "💬 Nouveau commentaire";
      body = `${record.content} (sur post ${record.post_id})`;
    } else if (table === "reports") {
      title = "📄 Nouveau rapport";
      body = `${record.name} vient d'être ajouté.`;
    } else {
      return new Response("No notification triggered", { status: 200 });
    }

    // 🔥 Récupérer les tokens de tous les autres utilisateurs
    const { data: users, error } = await supabase
      .from("users")
      .select("fcm_token")
      .neq("id", record.user_id);

    if (error) throw error;

    const tokens = users?.map((u: any) => u.fcm_token).filter(Boolean);

    if (!tokens || tokens.length === 0) {
      return new Response("No tokens found", { status: 200 });
    }

    // 🚀 Envoi via Firebase Cloud Messaging (FCM)
    const res = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `key=${Deno.env.get("FCM_SERVER_KEY")}`,
      },
      body: JSON.stringify({
        registration_ids: tokens,
        notification: {
          title,
          body,
          sound: "default",
        },
        data: {
          type: table,
          recordId: record.id,
        },
      }),
    });

    const json = await res.json();
    return new Response(JSON.stringify(json), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("❌ Error:", err);
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});
