import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.5";
import { encodeBase64Url } from "https://deno.land/std@0.177.0/encoding/base64url.ts";

console.log("🔧 Starting notification service with JWT library...");

// Configuration
const supabaseUrl = Deno.env.get("MY_SUPABASE_URL");
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const firebaseClientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL");
const firebasePrivateKey = Deno.env.get("FIREBASE_PRIVATE_KEY");
const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID");

// Validation des variables d'environnement
console.log("🔍 Environment check:", {
  supabase: !!supabaseUrl && !!supabaseKey,
  firebase: {
    clientEmail: !!firebaseClientEmail,
    privateKey: !!firebasePrivateKey,
    projectId: !!firebaseProjectId,
    privateKeyLength: firebasePrivateKey?.length,
  }
});

if (!supabaseUrl || !supabaseKey) {
  throw new Error("❌ Missing Supabase configuration");
}

if (!firebaseClientEmail || !firebasePrivateKey || !firebaseProjectId) {
  throw new Error("❌ Missing Firebase configuration");
}

const supabase = createClient(supabaseUrl, supabaseKey);

// Fonction simple pour encoder en base64 URL-safe
function base64urlEncode(str: string): string {
  return btoa(str)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

// Fonction pour signer le JWT en utilisant une approche différente
const getAccessToken = async (): Promise<string> => {
  try {
    console.log("🔑 Generating Firebase access token with simplified approach...");

    // Nettoyer la clé privée
    const privateKey = firebasePrivateKey.replace(/\\n/g, '\n').trim();

    console.log("📝 Private key info:", {
      startsWith: privateKey.substring(0, 30),
      endsWith: privateKey.substring(privateKey.length - 30),
      length: privateKey.length
    });

    const now = Math.floor(Date.now() / 1000);

    // Header JWT
    const header = {
      alg: "RS256",
      typ: "JWT"
    };

    // Payload JWT
    const payload = {
      iss: firebaseClientEmail,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      exp: now + 3600,
      iat: now,
    };

    // Encoder header et payload
    const encodedHeader = base64urlEncode(JSON.stringify(header));
    const encodedPayload = base64urlEncode(JSON.stringify(payload));
    const dataToSign = `${encodedHeader}.${encodedPayload}`;

    console.log("🔐 Attempting to sign JWT...");

    // Essayer une approche différente pour la signature
    let signature: string;

    try {
      // Méthode 1: Utiliser la crypto Web standard
      const textEncoder = new TextEncoder();
      const data = textEncoder.encode(dataToSign);

      // Nettoyer la clé pour l'importation
      const cleanPrivateKey = privateKey
        .replace('-----BEGIN PRIVATE KEY-----', '')
        .replace('-----END PRIVATE KEY-----', '')
        .replace(/\n/g, '')
        .trim();

      const keyData = Uint8Array.from(atob(cleanPrivateKey), c => c.charCodeAt(0));

      const key = await crypto.subtle.importKey(
        "pkcs8",
        keyData,
        {
          name: "RSASSA-PKCS1-v1_5",
          hash: "SHA-256",
        },
        false,
        ["sign"]
      );

      const signatureBuffer = await crypto.subtle.sign(
        "RSASSA-PKCS1-v1_5",
        key,
        data
      );

      signature = base64urlEncode(String.fromCharCode(...new Uint8Array(signatureBuffer)));

    } catch (cryptoError) {
      console.log("⚠️ Standard crypto failed, trying alternative approach...");

      // Méthode 2: Utiliser une bibliothèque externe
      const jwtModule = await import("https://esm.sh/jsonwebtoken@9.0.2");
      const jwt = jwtModule.default;

      // Créer le JWT avec la bibliothèque
      const token = jwt.sign(payload, privateKey, {
        algorithm: 'RS256',
        header: header,
        issuer: firebaseClientEmail,
        audience: "https://oauth2.googleapis.com/token",
        expiresIn: 3600,
        subject: firebaseClientEmail
      });

      // Pour cette méthode, nous allons directement utiliser le JWT généré
      // et faire la requête OAuth
      console.log("📤 Requesting OAuth token with JWT library...");

      const response = await fetch("https://oauth2.googleapis.com/token", {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({
          grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
          assertion: token,
        }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`OAuth failed: ${response.status} - ${errorText}`);
      }

      const tokenData = await response.json();
      console.log("✅ Firebase access token obtained with JWT library");
      return tokenData.access_token;
    }

    // Si la méthode 1 a réussi, continuer avec le JWT manuel
    const jwt = `${dataToSign}.${signature}`;

    console.log("📤 Requesting OAuth token...");

    const response = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`OAuth failed: ${response.status} - ${errorText}`);
    }

    const tokenData = await response.json();
    console.log("✅ Firebase access token obtained");
    return tokenData.access_token;

  } catch (error) {
    console.error("❌ Error getting Firebase access token:", error);

    // Dernière tentative: Utiliser une approche encore plus simple
    console.log("🔄 Trying simple approach...");
    try {
      const simpleToken = await getAccessTokenSimple();
      return simpleToken;
    } catch (simpleError) {
      throw new Error(`All methods failed: ${error.message}, ${simpleError.message}`);
    }
  }
};

