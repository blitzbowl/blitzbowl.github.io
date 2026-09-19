// Static server for Railway. Also injects Supabase config at /config.js from env,
// so no keys are committed to the repo.
const express = require("express");
const path = require("path");

const app = express();
const PORT = process.env.PORT || 3000;

app.get("/config.json", (_req, res) => {
  res.setHeader("Cache-Control", "no-store");
  res.json({
    supabaseUrl: process.env.SUPABASE_URL || "",
    supabaseAnonKey: process.env.SUPABASE_ANON_KEY || ""
  });
});

app.get("/healthz", (_req, res) =>
  res.json({ ok: true, supabase: Boolean(process.env.SUPABASE_URL) }));

app.use(express.static(path.join(__dirname, "public"), {
  setHeaders(res, filePath) {
    if (filePath.endsWith("index.html")) res.setHeader("Cache-Control", "no-cache");
  }
}));

app.get("*", (_req, res) => res.sendFile(path.join(__dirname, "public", "index.html")));

app.listen(PORT, () => console.log(`Blitz Bowl on :${PORT}`));
