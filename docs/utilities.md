# Gameplay utilities

These four modules have no engine or runtime package dependencies. Requiring them creates no
instances and starts no timers. All examples use `local Toolkit = require(game.ReplicatedStorage.GameplayToolkit)`.

## CleanupBag

Own a feature's connections, temporary instances, and cleanup callbacks in one place:

```lua
local bag = Toolkit.CleanupBag.new()
bag:Add(button.Activated:Connect(function() print("clicked") end))
bag:Add(temporaryModel)
bag:Add(function() print("feature closed") end)
local errors = bag:Destroy()
for _, err in ipairs(errors) do warn(err) end
```

| Method | Behavior |
| --- | --- |
| `new()` | Create an empty reusable bag |
| `Add(resource, method?)` | Return resource; infer Destroy for Instances, Disconnect for connections, or Destroy/Disconnect for tables |
| `Remove(resource)` | Remove and clean one resource; return removed boolean and optional error string |
| `Clean()` | Clean in reverse registration order; return error strings; keep bag reusable |
| `Destroy()` | Clean and permanently close; return error strings |

Functions run directly. An explicit method name such as `"Close"` overrides inference.
Register each resource once per bag. A bag cannot own itself. Prefer a single owner for each resource.
Cleanup callbacks must be synchronous and must not yield.

Errors do not stop later cleanup. Nested Clean calls are harmless. Resources added during cleanup
or after Destroy are immediately cleaned; Add then returns a second error value if cleanup failed.
Immediate errors during an active Clean are also included in its error list. No errors are logged
automatically. Clean and Destroy may be called repeatedly.

## Cooldown

Use a separate cooldown instance for each action with independent timing:

```lua
local kick = Toolkit.Cooldown.new({ duration = 1.5, maxKeys = 200 })
local allowed, retryAfter = kick:Try(player)
if not allowed then return end
-- Validate the action's other requirements, then perform it on the server.
```

`new({duration, clock?, maxKeys?})`: duration is a finite number of seconds >= 0.
The clock defaults to os.clock; inject a monotonic test clock when needed. maxKeys defaults to 1024.

| Method | Result |
| --- | --- |
| `Try(key)` | allowed boolean, remaining seconds on denial (zero on success) |
| `Remaining(key)` | Seconds remaining, without allocating a key |
| `Forget(key)` | Remove a key immediately; return whether it existed |
| `Prune()` | Remove expired keys; return removed count |
| `Clear()` | Remove every key |
| `GetSize()` | Number of stored keys, including expired keys awaiting pruning |

Rejected attempts do not extend a cooldown. Exact expiry permits the next attempt.
Zero duration permits attempts without storing keys. A clock rollback is held at the last
observed time. Invalid clock results are rejected before key storage changes.

## RateLimiter

A token bucket permits a short burst while limiting sustained request rate:

```lua
local requests = Toolkit.RateLimiter.new({ capacity = 6, refillRate = 2, maxKeys = 200 })
local allowed, retryAfter, tokensLeft = requests:Try(player) -- default cost = 1
if not allowed then return end
```

`new({capacity, refillRate, clock?, maxKeys?})`: capacity and tokens-per-second refillRate must be
positive finite numbers. Fractional tokens and costs are supported. The clock defaults to os.clock,
and maxKeys defaults to 1024.

| Method | Result |
| --- | --- |
| `Try(key, cost?)` | allowed boolean, seconds until this cost is available (zero on success), remaining tokens |
| `Peek(key)` | Available tokens without spending or allocating a bucket |
| `Forget(key)` | Remove a bucket; return whether it existed |
| `Prune()` | Remove fully refilled buckets only; return removed count |
| `Clear()` | Remove all buckets |
| `GetSize()` | Number of stored buckets |

Each new key starts full. Cost defaults to 1 and must be finite, positive, and <= capacity.
Denied attempts spend no tokens. Refill never exceeds capacity, and clock rollback grants no refill.
Pruning never forgives outstanding token debt. Forget and Clear deliberately reset debt.

## Key ownership and memory

Both timing modules accept non-nil keys (finite if numeric), including Player objects. They retain
strong references until Forget, Clear, or Prune. Use the server-provided Player as the key when
handling RemoteEvents; client-controlled identifiers can exhaust the key budget.

When full, a new key is denied with `retryAfter=math.huge` (and zero tokens for RateLimiter).
Existing keys continue to work. Peek reports the nominal full bucket for an unknown key even if
the key budget is full; Try is the admission decision. Expired/fully refilled keys are not removed
automatically: call Prune periodically on your own server loop, and Forget on PlayerRemoving.
Prune is O(stored keys); ordinary access uses table lookup. Choose maxKeys for your game's scale.

These checks limit request frequency. Eligibility, distance, inventory, balances, and persistence
must still be validated by the game's server. State is local to one server process and is not persisted.

## WeightedRandom

Build a reusable drop or variation table, then sample using server-selected randomness:

```lua
local pool = Toolkit.WeightedRandom.new({
    { value = "Common", weight = 70 },
    { value = "Rare", weight = 25 },
    { value = "Epic", weight = 5 },
})
local random = Random.new()
local value, originalIndex = pool:Pick(function() return random:NextNumber() end)
local probabilities = pool:GetProbabilities()
```

Entries must be a dense non-empty array of `{value, weight}`. Values cannot be nil. Weights must
be finite and non-negative, with at least one positive weight. Zero-weight entries are excluded.
Weights are normalized before summing to avoid overflow. Ranges too disparate to represent
positive cumulative intervals are rejected rather than silently dropping an entry.

Pick accepts a callback returning a finite number in [0,1], defaulting to math.random. It returns
the value and its original input index; exactly 1 selects the final positive-weight entry.
Selection uses binary search over cumulative weights. This is weighted sampling with replacement;
there is no pity counter, fairness guarantee for short runs, or cryptographic randomness.

GetProbabilities returns detached `{value, index, probability}` records for positive-weight entries.
Entry records and weights are copied at construction; values that are tables/Instances retain their
original reference. Do not accept a client's roll for authoritative rewards.

## Combined server example

[GuardedInteraction.server.luau](../examples/GuardedInteraction.server.luau) combines all four modules:
player-scoped request limiting, a preview cooldown, server-selected weighted variation, periodic
pruning, PlayerRemoving cleanup, and resource teardown. It sends a cosmetic preview string and
grants no game reward. The example is compiled by CI but is not inserted into the existing demo.

To try it, install the toolkit and copy the example to ServerScriptService. In a test LocalScript:

```lua
local remote = game.ReplicatedStorage:WaitForChild("ToolkitInteractionPreview")
remote.OnClientEvent:Connect(function(value) print(value) end)
remote:FireServer("RollPreview")
```

Run `luau scripts/utility-tests.luau` for portable scenarios; Studio's tests/Run also includes them.
CLI tests exercise table-based cleanup resources. Actual Instance/connection inference and the
RemoteEvent example still require an isolated Studio integration check.