// Approche ultra-simplifiée
const getAccessTokenSimple = async (): Promise<string> => {
  try {
    console.log("🔑 Trying simple JWT approach...");

    const privateKey = firebasePrivateKey.replace(/\\n/g, '\n').trim();

    const now = Math.floor(Date.now() / 1000);
    const payload = {
      iss: firebaseClientEmail,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      exp: now + 3600,
      iat: now,
    };

    const header = { alg: "RS256", typ: "JWT" };

    const encodedHeader = base64urlEncode(JSON.stringify(header));
    const encodedPayload = base64urlEncode(JSON.stringify(payload));
    const unsignedToken = `${encodedHeader}.${encodedPayload}`;

    // Utiliser une bibliothèque JWT dédiée
    const { createSign } = await import("https://deno.land/std@0.177.0/node/crypto.ts");

    const sign = createSign('RSA-SHA256');
    sign.update(unsignedToken);
    sign.end();

    const signature = sign.sign(privateKey, 'base64')
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');

    const jwt = `${unsignedToken}.${signature}`;

    const response = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Simple OAuth failed: ${response.status} - ${errorText}`);
    }

    const tokenData = await response.json();
    console.log("✅ Firebase access token obtained with simple method");
    return tokenData.access_token;

  } catch (error) {
    console.error("❌ Simple method also failed:", error);
    throw error;
  }
};

// Fonction pour envoyer les notifications FCM (version simplifiée)
const sendFCMNotification = async (
  token: string,
  title: string,
  body: string,
  data: any
): Promise<boolean> => {
  try {
    console.log(`📤 Sending FCM notification...`);

    // Pour le moment, simuler l'envoi
    console.log(`📨 Would send to: ${token.substring(0, 10)}...`);
    console.log(`📝 Title: ${title}`);
    console.log(`📝 Body: ${body}`);
    console.log(`🔧 Data:`, data);

    // Simuler le succès pour les tests
    await new Promise(resolve => setTimeout(resolve, 100));
    console.log("✅ FCM notification simulated successfully");
    return true;

  } catch (error) {
    console.error("❌ Error sending FCM notification:", error);
    return false;
  }
};

// Handler principal
serve(async (req) => {
  console.log("📨 Received request:", req.method);

  // Gestion CORS
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 200,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
      },
    });
  }

  try {
    const body = await req.json();
    console.log("📦 Request body:", JSON.stringify(body, null, 2));

    // Mode test pour vérifier Firebase
    if (body.action === "test_firebase") {
      try {
        console.log("🧪 Testing Firebase authentication...");
        const token = await getAccessToken();
        return new Response(
          JSON.stringify({
            status: "success",
            message: "Firebase authentication working!",
            hasToken: !!token,
            tokenPreview: token ? token.substring(0, 20) + "..." : null
          }),
          {
            status: 200,
            headers: {
              "Content-Type": "application/json",
              "Access-Control-Allow-Origin": "*",
            }
          }
        );
      } catch (error) {
        console.error("❌ Firebase test failed:", error);
        return new Response(
          JSON.stringify({
            status: "error",
            message: "Firebase authentication failed",
            error: error.message,
            suggestion: "Check Firebase private key format and permissions"
          }),
          {
            status: 500,
            headers: {
              "Content-Type": "application/json",
              "Access-Control-Allow-Origin": "*",
            }
          }
        );
      }
    }

    // Logique de notification normale (simulée pour le moment)
    const { record, table, type = "insert" } = body;

    if (!record || !table) {
      return new Response(
        JSON.stringify({ error: "Missing record or table" }),
        {
          status: 400,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          }
        }
      );
    }

    console.log(`🔄 Processing ${type} on table: ${table}`);

    // Simuler l'envoi de notification
    return new Response(
      JSON.stringify({
        status: "success",
        message: "Notification processed successfully (FCM simulated)",
        table: table,
        recordId: record.id,
        note: "Firebase FCM is currently in simulation mode"
      }),
      {
        status: 200,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      }
    );

  } catch (error) {
    console.error("❌ Unhandled error:", error);

    return new Response(
      JSON.stringify({
        error: "Internal server error",
        details: error.message,
        suggestion: "Check environment variables and Firebase configuration"
      }),
      {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      }
    );
  }
});