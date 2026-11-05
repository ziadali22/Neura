import {setGlobalOptions} from "firebase-functions";
import {onRequest} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";

setGlobalOptions({maxInstances: 10, region: "us-central1"});

initializeApp({
  storageBucket: "neura-8a679.firebasestorage.app",
});

const db = getFirestore();
const storage = getStorage();

const SHARE_TTL_MS = 2 * 60 * 60 * 1000;
const SIGNED_URL_TTL_MS = 15 * 60 * 1000;

const publicOptions = {
  region: "us-central1" as const,
  invoker: "public" as const,
};

interface ShareRequestBody {
  fileId?: string;
  filename?: string;
  storagePath?: string;
}

/**
 * Project id used to build the public share redirect.
 * @return {string} Active Google Cloud project id.
 */
function projectId(): string {
  return process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    "neura-8a679";
}

/**
 * File id from `/share/{fileId}` or `/{fileId}`.
 * @param {string} path Request path.
 * @return {string} Share document id.
 */
function fileIdFromPath(path: string): string {
  const parts = path.split("?")[0].split("/").filter(Boolean);
  if (parts[0] === "share") {
    return parts[1] ?? "";
  }
  return parts[0] ?? "";
}

// MARK: - POST /getShareUrl
// Called by the iOS app after uploading a file to Storage.
// Body: { fileId, filename, storagePath }
// Returns: { url, expiresAt } where expiresAt is Unix seconds.

export const getShareUrl = onRequest(publicOptions, async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");

  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).json({error: "Method Not Allowed"});
    return;
  }

  const body = (req.body ?? {}) as ShareRequestBody;
  const fileId = body.fileId?.trim();
  const storagePath = body.storagePath?.trim();
  const filename = body.filename?.trim() || "";

  if (!fileId || !storagePath) {
    res.status(400).json({error: "Missing fileId or storagePath"});
    return;
  }

  const expiresAtMs = Date.now() + SHARE_TTL_MS;

  try {
    await db.collection("shares").doc(fileId).set({
      storagePath,
      filename,
      expiresAt: expiresAtMs,
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (err) {
    logger.error("getShareUrl failed", err);
    res.status(500).json({error: "Could not create share link."});
    return;
  }

  const shortURL =
    `https://us-central1-${projectId()}.cloudfunctions.net/share/${fileId}`;

  res.status(200).json({
    url: shortURL,
    expiresAt: expiresAtMs / 1000,
  });
});

// MARK: - GET /share/:fileId
// Opened from the QR code. Looks up the share, signs a 15-minute download
// URL, and redirects the browser to it.

export const share = onRequest(publicOptions, async (req, res) => {
  if (req.method !== "GET") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  const fileId = fileIdFromPath(req.path);
  if (!fileId) {
    res.status(400).send("Missing file ID.");
    return;
  }

  const doc = await db.collection("shares").doc(fileId).get();
  if (!doc.exists) {
    res.status(404).send("Share link not found.");
    return;
  }

  const data = doc.data();
  const storagePath = data?.storagePath;
  const expiresAt = data?.expiresAt;

  if (typeof storagePath !== "string" || typeof expiresAt !== "number") {
    res.status(404).send("Share link not found.");
    return;
  }

  if (Date.now() > expiresAt) {
    res.status(410).send(`
      <html>
        <body style="font-family:system-ui;text-align:center;padding:60px">
          <h2>Link Expired</h2>
          <p>
            This sharing link expired. Ask the patient to generate a new one.
          </p>
        </body>
      </html>
    `);
    return;
  }

  try {
    const file = storage.bucket().file(storagePath);
    const [signedUrl] = await file.getSignedUrl({
      action: "read",
      expires: Date.now() + SIGNED_URL_TTL_MS,
    });
    res.redirect(302, signedUrl);
  } catch (err) {
    logger.error("share signed URL failed", err);
    res.status(500).send("Could not open this file.");
  }
});

// MARK: - POST /deleteUserData
// Called by the iOS app before deleting the Firebase Auth account.
// Verifies the ID token, then wipes that user's Storage and Firestore data.

export const deleteUserData = onRequest(publicOptions, async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");

  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).json({error: "Method Not Allowed"});
    return;
  }

  const authorization = req.headers.authorization || "";
  if (!authorization.startsWith("Bearer ")) {
    res.status(401).json({error: "Unauthorized"});
    return;
  }

  let uid: string;
  try {
    const token = authorization.slice("Bearer ".length);
    const decoded = await getAuth().verifyIdToken(token);
    uid = decoded.uid;
  } catch (err) {
    logger.error("deleteUserData token rejected", err);
    res.status(401).json({error: "Invalid token"});
    return;
  }

  try {
    const bucket = storage.bucket();
    await bucket.deleteFiles({prefix: `users/${uid}/`});

    const userRef = db.collection("users").doc(uid);
    const deleteCollection = async (
      name: string,
    ) => {
      const snap = await userRef.collection(name).get();
      if (snap.empty) {
        return;
      }
      const batch = db.batch();
      snap.docs.forEach((item) => batch.delete(item.ref));
      await batch.commit();
    };

    await deleteCollection("documents");
    await deleteCollection("profile");
    await userRef.delete();

    res.status(200).json({success: true});
  } catch (err) {
    logger.error("deleteUserData error", err);
    const message = err instanceof Error ? err.message : "Delete failed";
    res.status(500).json({error: message});
  }
});
