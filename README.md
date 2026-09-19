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

## Deploy

### GitHub Pages (what's live)

`.github/workflows/pages.yml` uploads `public/` on every push to `main`. The repo is
public because Pages on a private repo needs a paid plan.

It lives in the `blitzbowl` org rather than a personal account, and is named
`blitzbowl.github.io` so Pages serves it from the root — that's what keeps a
username out of the URL. Renaming the repo would move the site to a subpath.

    https://blitzbowl.github.io/

There's no server on Pages, so `public/config.js` carries the Supabase URL and anon
key as a committed file. It's loaded as `config.js?v=N` — Pages serves everything
with `max-age=600`, so without the version a returning player could pair a fresh
`index.html` with a ten-minute-old config. **Bump the `v` in `index.html` whenever
you change `config.js`.** That's fine: the anon key is a publishable key, and the chat
tables grant it nothing directly (see **Team chat** below).

### Railway (still wired, unused)

`server.js`, `Procfile` and `railway.json` are intact. **New Project → Deploy from
GitHub repo → blitz-bowl**; Nixpacks detects Node and runs `npm start`, with the
healthcheck at `/healthz`. Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` under Variables
and `server.js` serves them at `/config.json`.

The two paths don't fight: `config.js` only sets `window.BB_CONFIG` when its values
are non-empty, and the game falls through to `/config.json` when it isn't set.

Custom domain: Pages under **Settings → Pages**, Railway under **Settings →
Networking**.

---

## Working on it in Claude Code

```bash
git clone git@github.com:blitzbowl/blitzbowl.github.io.git
cd blitzbowl.github.io
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

## Team chat

`supabase/chat.sql` — one table, two functions, one room per code.

The room code is real access control, not a filter. `bb_messages` has RLS on with
**no policies**, so the anon key cannot read or write a single row of it. Everything
goes through `bb_history(code)` and `bb_post(code, author, body, client)`, which are
`security definer` and demand the code. Without that, anyone holding the anon key —
which is sitting in `config.js` in a public repo — could read every room.

Live delivery is a Realtime **broadcast** channel named `bb-chat-<CODE>`; channel
names aren't enumerable, so the code gates that too. A poll every 8s backstops anyone
whose socket dropped. `bb_post` caps messages at 12/minute/device and trims each room
to its last 300.

To change the room code everyone uses, just tell them a different one — there's no
room registry. The last code used is remembered in `localStorage` under `bb_room`.

| Want to change | Where |
|---|---|
| Flood limit, message length, room history depth | `bb_post` in `supabase/chat.sql` |
| Who appears as the author | `chatSend()` — currently `S.team` |
| Bubble styling | `.msg` / `.chatbar` in `index.html` |

---

## Calling a play

Picking a play doesn't snap it. The first tap lays the routes on the field as dashed
lines and highlights the card; tapping that same play again snaps. Tapping a
*different* play just switches the preview. Keys `1`-`5` follow the same two-press
rule.

The mechanism is `G.picked` plus `selectPlay()`. `drawPlayers()` already drew routes
during `PRESNAP` from `w.pts`, so the only real change was that `newPlay()` now blanks
`w.pts` after `layRoutes()` -- positions are set, lines stay hidden until you choose.

## Challenges and difficulty

The 20 challenges are all about yards and touchdowns -- gain ladders (10/20/30/40/50/60
on one play), touchdown ladders, consecutive 10+ plays, per-drill totals. Nothing
rewards merely snapping the ball. An interception costs `INT_COST` points (15), floored
at zero, so a pick is the one thing that moves the wallet backwards.

Difficulty was raised a notch in five places: `cthRadius` (smaller catch window),
`accScatter` (more wobble), `T.dbBase`/`T.dbScale` and the `DIFF` table (faster
coverage), `T.rushSpeed` (less pocket time), and the interception radius in
`resolveCatch`. Worth keeping in mind when tuning further: at Bronze a top-roll DB runs
7.77 yd/s against an 80-speed receiver's 8.06, so speed still beats coverage on the
lowest tier. From Silver up it doesn't, and you have to win with route breaks -- which
is what `steer()`'s momentum model is for. If you push `DIFF[0].db` much past 0.95 you
take that escape hatch away from the easiest difficulty.

---

## Saves

Progress lives in `localStorage` under `pg_save` — team, colors, roster, lineup,
challenge completions, RP, record. Device-local, wiped when site data is cleared,
and **separate per origin**: the Claude artifact and the Railway deploy each keep
their own save. Moving hosts means starting over unless profiles move to Supabase.

There's a schema version on the save (`S.v`) with a migration path in `boot()` —
bump it when the roster or lineup shape changes, or old saves will break.
