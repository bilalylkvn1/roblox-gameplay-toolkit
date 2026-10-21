# Roblox Gameplay Toolkit

Reusable Luau systems for procedural pet animation, bounded roaming, and exact integer currency.

Extracted and adapted from systems developed for **Kick an Egg**. This is a new standalone
open-source package. External adoption and performance benchmarks have not yet been established.

## Included

| Module | Purpose |
| --- | --- |
| `PetRig` | Builds Motor6D joints for named body parts, with 20 motion kinds |
| `PetAnimator` | Client animation, smooth gait changes, signature moves, turn response, and distance culling |
| `Roaming` | Server-selected curved movement inside upright, rotated rectangular bounds and a radius |
| `Money` | Exact non-negative decimal integers, including values beyond floating-point integer precision |

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
```

CI compiles the Luau files, runs the currency suite, and rebuilds the Studio artifacts.
Roblox engine behavior is verified separately in Studio.

## Project status

Version **0.1.0** is an initial extraction with a documented model contract.
The original game-specific creature art, custom boss rigs, sounds, purchase systems, account
configuration, and player data are not included.

[Contributing](CONTRIBUTING.md) · [Changelog](CHANGELOG.md) · [MIT license](LICENSE)

