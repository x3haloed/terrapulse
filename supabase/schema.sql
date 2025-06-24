-- Enable HTTP requests via pg_net
-- (If you're using Supabase, this is already done)
-- CREATE EXTENSION IF NOT EXISTS pg_net;

-- Enable UUID generation
-- (If you're using Supabase, this is already done)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";


-- games: global game metadata
CREATE TABLE public.games (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name         text NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  status       text NOT NULL DEFAULT 'open' CHECK (status IN ('open','active','finished')),
  next_tick_at timestamptz,
  tick_length  interval NOT NULL DEFAULT interval '24 hours'
);
COMMENT ON TABLE public.games IS 'Global metadata for each game session.';


-- players: one per user per game
CREATE TABLE public.players (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id      uuid NOT NULL REFERENCES public.games ON DELETE CASCADE,
  user_id      uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  name         text, -- Player's name or handle, maybe from auth.users
  ap           int NOT NULL DEFAULT 0,
  ap_cap       int NOT NULL DEFAULT 24,
  is_locked    bool NOT NULL DEFAULT false,
  capital_id   uuid, -- FK to territories, added later to avoid circular dependency
  -- Add last_ap_ts for lazy AP regeneration
  last_ap_ts   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_player_in_game UNIQUE(game_id, user_id)
);
COMMENT ON TABLE public.players IS 'Represents a user''s participation in a single game.';


-- territories: board cells
CREATE TABLE public.territories (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id     uuid NOT NULL REFERENCES public.games ON DELETE CASCADE,
  owner_id    uuid REFERENCES public.players ON DELETE SET NULL,
  name        text NOT NULL,
  armies      int NOT NULL DEFAULT 0,
  continent   text NOT NULL
);
COMMENT ON TABLE public.territories IS 'The individual cells on the game board.';

-- Add the foreign key from players to territories for the capital
ALTER TABLE public.players
ADD CONSTRAINT fk_capital_territory
FOREIGN KEY (capital_id) REFERENCES public.territories(id);


-- orders: pending actions submitted by players
CREATE TABLE public.orders (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id      uuid NOT NULL REFERENCES public.games ON DELETE CASCADE,
  player_id    uuid NOT NULL REFERENCES public.players ON DELETE CASCADE,
  type         text NOT NULL CHECK (type IN ('reinforce','attack','fortify')),
  payload      jsonb NOT NULL,
  cost_ap      int NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  executed_at  timestamptz
);
COMMENT ON TABLE public.orders IS 'Player-submitted actions to be resolved in the next tick.';


-- events: immutable log of all game state changes
CREATE TABLE public.events (
  id           bigserial PRIMARY KEY,
  game_id      uuid NOT NULL REFERENCES public.games ON DELETE CASCADE,
  created_at   timestamptz NOT NULL DEFAULT now(),
  type         text NOT NULL,
  payload      jsonb NOT NULL
) PARTITION BY RANGE (created_at);
COMMENT ON TABLE public.events IS 'Immutable, partitioned log of all significant game events.';

-- Create a default partition for events
CREATE TABLE events_default PARTITION OF public.events DEFAULT;


--------------------------------------------------------------------------------
-- Row-Level Security (RLS)
--------------------------------------------------------------------------------

-- Enable RLS on all tables
ALTER TABLE public.games ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.players ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.territories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

-- Helper function to get user's player_id in a specific game
CREATE OR REPLACE FUNCTION public.get_my_player_id(p_game_id uuid)
RETURNS uuid AS $$
  SELECT id FROM public.players WHERE game_id = p_game_id AND user_id = auth.uid();
$$ LANGUAGE sql STABLE;


-- games: Anyone can see any game. Authenticated users can create games.
CREATE POLICY "games_select_policy" ON public.games FOR SELECT
  USING (true);
CREATE POLICY "games_insert_policy" ON public.games FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');


-- players: Anyone can see players in any game. Users can insert their own player record.
CREATE POLICY "players_select_policy" ON public.players FOR SELECT
  USING (true);
CREATE POLICY "players_insert_policy" ON public.players FOR INSERT
  WITH CHECK (user_id = auth.uid());
-- Users can update their own 'is_locked' status.
CREATE POLICY "players_update_lock_policy" ON public.players FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());


-- territories: Anyone can see all territories.
CREATE POLICY "territories_select_policy" ON public.territories FOR SELECT
  USING (true);


-- orders: Players can CRUD their own orders for a game they are in.
CREATE POLICY "orders_select_policy" ON public.orders FOR SELECT
  USING (player_id = public.get_my_player_id(game_id));

CREATE POLICY "orders_insert_policy" ON public.orders FOR INSERT
  WITH CHECK (player_id = public.get_my_player_id(game_id));

CREATE POLICY "orders_update_policy" ON public.orders FOR UPDATE
  USING (player_id = public.get_my_player_id(game_id));

CREATE POLICY "orders_delete_policy" ON public.orders FOR DELETE
  USING (player_id = public.get_my_player_id(game_id));


-- events: Anyone can see events for any game.
CREATE POLICY "events_select_policy" ON public.events FOR SELECT
  USING (true);

-- Create read-only views for clients
-- This simplifies client-side logic by providing denormalized data.

-- A view of games with player counts
CREATE OR REPLACE VIEW public.games_with_player_count AS
SELECT
  g.*,
  (SELECT count(*) FROM public.players p WHERE p.game_id = g.id) AS player_count
FROM public.games g;


-- A view for the main game state, including territories and their owners
CREATE OR REPLACE VIEW public.game_state AS
SELECT
  t.id as territory_id,
  t.game_id,
  t.name as territory_name,
  t.continent,
  t.armies,
  p.id as owner_id,
  p.user_id as owner_user_id,
  p.name as owner_name
FROM public.territories t
LEFT JOIN public.players p ON t.owner_id = p.id;


--------------------------------------------------------------------------------
-- Functions and Triggers
--------------------------------------------------------------------------------

-- Lazy AP regeneration: current_ap
CREATE OR REPLACE FUNCTION public.current_ap(p_player uuid)
RETURNS int AS $$
DECLARE
  v_player public.players%ROWTYPE;
  v_now timestamptz := now();
  v_delta int;
BEGIN
  SELECT * INTO v_player FROM public.players WHERE id = p_player FOR UPDATE;
  v_delta := FLOOR(EXTRACT(EPOCH FROM (v_now - v_player.last_ap_ts)) / 60); -- minutes
  IF v_delta > 0 THEN
    v_player.ap := LEAST(v_player.ap_cap, v_player.ap + v_delta);
    v_player.last_ap_ts := v_player.last_ap_ts + (v_delta || ' minutes')::interval;
    UPDATE public.players SET ap = v_player.ap, last_ap_ts = v_player.last_ap_ts WHERE id = p_player;
  END IF;
  RETURN v_player.ap;
END;
$$ LANGUAGE plpgsql;

-- Self-ticking game loop: maybe_run_tick
CREATE OR REPLACE FUNCTION public.maybe_run_tick(p_game uuid) RETURNS void AS $$
DECLARE
  v_game public.games%ROWTYPE;
BEGIN
  SELECT * INTO v_game FROM public.games WHERE id = p_game FOR UPDATE;
  IF v_game.next_tick_at <= now() THEN
    PERFORM pg_try_advisory_xact_lock(hashtext(v_game.id::text));
    IF FOUND THEN
      PERFORM public.tick(v_game.id);
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Modified trigger: use current_ap for AP cost check
CREATE OR REPLACE FUNCTION public.check_order_cost()
RETURNS TRIGGER AS $$
DECLARE
  current_ap int;
BEGIN
  SELECT public.current_ap(NEW.player_id) INTO current_ap;
  IF current_ap < NEW.cost_ap THEN
    RAISE EXCEPTION 'Not enough Action Points. Required: %, Available: %', NEW.cost_ap, current_ap;
  END IF;
  UPDATE public.players
  SET ap = current_ap - NEW.cost_ap
  WHERE id = NEW.player_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_order_insert
  BEFORE INSERT ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.check_order_cost();

-- Remove per-minute AP regeneration function
DROP FUNCTION IF EXISTS public.update_ap();

-- Modified lock_orders: call tick() directly
CREATE OR REPLACE FUNCTION public.lock_orders(p_game_id uuid)
RETURNS void AS $$
DECLARE
  all_locked bool;
BEGIN
  UPDATE public.players
  SET is_locked = true
  WHERE game_id = p_game_id AND user_id = auth.uid();

  SELECT bool_and(is_locked) INTO all_locked
  FROM public.players
  WHERE game_id = p_game_id;

  IF all_locked THEN
    PERFORM public.tick(p_game_id);
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Auto-garrison for idle players
CREATE OR REPLACE FUNCTION public.apply_default_garrison(p_game_id uuid)
RETURNS void AS $$
BEGIN
  -- For any player who is not locked, add a default reinforce order
  -- This is a simple version: reinforce their capital with all available armies this turn (usually from continent bonus)
  -- A more complex version could involve reinforcing border territories.
  INSERT INTO public.orders (game_id, player_id, type, payload, cost_ap)
  SELECT
    p.game_id,
    p.id,
    'reinforce',
    jsonb_build_object('territory_id', p.capital_id, 'armies', 1), -- Simplified: add 1 army
    0 -- No cost for default orders
  FROM public.players p
  WHERE p.game_id = p_game_id
  AND p.is_locked = false;
END;
$$ LANGUAGE plpgsql;

-- Main tick function
CREATE OR REPLACE FUNCTION public.tick(p_game_id uuid DEFAULT NULL)
RETURNS void AS $$
DECLARE
  v_game record;
  unexecuted_orders CURSOR FOR
    SELECT * FROM public.orders
    WHERE game_id = v_game.id AND executed_at IS NULL
    ORDER BY created_at;
  v_order record;
  attacker_rolls int[];
  defender_rolls int[];
  attack_losses int;
  defend_losses int;
  v_from_territory public.territories;
  v_to_territory public.territories;

BEGIN
  FOR v_game IN
    SELECT * FROM public.games
    WHERE (id = p_game_id OR p_game_id IS NULL)
    AND status = 'active'
    AND next_tick_at <= now()
  LOOP
    -- Advisory lock to prevent concurrent ticks for the same game
    PERFORM pg_advisory_xact_lock(hashtext(v_game.id::text));

    -- Set a seed for deterministic randomness
    PERFORM setseed(0.5); -- In a real scenario, this might come from a secure source

    -- 1. Apply default garrisons for non-locked players
    CALL public.apply_default_garrison(v_game.id);

    -- 2. Resolve orders
    -- This is a simplified resolution loop. A real implementation would handle order dependencies.
    -- For now, we do reinforce -> attack -> fortify

    -- REINFORCE
    FOR v_order IN SELECT * FROM public.orders WHERE game_id=v_game.id AND type='reinforce' AND executed_at IS NULL LOOP
      UPDATE public.territories
      SET armies = armies + (v_order.payload->>'armies')::int
      WHERE id = (v_order.payload->>'territory_id')::uuid;

      UPDATE public.orders SET executed_at = now() WHERE id=v_order.id;
    END LOOP;

    -- ATTACK
    FOR v_order IN SELECT * FROM public.orders WHERE game_id=v_game.id AND type='attack' AND executed_at IS NULL LOOP
      SELECT * INTO v_from_territory FROM public.territories WHERE id = (v_order.payload->>'from')::uuid;
      SELECT * INTO v_to_territory FROM public.territories WHERE id = (v_order.payload->>'to')::uuid;

      IF v_from_territory.owner_id = v_order.player_id AND v_from_territory.armies > 1 THEN
        -- Determine number of dice
        attacker_rolls := ARRAY(SELECT floor(random() * 6) + 1 FROM generate_series(1, LEAST(3, v_from_territory.armies - 1))) ORDER BY 1 DESC;
        defender_rolls := ARRAY(SELECT floor(random() * 6) + 1 FROM generate_series(1, LEAST(2, v_to_territory.armies))) ORDER BY 1 DESC;

        -- Compare dice
        attack_losses := 0;
        defend_losses := 0;
        FOR i IN 1..LEAST(array_length(attacker_rolls, 1), array_length(defender_rolls, 1)) LOOP
          IF attacker_rolls[i] > defender_rolls[i] THEN
            defend_losses := defend_losses + 1;
          ELSE
            attack_losses := attack_losses + 1;
          END IF;
        END LOOP;

        -- Apply losses
        UPDATE public.territories SET armies = armies - attack_losses WHERE id = v_from_territory.id;
        UPDATE public.territories SET armies = armies - defend_losses WHERE id = v_to_territory.id;

        -- Check for conquest
        IF (SELECT armies FROM public.territories WHERE id = v_to_territory.id) <= 0 THEN
          UPDATE public.territories SET owner_id = v_from_territory.owner_id, armies = array_length(attacker_rolls, 1) - attack_losses WHERE id = v_to_territory.id;
          UPDATE public.territories SET armies = armies - (array_length(attacker_rolls, 1) - attack_losses) WHERE id = v_from_territory.id;
        END IF;

      END IF;
      UPDATE public.orders SET executed_at = now() WHERE id=v_order.id;
    END LOOP;

    -- FORTIFY
    FOR v_order IN SELECT * FROM public.orders WHERE game_id=v_game.id AND type='fortify' AND executed_at IS NULL LOOP
       -- ... implementation for fortify ...
       UPDATE public.orders SET executed_at = now() WHERE id=v_order.id;
    END LOOP;

    -- 3. Reset player lock status and zero out AP (or whatever the rule is)
    UPDATE public.players SET is_locked = false, ap = 0 WHERE game_id = v_game.id;

    -- 4. Emit event
    INSERT INTO public.events (game_id, type, payload)
    VALUES (v_game.id, 'tick', jsonb_build_object('tick_time', now()));

    -- 5. Schedule next tick
    UPDATE public.games SET next_tick_at = now() + v_game.tick_length WHERE id = v_game.id;

  END LOOP;
END;
$$ LANGUAGE plpgsql;


-- Trigger to NOTIFY on new event
CREATE OR REPLACE FUNCTION public.notify_game_event()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM pg_notify(
    'game_evts',
    json_build_object(
      'game_id', NEW.game_id,
      'event_type', NEW.type,
      'payload', NEW.payload
    )::text
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_new_event
  AFTER INSERT ON public.events
  FOR EACH ROW EXECUTE FUNCTION public.notify_game_event(); 