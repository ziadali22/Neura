const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const storage = admin.storage();

// MARK: - POST /getShareUrl
// Called by the iOS app after uploading a file to Storage.
// Body: { fileId: string, filename: string, storagePath: string }
// Returns: { url: string, expiresAt: number (Unix seconds) }

exports.getShareUrl = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");

  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    return res.status(204).send("");
  }

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method Not Allowed" });
  }

  const { fileId, filename, storagePath } = req.body;

  if (!fileId || !storagePath) {
    return res.status(400).json({ error: "Missing fileId or storagePath" });
  }

  const expiresAtMs = Date.now() + 2 * 60 * 60 * 1000; // 2 hours from now

  // Store the mapping so GET /share/:fileId can look it up
  await db.collection("shares").doc(fileId).set({
    storagePath,
    filename: filename || "",
    expiresAt: expiresAtMs,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const projectId = process.env.GCLOUD_PROJECT;
  const region = "us-central1";
  const shortURL = `https://${region}-${projectId}.cloudfunctions.net/share/${fileId}`;

  return res.status(200).json({
    url: shortURL,
    expiresAt: expiresAtMs / 1000, // iOS expects Unix seconds
  });
});

// MARK: - GET /share/:fileId
// Scanned by the doctor's phone. Looks up the share record, generates a
// 15-minute signed download URL, and redirects the browser to it.

exports.share = functions.https.onRequest(async (req, res) => {
  // req.path is "/{fileId}" when invoked as /share/{fileId}
  const fileId = req.path.replace(/^\/+/, "").trim();

  if (!fileId) {
    return res.status(400).send("Missing file ID.");
  }

  const doc = await db.collection("shares").doc(fileId).get();

  if (!doc.exists) {
    return res.status(404).send("Share link not found.");
  }

  const { storagePath, expiresAt } = doc.data();

  if (Date.now() > expiresAt) {
    return res.status(410).send(`
      <html>
        <body style="font-family:system-ui;text-align:center;padding:60px">
          <h2>Link Expired</h2>
          <p>This sharing link expired. Ask the patient to generate a new one.</p>
        </body>
      </html>
    `);
  }

  // Generate a short-lived signed URL — the doctor's browser opens it immediately
  const bucket = storage.bucket();
  const file = bucket.file(storagePath);

  const [signedUrl] = await file.getSignedUrl({
    action: "read",
    expires: Date.now() + 15 * 60 * 1000, // 15 minutes is enough
  });

  return res.redirect(302, signedUrl);
});
