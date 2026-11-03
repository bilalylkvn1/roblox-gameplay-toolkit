# Roblox Studio validation protocol (0.2.0 release candidate)

> **Status: awaiting Studio execution.** This is a reproducible protocol and evidence template, **not** a claim that any of these engine checks have passed. The 4,694 portable assertions reported in [validation.md](validation.md) do not replace Studio verification. Do not deploy tests to a production place or use real player data.

This protocol is for contributors and game developers who want to validate the toolkit before integrating it into a live Roblox experience. Report failures as GitHub issues with a minimal, license-safe reproduction. PR #1 adds the changed modules; PR #2 adds a separate, optional checkpoint example and must be tested after its base branch.

## 1. Capture the environment

Record before testing:

- Git commit SHA, branch or release tag (the candidate must include PR #1 changes).
- Roblox Studio version, operating system, and test date.
- Server/client test mode, player count, streaming settings, graphics quality, and test device.
- Any extra models, plugins, or scripts used in the test place. Prefer a new, unmodified place.

For portable checks use the versions listed in [CONTRIBUTING.md](../CONTRIBUTING.md). Record portable results separately from all Studio results.

## 2. Reproduce the existing Studio suites

1. Use a **separate Studio window/place**, not a published production experience.
2. Build `dist/GameplayToolkitDemo.rbxlx` from the candidate branch with `rojo build demo.project.json -o dist/GameplayToolkitDemo.rbxlx`, or download the CI artifact for the exact candidate commit. Do not test the older file from `main` by mistake.
3. Open that demo in Studio **Edit** mode.
4. In **View > Command Bar**, execute:

```lua
local results = require(game.ServerStorage.GameplayToolkitTests.Run)(
    require(game.ReplicatedStorage.GameplayToolkit)
)
print("Studio suite result:", results.total, "assertions", results)
```

5. Save the **full Output log**, the returned per-suite counts, and the candidate SHA. On an assertion failure, record the suite name, error and stack trace; the runner stops at the first failure.
6. Press **Play** to inspect the three primitive demo pets. The Edit-mode assertions alone do not establish on-screen animation, player networking, or physics correctness.

**Pass gate:** every suite in `tests/Run.luau` completes without errors: Money, Utilities, Roaming, and Pets. Do not copy historical 0.1.0 results into the 0.2.0 record.

## 3. Manual engine integration matrix

Use a new disposable place for each isolated scenario. Record **pass / fail / not run** for every item. A pass means the observations actually happened in Studio, not merely that the code compiled.

| ID | Scenario | Reproduction | Pass condition |
| --- | --- | --- | --- |
| E1 | CleanupBag with real Instances | Create a temporary Part, add it to a new bag, destroy the bag twice | Part is destroyed; repeated cleanup is harmless; returned errors are empty |
| E2 | CleanupBag with real RBXScriptConnections | Connect a BindableEvent, register its connection, fire, destroy bag, fire again | Handler fires before teardown and never after; no leaked connection remains |
| E3 | PetRig and PetAnimator presentation | Start the demo in Play mode, check all three primitive pets and their state changes | No broken joints, invalid transforms, frozen poses, or unexpected collisions |
| E4 | Attach/detach/streaming lifecycle | Repeatedly add/remove tagged pets, stream them out and back in when applicable, restart the animator | No duplicates, stale callbacks, orphaned rigs or missing animations after recovery |
| E5 | Roaming geometry and snapshots | Run upright, rotated, near-edge, and explicitly tiny eligible bounds; send server snapshots to a test client | Samples remain within configured usable bounds; client prediction stays coherent after updates |
| E6 | RemoteEvent integration | Copy `examples/GuardedInteraction.server.luau` into ServerScriptService, use two test clients, send `RollPreview` bursts | Only the requesting client gets a cosmetic response; server enforces rate/cooldown; no reward is granted |
| E7 | Departure and teardown | Disconnect/rejoin a test player; remove the guarded example Script and verify its RemoteEvent is removed | Player state is forgotten, fresh sessions behave as documented, and preview resources/connections are cleaned |
| E8 | Multi-client isolation | Run a local server with at least two clients and test near-simultaneous requests | One player's cooldown/limits do not consume the other player's budget; no cross-client response leaks |
| E9 | Device/performance smoke test | Run a representative number of pets on a low-spec device or Studio device emulator; inspect MicroProfiler/Stats | Record observed frame rate, frame-time and memory; do not claim a benchmark or target without actual measurements |
| E10 | Optional checkpoint example (PR #2 only) | Install its tagged parts and script, activate checkpoint, respawn, remove tags, leave/rejoin | Session-only respawn is correct; tag removal and disconnect clean state; no unintended persistence/reward |

### Minimal real-object cleanup probe (Edit-mode Command Bar)

This probe supplements `Utilities.spec.luau`, which uses table doubles. It does **not** cover E3–E10. Run it with the candidate module installed under ReplicatedStorage:

```lua
local Toolkit = require(game.ReplicatedStorage.GameplayToolkit)
local bag = Toolkit.CleanupBag.new()
local part = Instance.new("Part")
part.Name = "ToolkitCleanupProbe"
part.Parent = workspace
local event = Instance.new("BindableEvent")
local calls = 0
local connection = event.Event:Connect(function()
    calls += 1
end)
bag:Add(part)
bag:Add(connection)
event:Fire()
assert(calls == 1, "connected handler did not fire once")
local errors = bag:Destroy()
assert(#errors == 0, "cleanup reported errors")
assert(part.Parent == nil, "temporary part not removed")
assert(not connection.Connected, "event connection is still live")
event:Fire()
assert(calls == 1, "handler fired after cleanup")
assert(#bag:Destroy() == 0, "repeated destroy returned errors")
event:Destroy()
print("CleanupBag real Instance/connection probe: PASS")
```

This probe does not test callback reentrancy or network cleanup. Do not use its output as evidence for those scenarios.

## 4. Submit an evidence record

Copy the following to an issue or pull-request comment. Avoid personal data, private games, credentials, and unlicensed asset uploads.

```text
Repository/PR:
Candidate commit SHA:
Tester / GitHub username (optional):
Date / Studio version / OS:
Mode: Edit suite / Play / local server / device
Player count / StreamingEnabled:
Studio suites: Money=__, Utilities=__, Roaming=__, Pets=__, total=__
Engine probe: E1=__, E2=__, E3=__, E4=__, E5=__, E6=__, E7=__, E8=__, E9=__, E10=__
Observed results and reproduction steps:
Output / errors / stack traces (sanitized):
Performance observation (device, pet count, fps/frame-time/memory):
Test limitations / untested paths:
```

Mark **not run**, not **pass**, for inaccessible devices or scenarios. A reproduction should identify the smallest affected module and exact steps to trigger the issue.

## 5. Release gate

Before marking PR #1 ready or publishing a version intended for general use:

- [ ] Studio suites run on the exact changed commit, with complete output and recorded counts.
- [ ] E1–E8 have passing evidence, or unresolved failures are fixed and re-tested.
- [ ] E9 has actual measured results with the test conditions documented; no invented performance claims.
- [ ] Rebuilt `dist` artifacts match the candidate and CI checks pass.
- [ ] README, CHANGELOG and validation JSON state the verified version and **separate** CLI/Lune/Studio claims.
- [ ] E10 is checked against PR #2's own commit before that example leaves draft.
- [ ] Any remaining limitations are documented clearly instead of being presented as guarantees.

Community verification is welcome, but a tester's reported result is not independently reproduced until a maintainer verifies it. An open PR and a portable assertion count are not evidence of external adoption.
