# Blitz Bowl

Pocket-passing football game. Call the play, drop back, find the open man, then take
over as the receiver and run it in. Built with Henry Sather.

Single static HTML file — no build step, no framework, no bundler. Canvas + vanilla JS.

---

## Run it locally

```bash
npm install
npm start          # http://localhost:3000
```

The whole game is `public/index.html`. Open it directly in a browser and it works —
the Express server exists only so Railway has something to boot.

---

## Deploy to Railway

Same shape as the Hegenes dashboard, minus the Python.

```bash
gh repo create blitz-bowl --private --source=. --remote=origin --push
```

Then in Railway: **New Project → Deploy from GitHub repo → blitz-bowl**.

Nixpacks detects Node from `package.json` and runs `npm start`. `railway.json`
pins the start command and points the healthcheck at `/healthz`. Nothing else to
configure — no env vars, no database, no build command.

Custom domain goes under **Settings → Networking → Custom Domain**.

---

## Working on it in Claude Code

```bash
git clone git@github.com:<you>/blitz-bowl.git
cd blitz-bowl
claude
```

Everything lives in one file, so point Claude at the section you want:

| What you want to change | Where it is in `public/index.html` |
|---|---|
| The roster — names, jersey numbers, star ratings | `const ROSTER = [` |
| Routes (go, post, slant, drag, wheel…) | `const ROUTES = {` |
| The five plays and their route assignments | `const PLAYBOOK = [` |
| The 20 challenges and their point values | `const CHALLENGES = [` |
| Rank tiers and bot difficulty per tier | `const TIERS` / `const DIFF` |
| Speeds, pocket time, tackle radius | `const T = {` |
| Camera — top-down vs the angled side view | `function P(` and `const SIDE =` |
| Player figure drawing | `function figure(` |
| On-screen controller (stick, sprint, skill, hurdle) | search `paintPad` |

### A note on scale

`index.html` is ~2,500 lines in one file. That's fine for now and genuinely nice for
a game — no module graph, no build, edit and refresh. If it keeps growing, the split
that costs the least is:

```
public/
  index.html      markup + styles
  js/engine.js    tick, physics, collision
  js/render.js    projection, field, figures
  js/roster.js    ROSTER, ROUTES, PLAYBOOK, CHALLENGES
  js/ui.js        screens, roster picker, shop, ranks
```

Plain `<script>` tags in order — still no bundler. Only worth doing when a single
edit starts touching four unrelated places.

---

## What breaks outside Claude

The game currently uses two Claude artifact runtime capabilities:

- **`db`** — the online leaderboard and ranked matchmaking. Player profiles are
  written to a `players/` collection and read back to find opponents.
- **`room`** — the "N coaches online" presence count.

Both are reached through `window.claude.use(...)`. That object does not exist
anywhere else, so on Railway those calls resolve to `null`.

**This is already handled.** Every call site checks for `null` and degrades: the
leaderboard shows "offline," Online falls back to a bot match, presence hides
itself. Nothing throws. Everything else — challenges, roster, drills, games,
ranks, saves — works identically.

### Rebuilding online on Supabase

Same pattern you used for the fitness app. Two tables and anonymous auth cover it:

```sql
create table profiles (
  id          uuid primary key default gen_random_uuid(),
  client_id   text unique not null,
  team        text not null,
  coach       text,
  color       text,
  rp          int  not null default 0,
  wins        int  not null default 0,
  losses      int  not null default 0,
  squad       jsonb not null default '[]',
  updated_at  timestamptz not null default now()
);

create index profiles_rp_idx on profiles (rp desc);
```

Then swap the three functions that touch the capability:

- `pushProfile()` → `supabase.from('profiles').upsert(...)`
- `refreshLeaderboard()` → `.select().order('rp',{ascending:false}).limit(15)`
- `findOpponent()` → `.select()` near the player's RP, pick one at random

Keep the `null` guards. They're what lets the same file run in both places.

Presence ("coaches online") maps to Supabase Realtime presence, but it's cosmetic —
skip it unless you want it.

---

## Saves

Progress lives in `localStorage` under `pg_save` — team, colors, roster, lineup,
challenge completions, RP, record. Device-local, wiped when site data is cleared,
and **separate per origin**: the Claude artifact and the Railway deploy each keep
their own save. Moving hosts means starting over unless profiles move to Supabase.

There's a schema version on the save (`S.v`) with a migration path in `boot()` —
bump it when the roster or lineup shape changes, or old saves will break.
