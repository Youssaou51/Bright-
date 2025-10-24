import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.5";

// Initialize Supabase client with service role credentials
const supabase = createClient(
  Deno.env.get("MY_SUPABASE_URL")!,
  Deno.env.get("MY_SUPABASE_SERVICE_ROLE_KEY")!
);

// Generate OAuth 2.0 access token for FCM v1 API
const getAccessToken = async () => {
  try {
    const now = Math.floor(Date.now() / 1000);
    const jwtHeader = { alg: "RS256", typ: "JWT" };
    const jwtClaim = {
      iss: Deno.env.get("FIREBASE_CLIENT_EMAIL"),
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    };

    const encoder = new TextEncoder();
    const header = btoa(JSON.stringify(jwtHeader));
    const payload = btoa(JSON.stringify(jwtClaim));
    const unsigned = `${header}.${payload}`;

    const privateKey = Deno.env.get("FIREBASE_PRIVATE_KEY")!.replace(/\\n/g, "\n");
    const key = await crypto.subtle.importKey(
      "pkcs8",
      encoder.encode(privateKey),
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["sign"]
    );

    const signatureBuffer = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, encoder.encode(unsigned));
    const signature = btoa(String.fromCharCode(...new Uint8Array(signatureBuffer)));

    const jwt = `${unsigned}.${signature}`;

    const res = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }),
    });

    if (!res.ok) {
      const text = await res.text();
      console.error("OAuth error:", text);
      throw new Error(`Failed to get access token: ${res.status} - ${text}`);
    }

    const data = await res.json();
    return data.access_token;
  } catch (err) {
    console.error("getAccessToken error:", err);
    throw err;
  }
};

// Serve HTTP requests
serve(async (_req) => {
  try {
    // Subscribe to PostgreSQL Realtime changes
    const subscription = supabase
      .channel("notifications")
      .on("postgres_changes", { event: "*", schema: "public" }, async (payload: any) => {
        try {
          // Fix: Use payload.new directly (no JSON.parse)
          const { table, record } = payload.new;
          console.log("Received payload:", { table, record });

          let title = "";
          let body = "";

          // Define notification content based on table
          if (table === "posts") {
            title = "🆕 Nouveau post";
            body = `${record.username}: ${record.caption ?? ""}`;
          } else if (table === "comments") {
            title = "💬 Nouveau commentaire";
            body = `${record.content} (sur post ${record.post_id})`;
          } else if (table === "reports") {
            title = "📄 Nouveau rapport";
            body = `${record.name ?? "Un rapport"} vient d'être ajouté.`;
          } else {
            console.log("No notification triggered for table:", table);
            return;
          }

          // Fetch FCM tokens for users (excluding the record's user)
          const { data: users, error } = await supabase
            .from("users")
            .select("fcm_token")
            .neq("id", record.user_id);

          if (error) {
            console.error("Error fetching tokens:", error);
            return;
          }

          const tokens = users?.map((u: any) => u.fcm_token).filter(Boolean);
          if (!tokens || tokens.length === 0) {
            console.log("No valid FCM tokens found");
            return;
          }

          // Get OAuth access token for FCM
          const accessToken = await getAccessToken();

          // Send notifications to each token
          const fcmUrl = `https://fcm.googleapis.com/v1/projects/${Deno.env.get("FIREBASE_PROJECT_ID")}/messages:send`;
          for (const token of tokens) {
            const res = await fetch(fcmUrl, {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${accessToken}`,
              },
              body: JSON.stringify({
                message: {
                  token,
                  notification: { title, body, sound: "default" },
                  data: { type: table, recordId: record.id },
                },
              }),
            });

            const text = await res.text();
            console.log(`FCM response for token ${token}:`, text);
            if (!res.ok) {
              console.error(`FCM error for token ${token}:`, text);
              continue; // Skip failed tokens
            }
            const json = JSON.parse(text);
            console.log(`FCM parsed response for token ${token}:`, json);
          }
        } catch (err) {
          console.error("Error in subscription callback:", err);
        }
      })
      .subscribe();

    return new Response(JSON.stringify({ status: "Listening for notifications..." }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("❌ Error:", err);
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});