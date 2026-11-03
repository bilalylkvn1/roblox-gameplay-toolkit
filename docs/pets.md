# Pet model contract

## Builder

`PetRig.Build(model, options?) -> boolean` builds a rig once; a repeat call at the same rig version
returns false. The model needs a `Root` BasePart (or PrimaryPart) and body geometry.
The builder assigns PrimaryPart when it uses Root, anchors Root, disables collisions, creates
an AnimationRig folder, and tags the model.

Options:

| Key | Default | Meaning |
| --- | --- | --- |
| Kind | inferred | Motion kind; explicit selection is recommended |
| Tag | GameplayToolkitPet | CollectionService tag shared with the animator |
| Species | nil | Optional display-name-to-kind lookup table |
| WingRanges | one group per side | Array of index ranges for multiple wing sets |

Motion kinds:
`Hop, Turtle, Bird, Insect, Fairy, Float, Biped, Crab, Slither, SkySerpent, Octopus, Jellyfish,
Swim, Seal, Crawl, Bat, Dragon, WingedQuad, Lizard, Quad`.

Recognized geometry names include Body/Torso/Thorax, Head, FrontLeg/BackLeg/Leg, Arm, Wing,
Tail/TailSeg/FishTail, Tentacle/OralArm, Fin/Flipper, Ear, and Eye.
Unjointed decorative pieces are welded to a nearby matching body part.
Multiple Body parts form a spine for Slither and SkySerpent.

This is a naming convention for modular parts, not a general-purpose mesh auto-rigger.
Skinned meshes, imported bone animation, custom boss rigs, and arbitrary imported skeletons
are outside the initial package contract.

## Animator

`PetAnimator.new(options?)` creates a dormant animator.
`Start()` must be called in a LocalScript. `Stop()` disconnects listeners and restores registered
models. `Attach(model)`, `Detach(model)`, `SetState(model, state)`, and `Step(dt)` support explicit
lifecycle control; `Pose` is a low-level method used by the engine tests.

Options: `Tag` (must match the builder), `ClientSkinning` (default true),
`WorldRoot` (default workspace; WorldModel is useful for isolated tests),
`ActionsByName` (optional action lists by model display name).

Action entries are `{name, durationSeconds, mode}`, where mode is idle, fly, or any.
Use positive finite durations. Default actions include Stretch, Jump, Shake, Barrel, Loop,
Preen, Twirl, Spin, Coil, Wave, and other motion-kind-specific actions.
Invalid durations, empty names, and unknown modes fail during construction. Action lists are
copied and frozen, so later edits to the caller's options do not change an existing animator.
Pass an empty list for a model name to disable its signature actions.

Start is idempotent. Stop cancels queued streaming/tag attachments as well as active listeners;
an old deferred callback cannot reattach a model after a stop/restart. Tag removal cancels pending
attachment. Incomplete Motor6D endpoints are skipped until another streaming notification arrives.

Set `PetAnimationState` to Idle, Walk, or Fly, or clear it for automatic movement detection.
A non-flying kind rejects a forced Fly state through SetState.
Set `PetAnimationEnabled=false` to pause in the neutral pose.
Optional `PetWanderTarget` (Vector3) adds looking and turning response.
Optional `PetMotionProfile`: Heavy, Graceful, Coiled, or SlowWings.

Viewport models can use `PetViewport=true` and manual Attach / Step calls.
Client skinning is disabled for that presentation mode.

The client skinning path temporarily anchors parts and disables joints to move visual geometry
in batches. Detach and Stop restore those flags. Do not run two animators on the same model.
Models should be visually scaled before attachment. Detach and attach again after changing
scale or topology.

Root motion, collision gameplay, replication policy, and ownership checks belong to the
integrating game. Rendering thresholds are heuristics; no cross-device performance claim is made.

