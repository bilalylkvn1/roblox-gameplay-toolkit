# Validation

The initial extraction was checked on 21 October 2026.

- Luau 0.743 compiles every source, example, and test file.
- The CLI currency suite checks precision beyond 2^53, long carries and borrows, saturation,
  invalid values, underflow, and reference arithmetic.
- Studio engine tests check motion containment in ordinary and yaw-rotated bounds,
  deterministic snapshot round trips, invalid snapshot rejection, and bounded pause recovery.
- Studio pet tests evaluate all 20 motion kinds through Idle/Walk and eligible Fly states;
  validate finite joint transforms; test repeated build/attach, pause/resume, cleanup,
  and restoration of client skinning flags.
- Tests create disposable models inside detached WorldModels; they do not use player data
  stores, purchase APIs, or the original game's live scene.

Assertion totals include individual transform components and sampled path points; they are
not counts of distinct test scenarios. Reproduction uses tests/Run.luau.

The initial package has not been benchmarked across devices, profiled with large crowds,
or tested as a published multiplayer game. The demo and isolated checks do not establish
those outcomes. CI runs syntax, currency, and artifact-build checks; it cannot run the
Roblox engine suites.

