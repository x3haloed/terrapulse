-- pgTAP test for the tick() function.
-- This is a placeholder and would need to be expanded.

BEGIN;

-- Plan the tests. We will run three assertions.
SELECT plan(3);

-- Store the current next_tick_at to compare after running tick().
CREATE TEMP TABLE tmp_old_tick AS
  SELECT next_tick_at FROM public.games
  WHERE id = '00000000-0000-0000-0000-000000000001';

-- Run the tick() function and ensure it succeeds.
SELECT lives_ok(
  $$ SELECT public.tick('00000000-0000-0000-0000-000000000001') $$,
  'tick() function should run without errors for the seed game'
);

-- Verify an event row was inserted for the game.
SELECT is(
  (SELECT count(*) FROM public.events
   WHERE game_id = '00000000-0000-0000-0000-000000000001'
     AND type = 'tick'),
  1,
  'tick() inserts an event'
);

-- Verify next_tick_at advanced relative to the stored value.
SELECT ok(
  (SELECT next_tick_at FROM public.games WHERE id = '00000000-0000-0000-0000-000000000001') >
  (SELECT next_tick_at FROM tmp_old_tick),
  'next_tick_at is scheduled in the future'
);

-- Finish the tests.
SELECT * FROM finish();

ROLLBACK;
