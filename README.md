# TerraPulse

A simultaneous‑turn, Risk‑inspired strategy game designed for fully **asynchronous** play.  All persistence **and** core game mechanics run inside Supabase Postgres (Free Tier), driven by `LISTEN/NOTIFY` and the `pg_net` WebSocket extension.  No dedicated game server is required.

---

## ✨ Key Features

| Area                               | Highlights                                                                                                                            |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| **Asynchronous Loop**              | Players queue actions whenever they have time; a *pulse* (tick) resolves every 24 h — or instantly if all players have locked orders. |
| **Action‑Point Economy**           | Each player gets a fixed budget of Action Points (AP) that regenerates every minute.  Prevents grinding while allowing long sessions. |
| **Deterministic Server‑Side Dice** | All randomness lives in Postgres (`setseed()` + `random()`), guaranteeing identical replays from DB state alone.                      |
| **Push Realtime Updates**          | Game events broadcast with `NOTIFY game_evts <json>` → `pg_net` → Supabase Realtime → client subscribe.                               |
| **Offline Safety**                 | Auto‑garrison orders + defensive bonuses stop midnight wipeouts.                                                                      |
| **Free‑tier Compatible**           | 500 MB DB, unlimited API, 50k MAU ‑ comfortably runs thousands of concurrent games.                                                   |

---

## 🏗️ System Architecture

```
Browser (React + Vite) ──►  Supabase.JS  ─────────┐
                                         │ REST
                                         │ RPC
                                   (PostgREST)
                                         ▼
    ┌─────────────────────────────────────────────────────────┐
    │  Supabase Postgres (DB + logic)                         │
    │                                                       │
    │  tables:                                               │
    │    games, players, territories, orders, events         │
    │                                                       │
    │  PL/pgSQL:                                             │
    │    tick()              -- main resolver                │
    │    update_ap()         -- AP regen trigger             │
    │    lock_orders()       -- RPC for players              │
    │    default_garrison()  -- autodefense helper           │
    │                                                       │
    │  LISTEN game_evts;     -- json payloads                │
    │  pg_net → WebSocket → Supabase Realtime                │
    └─────────────────────────────────────────────────────────┘
```

---

## 🔌  Supabase Setup

1. **Create project** → *Run in Free Tier.*  Under **Database → Extensions** enable:

   * `pg_net`
   * `pgcrypto` (for UUID helpers)
2. **Auth** → Enable Email (magic link) + GitHub oauth.
3. **Edge Functions** → *optional* `trigger_tick` function for fast‑forward requests.
4. **Cron** → Add Scheduled Function:

   ```cron
   */5 * * * *  SELECT public.tick();  -- fallback every 5 min
   ```
5. **Environment Vars (Local)**

   ```env
   SUPABASE_URL=https://<project>.supabase.co
   SUPABASE_ANON_KEY=<anon>
   SUPABASE_SERVICE_KEY=<service>
   ```

---

## 🗄️  Database Schema (excerpt)

```sql
-- games
CREATE TABLE public.games (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name         text NOT NULL,
  created_at   timestamptz DEFAULT now(),
  status       text CHECK (status IN ('open','active','finished')),
  next_tick_at timestamptz,
  tick_length  interval      DEFAULT interval '24 hours'
);

-- players (one per user per game)
CREATE TABLE public.players (
  id         uuid  PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id    uuid  REFERENCES public.games ON DELETE CASCADE,
  user_id    uuid  REFERENCES auth.users ON DELETE CASCADE,
  ap         int   DEFAULT 0,
  ap_cap     int   DEFAULT 24,
  is_locked  bool  DEFAULT false,
  capital_id uuid  -- FK to territories
);

-- territories
CREATE TABLE public.territories (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id   uuid REFERENCES public.games ON DELETE CASCADE,
  owner_id  uuid REFERENCES public.players,
  name      text,
  armies    int  DEFAULT 0,
  continent text
);

-- orders
CREATE TABLE public.orders (
  id           uuid  PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id      uuid  REFERENCES public.games ON DELETE CASCADE,
  player_id    uuid  REFERENCES public.players ON DELETE CASCADE,
  type         text  CHECK (type IN ('reinforce','attack','fortify')),
  payload      jsonb NOT NULL,
  cost_ap      int   NOT NULL,
  executed_at  timestamptz
);
```

