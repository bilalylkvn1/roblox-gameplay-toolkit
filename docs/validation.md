# Validation

Version 0.2.0 was checked locally on Windows on 21 October 2026 with Luau 0.743,
Lune 0.10.5, StyLua 2.6.0, and Rojo 7.7.1. Machine-readable results are in
[validation-results.json](validation-results.json).

| Check | Coverage | Result |
| --- | --- | --- |
| Luau compile | Every source, example, test, and runner | Passed |
| Money (Luau CLI) | 2,454 assertions: precision, invalid input, carries/borrows, saturation, multiplication, division identities, remainder, grouping | Passed |
| Utilities (Luau CLI) | 486 assertions: cleanup errors/reentrancy, cooldowns, token budgets, clock rollback, key limits, weighted choice boundaries | Passed |
| Luau analyze | Money, four utility modules, utility spec and runner | Passed |
| Roaming (Lune) | 1,737 assertions: ordinary/rotated/tiny bounds, expiry, snapshot validation, bounded pause recovery | Passed |
| Animator (mocked Lune lifecycle) | 17 assertions: coalesced events, cancellation, restart, cleanup, action options | Passed |
| StyLua | Source, examples, tests, runners | Passed |
| Rojo builds | Installable module and demo; repeat builds are identical | Passed |
| Roblox engine suites for 0.2.0 | Posing, physics, joints, rendering, actual streaming/event timing | Not run; no Studio instance connected |

Assertion totals count individual transform components and sampled path points, not distinct
test scenarios. No device/crowd benchmark or published multiplayer result is claimed.

## Portable tests and their limits

Run the commands in [Contributing](../CONTRIBUTING.md) from the repository root.
The currency runner loads the actual Money module under the standalone Luau CLI.

The roaming runner loads the actual Roaming source and the same Roaming.spec used by Studio.
Lune supplies Vector3/CFrame math; JSON methods are mapped to Lune serde. Lune 0.10.5's native
lookAt mirrors the Z heading in a simple forward-vector probe. The runner substitutes an upright
yaw constructor (the only lookAt domain used by Roaming) and checks its forward convention.
This adapter is test-only. It does not replace or emulate the Roblox engine in the shipped package.

The animator runner loads the actual source with explicit mocks for events, tag membership,
deferred scheduling, and the client flag. Geometry attachment, detachment, and posing are replaced
with counters. This tests lifecycle control and configuration validation only; it says nothing
about Motor6D rendering, client skinning, physics, or real streaming ordering.

Utility scenarios use the same spec in Luau CLI and Studio. Cleanup resources are table doubles;
actual Instance/connection inference and the RemoteEvent preview example have not been run in Studio.
Timing tests use injected clocks, so expiry and rollback cases need no sleeps.

CI runs these portable checks, analysis, formatting, compilation, and builds. It also rejects committed
Studio downloads that differ from a fresh build, and uploads the validated files.

## Studio reproduction

Open the rebuilt demo in a separate Studio window. In Edit mode, run:

```lua
require(game.ServerStorage.GameplayToolkitTests.Run)(
    require(game.ReplicatedStorage.GameplayToolkit)
)
```

Tests use disposable primitive models in detached WorldModels. They do not touch player data,
purchase APIs, or a live game scene. Then press Play to inspect the three animated pets.
Manual multiplayer and representative device profiling remain separate integration work.

## Historical baseline

The 0.1.0 extraction passed 56,558 Studio assertions across Money, Roaming, and all 20 motion
kinds. Its original record is preserved in [validation-v0.1.0.json](validation-v0.1.0.json).
Those results do not establish engine correctness of the changed 0.2.0 source.
