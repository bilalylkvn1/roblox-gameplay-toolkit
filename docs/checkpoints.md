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
rewards. By default it accepts any tagged checkpoint. Optional stage ordering is described below. Keep
checkpoint platforms horizontal and provide clear space above them. A one-second
per-player cooldown limits rapid checkpoint changes. A character that spawns
without a saved checkpoint uses the normal spawn flow. If the saved checkpoint
changes while the root loads, the pending move is skipped. This also applies
when the platform is untagged, tagged again, and touched during that wait. The
new checkpoint applies on the next respawn.

Tags can be added or removed at runtime. Enable `CanTouch` before tagging a
platform. If a tagged platform was ignored because `CanTouch` was off, enable
it and reapply the tag to register the platform. Removing a tag forgets that checkpoint
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
if the same platform is tagged again. It also checks that a spawn without a saved checkpoint does not wait for the root.
The expected result is `32 mocked scenarios passed`.
The mocks substitute CleanupBag, Cooldown, geometry, and event delivery, so the
Studio checklist above remains required. CI runs this command automatically.

Turning off a saved platform's `CanTouch` while a character is loading cancels
that pending checkpoint move. Reapply the tag after enabling touch to restore
its handler if Roblox disconnected it.

A pending checkpoint move is skipped if the character dies or loses its Humanoid
while the root is loading. The next live character can use the saved checkpoint.

## Temporarily disabling a checkpoint

Set a platform's boolean `CheckpointEnabled` attribute to `false` to pause touch
registration and respawn moves. Set it to `true`, or remove the attribute, to
resume. Saved checkpoints are retained while disabled. A character spawning
during that time uses the normal spawn. Use this attribute for round transitions
while keeping `CanTouch` enabled and the `ToolkitCheckpoint` tag applied.

## Optional stage ordering for obbies

Set the numeric `CheckpointStage` attribute on every checkpoint in an ordered
course, using positive integers such as 1, 2, and 3. When both the saved platform
and the newly touched platform have valid stages, only a strictly higher stage
can replace the saved checkpoint. Touching an earlier stage or a second platform
with the same stage preserves progress and does not consume the touch cooldown.
The first checkpoint is accepted normally, and forward stage skips are allowed;
this is not a sequential completion or reward-validation system.

For example, set these attributes in a server setup script (the parts must
already carry the `ToolkitCheckpoint` tag):

```lua
workspace.BlueCheckpoint:SetAttribute("CheckpointStage", 1)
workspace.GreenCheckpoint:SetAttribute("CheckpointStage", 2)
```

After reaching green, touching blue does not move the saved respawn back to blue.
Stage values are read on each touch. Missing, zero, negative, fractional,
non-finite, and nonnumeric values are unordered: if either platform is unordered,
the existing last-touch behavior applies. Use valid stages on **all** course pads
to prevent backtracking. Tag removal still clears saved progress, and stage
ordering does not persist between sessions.

Portable tests cover forward, backward, equal, mixed unordered, and invalid
stages. In Studio, also verify two players independently advance blue to green,
then return to blue and reset: both should respawn at green. This engine check
has not yet been run.