### Row‑Level Security

```sql
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "orders‑own" ON public.orders
  FOR ALL USING (player_id = auth.uid());
```

---

## ⚙️ Core PL/pgSQL Procedures

### `update_ap()` – regen trigger (per‑minute)

```sql
CREATE OR REPLACE FUNCTION public.update_ap() RETURNS void AS $$
BEGIN
  UPDATE public.players
  SET    ap = LEAST(ap_cap, ap + 1)
  WHERE  game_id IN (SELECT id FROM public.games WHERE status='active');
END; $$ LANGUAGE plpgsql;

-- call via cron: SELECT public.update_ap();
```

### `lock_orders(p_game uuid, p_player uuid)` – player ready

```sql
UPDATE public.players SET is_locked = true WHERE id = p_player AND game_id = p_game;
-- if every active player in the game is_locked, call tick();
```

### `tick()` – single source of truth

```sql
CREATE OR REPLACE FUNCTION public.tick(p_game uuid DEFAULT NULL) RETURNS void AS $$
DECLARE
  v_game  record;
BEGIN
  -- advisory lock per‑game to prevent double ticks
  FOR v_game IN SELECT * FROM public.games WHERE (id = p_game OR p_game IS NULL) AND status='active' LOOP
    PERFORM pg_advisory_xact_lock(hashtext(v_game.id::text));

    -- 1. collect & validate unexecuted orders
    CALL public.apply_default_garrison(v_game.id);

    -- 2. resolve battles (dice)
    -- 3. move armies / apply reinforcements
    -- 4. compute AP costs, zero ap

    -- 5. emit NOTIFY
    PERFORM pg_notify('game_evts', json_build_object('game',v_game.id,'tick',now())::text);

    -- 6. schedule next_tick_at
    UPDATE public.games SET next_tick_at = now() + v_game.tick_length WHERE id = v_game.id;
  END LOOP;
END; $$ LANGUAGE plpgsql;
```

---

## 🔄 Action Lifecycle

1. **Client** inserts rows into `public.orders` (AP cost auto‑checked).
2. Client calls `rpc/lock_orders` when done.
3. If *all* players locked **or** cron triggers, server executes `tick()`.
4. `tick()` updates state + writes immutable `events` log + `NOTIFY`s.
5. **Client** subscribed via Realtime receives diff → re‑renders.

---

## 🖥️ Front‑End Integration (React)

```ts
import { createClient } from '@supabase/supabase-js';
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// subscribe to game events
await supabase.channel('game_evts')
  .on('postgres_changes', { event: '*', schema: 'public', table: 'events', filter: `game_id=eq.${gameId}` }, payload => {
     store.applyEvent(payload.new);
  })
  .subscribe();

// submit an order
await supabase.from('orders').insert({
  game_id: gameId,
  player_id: userId,
  type: 'attack',
  payload: { from: terrA, to: terrB, dice: 3 },
  cost_ap: 1,
});
```

---

## 🚀 Local Dev Workflow

```bash
# 1. Service startup
supabase start        # spins docker‑compose db + studio

# 2. Load schema & seeds
supabase db reset     # pulls /supabase/schema.sql & seeds

# 3. Run tick manually
supabase functions invoke --name tick   # or SQL: SELECT public.tick();

# 4. Front‑end
npm run dev           # http://localhost:5173
```

### Tests

* **Unit** – `tests/plpgsql/tick.test.sql` (pg‑tap).
* **Integration** – Cypress flow: signup → create game → two bots submit orders → run tick → assert map state.

---

## 📈 Scaling & Performance

* **Events table partitioned** by month to keep scans cheap.
* Use `jsonb_path_ops` GIN indexes on `orders.payload`.
* Cap event log at 90 days via policy.

---

## 🗺️ Roadmap

* Animated dice & battle logs
* Email / push notifications for new pulses
* Skirmish live‑play mode (accelerated AP)
* Godot 3‑D client using same protocol

---

## 📝 License

MIT