# Roblox Gameplay Toolkit

[![Validate toolkit](https://github.com/bilalylkvn1/roblox-gameplay-toolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/bilalylkvn1/roblox-gameplay-toolkit/actions/workflows/ci.yml)

Reusable Luau systems for pet animation, bounded roaming, exact currency, request limits,
cooldowns, weighted choices, and resource cleanup.

Extracted and adapted from systems developed for **Kick an Egg**. This is a new standalone
open-source package. External adoption and performance benchmarks have not yet been established.

## Included

| Module | Purpose |
| --- | --- |
| `PetRig` | Builds Motor6D joints for named body parts, with 20 motion kinds |
| `PetAnimator` | Client animation, smooth gait changes, signature moves, turn response, and distance culling |
| `Roaming` | Server-selected curved movement inside upright, rotated rectangular bounds and a radius |
| `Money` | Exact non-negative decimal integers, including values beyond floating-point integer precision |
| `CleanupBag` | Reverse-order cleanup of callbacks, connections, and temporary objects; errors do not stop cleanup |
| `Cooldown` | Per-player or per-action cooldowns with injectable clocks and bounded key storage |
| `RateLimiter` | Token-bucket request limiting with per-key burst capacity, refill, and explicit pruning |
| `WeightedRandom` | Reusable weighted selection with original indices and probability inspection |

The package has no runtime package dependencies. The demo creates its own primitive geometry.

## Install in Studio

1. Download [GameplayToolkit.rbxmx](dist/GameplayToolkit.rbxmx) using GitHub's **Raw / Download raw file** button.
2. In Studio, right-click **ReplicatedStorage**, choose **Insert from File**, and select the file.
3. Keep the imported ModuleScript named **GameplayToolkit**, including all its children.

Alternatively, copy `src/init.luau` into a ModuleScript named GameplayToolkit, and create the
other `src/*.luau` files as its child ModuleScripts.

```lua
local Toolkit = require(game.ReplicatedStorage.GameplayToolkit)
print(Toolkit.Money.Add("9007199254740991", "10")) -- "9007199254741001"
```

## Exact rewards and prices

Keep currency as decimal strings throughout arithmetic and persistence:

```lua
local Money = require(game.ReplicatedStorage.GameplayToolkit).Money
local total = Money.Multiply("9007199254740993", "3") -- "27021597764222979"
local each, remainder = Money.Divide(total, "4") -- "6755399441055744", "3"
print(Money.FormatFull(total)) -- 27,021,597,764,222,979
```

Add and Multiply saturate at 10^18. Divide returns an exact floor quotient and remainder;
Subtract returns nil on underflow. See the [complete currency API](docs/money.md).

## Common gameplay utilities

```lua
local requests = Toolkit.RateLimiter.new({ capacity = 6, refillRate = 2 })
local kick = Toolkit.Cooldown.new({ duration = 1.5 })
-- Inside a server handler, after receiving the server-provided Player:
if not requests:Try(player) or not kick:Try(player) then return end
```

Forget player keys on PlayerRemoving and periodically Prune retained state.
[Utility APIs and examples](docs/utilities.md) cover cleanup ownership, clock rollback,
bounded memory, weighted choices, and a combined server interaction preview.

## Pet animation

On the server, clone a model with a `Root` BasePart and named `Body`, `Head`, `Leg`, `Wing`,
and similar parts. Set its PrimaryPart or let the builder use `Root`.

```lua
local Toolkit = require(game.ReplicatedStorage.GameplayToolkit)
local pet = game.ServerStorage.MyPet:Clone()
Toolkit.PetRig.Build(pet, {Kind = "Quad"})
pet.Parent = workspace
```

Start one animator in a **LocalScript**:

```lua
local Toolkit = require(game.ReplicatedStorage.GameplayToolkit)
local animator = Toolkit.PetAnimator.new()
animator:Start()
script.Destroying:Connect(function()
    animator:Stop()
end)
```

Move the model's Root with your own server movement system. Animation is client-side;
it does not award currency, determine ownership, or authorize game actions.
The builder changes joints and collision settings: use a clone of your art.
See [pet model contract and API](docs/pets.md).

## Roaming

```lua
local Roaming = require(game.ReplicatedStorage.GameplayToolkit).Roaming
local now = workspace:GetServerTimeNow()
local plan = Roaming.new({
    boundsFrame = CFrame.new(),
    boundsSize = Vector3.new(80, 1, 80),
    origin = Vector3.new(0, 2, 0),
    radius = 20,
    speed = 8,
    startsAt = now,
})
-- On a server update:
Roaming.Advance(plan, workspace:GetServerTimeNow(), playerPosition)
local position, heading = Roaming.Sample(plan, workspace:GetServerTimeNow())
-- Broadcast Roaming.Encode(plan) after changed decisions; apply trusted snapshots on clients.
```

This is open-area roaming, without obstacle pathfinding. See [roaming API](docs/roaming.md).

## Demo and tests

Open [GameplayToolkitDemo.rbxlx](dist/GameplayToolkitDemo.rbxlx) in a separate Studio window and press
**Play**. Three primitive pets demonstrate movement and animation. The demo prints an exact
large-integer addition.

In the demo's **Edit** mode Command Bar, run:

```lua
require(game.ServerStorage.GameplayToolkitTests.Run)(
    require(game.ReplicatedStorage.GameplayToolkit)
)
```

[Validation notes](docs/validation.md) distinguish engine tests, CLI tests, and unmeasured behavior.

To rebuild with [Rojo 7](https://rojo.space/docs/v7/):

```sh
rojo build default.project.json -o dist/GameplayToolkit.rbxmx
rojo build demo.project.json -o dist/GameplayToolkitDemo.rbxlx
```

For the engine-independent currency suite, use the
[Luau CLI](https://github.com/luau-lang/luau/releases):

```sh
luau scripts/money-tests.luau
luau scripts/utility-tests.luau
```

The portable movement and lifecycle regressions use [Lune 0.10.5](https://github.com/lune-org/lune/releases/tag/v0.10.5):

```sh
lune run scripts/roaming-tests.luau
lune run scripts/animator-tests.luau
```

CI compiles every Luau file, analyzes the engine-independent modules, checks StyLua formatting,
runs the four portable suites, and checks that both committed Studio downloads match a fresh
Rojo build. Validated downloads
are also available as workflow artifacts. Roblox posing, physics, and rendering still require
the separate Studio suites; Lune uses a documented math adapter and mocked lifecycle services.

## Project status

Version **0.2.0** adds four gameplay utilities, expands exact arithmetic, and hardens roaming
and animator lifecycle handling. The local portable suites pass 4,694 assertions.
Current engine changes and the new server interaction example still need a Studio run;
the recorded 0.1.0 engine results are historical evidence, not validation of 0.2.0.
See [validation and limitations](docs/validation.md) and [migration notes](CHANGELOG.md).
The original game-specific creature art, custom boss rigs, sounds, purchase systems, account
configuration, and player data are not included.

[Contributing](CONTRIBUTING.md) · [Changelog](CHANGELOG.md) · [MIT license](LICENSE)

