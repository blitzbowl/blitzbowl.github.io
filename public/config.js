/* Public runtime config, served as a plain file by GitHub Pages.

   The anon key is meant to be published — it only grants what row-level
   security allows, and the chat tables grant it nothing directly (every
   read and write goes through a function that demands the room code).

   Left blank, the game falls through to /config.json, which is how the
   Railway deploy injects the same two values from env vars. So the same
   file runs in both places. */
(function () {
  var cfg = {
    supabaseUrl: "",
    supabaseAnonKey: ""
  };
  if (cfg.supabaseUrl && cfg.supabaseAnonKey) window.BB_CONFIG = cfg;
})();
