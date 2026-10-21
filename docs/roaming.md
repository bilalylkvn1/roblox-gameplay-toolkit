# Roaming API

`Roaming.new(options)` returns a mutable plan. Required fields are
boundsFrame (upright CFrame), boundsSize (Vector3 with positive X/Z),
and origin (finite Vector3 inside the usable rectangle).
Yaw rotations are supported. Tilted bounds are rejected.

Optional values: radius=20, speed=8, bodyHeight=2.6, edgePadding=4,
startsAt=0, expiresAt=math.huge, direction=Vector3.new(0,0,-1).
The usable half extents subtract bodyHeight * 0.395 + edgePadding. Both must stay positive:
construction rejects bounds consumed by the margin. Small valid bounds retain their actual size.
For example, a 0.8 by 0.6 region is supported with bodyHeight=0 and edgePadding=0.

- `Advance(plan, now, playerPosition, random?) -> changed`: server-side decision update.
- `Sample(plan, now) -> position, heading, travel, instantaneousSpeed`: deterministic prediction.
- `Inside(plan, point, inset?) -> boolean`: horizontal rectangular and radial containment.
- `Clamp(plan, point) -> Vector3`: clamp to the movement bounds at the origin's height.
- `Snapshot(plan) -> table`, `ApplySnapshot(plan, state) -> boolean`: plain serializable state.
- `Encode(plan) -> string`, `Decode(plan, json) -> boolean`: JSON transport convenience.

Advance at least once at or after startsAt before calling Sample or Encode.
Use the same static plan options on server and client.
The server advances decisions every 0.2 seconds; clients predict up to 0.6 seconds.
An optional random callback returns numbers in [0, 1] and makes tests reproducible.
Calling Advance with a time older than the last update returns false without changing the plan.
At and after expiresAt, Sample freezes at the final predicted position and reports zero speed.

After a pause longer than 2 seconds, Advance holds the last position and processes at most
10 catch-up decisions. This bounds synchronous work rather than simulating an arbitrarily
long absence.

ApplySnapshot rejects malformed/non-finite vectors, zero headings, positions outside bounds,
negative or decreasing travel, vectors that overflow when converted to Vector3, and timestamps
older than the current state or outside the plan's lifetime.
Failure leaves the plan unchanged.
Travel comparisons allow 0.000001 studs of JSON rounding error; accepted snapshots never reduce
the accumulated travel. Reapplying a current snapshot is safe.

In 0.2, bounds too small for the configured margin are rejected instead of silently expanded.
Reduce bodyHeight/edgePadding or enlarge the bounds when migrating a tiny region from 0.1.

Only feed clients snapshots from your trusted server. A valid movement snapshot is not proof of
ownership, eligibility for a reward, or any other gameplay permission.
No pathfinding, collision avoidance, navigation mesh, or RemoteEvent instance is included.

