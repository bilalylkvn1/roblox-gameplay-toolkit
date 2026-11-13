# Session checkpoints example

Copy `examples/Checkpoints.server.luau` to ServerScriptService. Install GameplayToolkit
in ReplicatedStorage. Tag anchored, touchable BaseParts in Workspace with
`ToolkitCheckpoint` using Studio's Tag Editor. The last touched checkpoint becomes
the player's respawn destination. The character pivot is placed four studs above
the platform's top face by default. Set the platform's numeric
`CheckpointSpawnClearance` attribute to customize that distance. For example,
use `8` to leave extra room for a taller character. Zero is valid. Missing,
negative, non-finite, and nonnumeric values fall back to four studs.

This example uses Cooldown and CleanupBag from the 0.2.0 branch. It stores progress
only for the current server session; it does not save DataStore progress or grant
rewards. It accepts any tagged checkpoint, without enforcing stage order. Keep
checkpoint platforms horizontal and provide clear space above them. A one-second
per-player cooldown limits rapid checkpoint changes.

Tags can be added or removed at runtime. Removing a tag forgets that checkpoint
and disconnects its touch handler. Departing players are removed from all maps, and late touches cannot recreate their state.
Destroying the script cleans up its owned connections. Disable/re-enable lifecycle
is not supported; destroy and reinstall the script to stop/restart it.

## Try the checkpoint place in Studio

Download `GameplayToolkitCheckpoints.rbxlx` from a successful CI run, or build
it from the repository root with Rojo 7.7.1.

```sh
rojo build checkpoints.project.json -o GameplayToolkitCheckpoints.rbxlx
```

Open the place in Studio and start a local server with two players. The blue and
green pads already carry the `ToolkitCheckpoint` tag. Walk one player onto each
pad, then reset both characters. Each should reappear over their own pad.

## Required Studio validation (not yet run)

- With two clients, touch different platforms and reset both characters: each
  returns to its own checkpoint, with no shared progress.
- Repeated limb touches do not change other players' checkpoints.
- Remove a saved platform's tag, then reset: the normal spawn is used.
- Add/tag a new platform during play: it starts accepting touches.
- Remove a player, destroy the script, and verify handlers stop and maps release.
- With no saved checkpoint, character spawning remains unchanged.

Touched events are a convenience gameplay signal, not an anti-cheat boundary.
Add server-side stage and movement validation before using checkpoints for rewards.

## Running the portable lifecycle regressions

From the repository root with Lua 5.4 installed, run:

```sh
lua5.4 scripts/checkpoint-lifecycle-tests.lua examples/Checkpoints.server.luau
```

The harness executes the actual example source with mocked services. It checks
normal respawn, script destruction during root loading, and player departure
during root loading. It also covers root timeout, character replacement, and tag
removal while the root is loading, plus default, custom, zero, and invalid spawn
clearance. It verifies that a queued touch from a removed tag cannot save a checkpoint
if the same platform is tagged again. The expected result is `14 mocked scenarios passed`.
The mocks substitute CleanupBag, Cooldown, geometry, and event delivery, so the
Studio checklist above remains required. CI runs this command automatically.
