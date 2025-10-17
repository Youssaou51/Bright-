import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.5";

// Crée le client Supabase
const supabase = createClient(
  Deno.env.get("MY_SUPABASE_URL")!,
  Deno.env.get("MY_SUPABASE_SERVICE_ROLE_KEY")!
);

serve(async (req) => {
  try {
    const payload = await req.json();
    const table = payload.table;
    const record = payload.record;

    let title = "";
    let body = "";

    if (table === "posts") {
      title = "📰 Nouveau post sur Bright Future";
      body = record.content || "Quelqu’un a publié un nouveau post.";
    } else if (table === "comments") {
      title = "💬 Nouveau commentaire";
      body = record.content || "Quelqu’un a commenté une publication.";
    }

    // Récupère tous les utilisateurs sauf l'auteur
    const { data: users } = await supabase
      .from("profiles")
      .select("fcm_token")
      .neq("id", record.user_id);

    const tokens = users?.map((u) => u.fcm_token).filter(Boolean);

    if (!tokens || tokens.length === 0) {
      console.log("No tokens found.");
      return new Response("No tokens found", { status: 200 });
    }

    const fcmKey = Deno.env.get("FIREBASE_SERVER_KEY");

    // Envoie les notifications via l'API FCM HTTP
    const notifications = tokens.map((token) =>
      fetch("https://fcm.googleapis.com/fcm/send", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `key=${fcmKey}`,
        },
        body: JSON.stringify({
          to: token,
          notification: { title, body },
          data: { type: table, id: String(record.id) },
        }),
      })
    );

    await Promise.all(notifications);

    console.log(`✅ Notifications envoyées: ${tokens.length}`);
    return new Response("ok", { status: 200 });

  } catch (error) {
    console.error("❌ Erreur:", error);
    return new Response("Erreur serveur", { status: 500 });
  }
});
