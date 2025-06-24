1 — Project Snapshot

Item	Value
Name	TerraPulse
Core Loop	Simultaneous-turn, Risk-style world conquest
Back-end	Supabase Free Tier (Postgres + LISTEN/NOTIFY + pg_net WebSockets)
Front-end	Vite + React (TypeScript)
Source of Truth	Everything—rules, state, events—lives in Postgres (schema.sql)


⸻

2 — Prime Directives
	1.	Preserve Determinism
	•	All game state transitions must be reproducible from DB rows alone.
	•	Randomness = setseed() + random() inside the tick() procedure.
	2.	Stay Inside Free-Tier Limits
	•	≤ 500 MB total DB storage.
	•	No long-running functions > 10 s.
	•	Keep WebSocket payloads < 50 KB.
	3.	One Source, One Path
	•	All schema changes go through /supabase/schema.sql migration blocks.
	•	Never manipulate tables ad-hoc from the client.
	4.	Security First
	•	No secrets in the repo.
	•	Use Row-Level Security (RLS) on every table; default deny.
	5.	Fail Loud, Roll Back Clean
	•	If a PL/pgSQL step throws, abort the transaction; never half-apply game logic.

⸻

3 — Turn Checklist
	1.	Think – Review the open GitHub issue / goal for this turn.
	2.	Plan – Outline the minimum set of changes (code, SQL, docs).
	3.	Act – Implement; run npm test && supabase db reset locally.
	4.	Verify – Manual sanity check in browser: create game, submit orders, run tick().
	5.	Commit – Message format:

<scope>: <summary>

WHY:
- <bullet 1>
- <bullet 2>

HOW:
- <key technical detail>


	6.	Reflect – Add a short note to the issue/comment if next agent needs context.

⸻

4 — Key Tables (read-only primer)

Table	Purpose	Notes
games	Global game metadata	status, next_tick_at
players	One row ↔ one user ↔ one game	Holds ap, is_locked, capital_id
territories	Board cells	owner_id, armies
orders	Pending actions	type, payload, executed_at
events	Immutable log	Emitted by tick(), broadcast via NOTIFY


⸻

5 — Allowed Client Operations
	•	SELECT from any public.* view.
	•	INSERT into orders (validated by trigger).
	•	Call rpc/lock_orders to mark readiness.
	•	Read WebSockets on realtime:public:game_evts.

All other mutations are reserved for server-side logic inside Postgres.

⸻

6 — Style Rules
	•	SQL – Snake_case identifiers; -- for comments; wrap DDL in BEGIN; … COMMIT;.
	•	TypeScript – ESLint clean; prefer functional components & hooks; state via Zustand.
	•	Docs – Update README or docs/** when behavior changes; keep this file current.

⸻

7 — Common Pitfalls
	1.	Forgetting to update RLS after adding columns.
	2.	Broadcasting giant payloads (slice to diff before NOTIFY).
	3.	Using NOW() in client code—always trust server time.
	4.	Allowing simultaneous fast-forward ticks—guard with pg_advisory_lock.