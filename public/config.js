/* Public runtime config, served as a plain file by GitHub Pages.

   The anon key is meant to be published — it only grants what row-level
   security allows, and the chat tables grant it nothing directly (every
   read and write goes through a function that demands the room code).

   Left blank, the game falls through to /config.json, which is how the
   Railway deploy injects the same two values from env vars. So the same
   file runs in both places. */
(function () {
  var cfg = {
    supabaseUrl: "https://bkijvhinhblbqhrjyrcb.supabase.co",
    supabaseAnonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJraWp2aGluaGJsYnFocmp5cmNiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3ODAzNTQsImV4cCI6MjEwMDM1NjM1NH0.pEoTRj1E-iT1Y1St5G7ZX-szBA9FuG6uphxUjOpdJxo"
  };
  if (cfg.supabaseUrl && cfg.supabaseAnonKey) window.BB_CONFIG = cfg;
})();
