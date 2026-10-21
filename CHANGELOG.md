# Changelog

## 0.2.0 — 2026-10-21

- Add exact saturated Money.Multiply, quotient/remainder Money.Divide, and Money.FormatFull.
- Fix tiny roaming bounds expanding outside their physical rectangle; reject margins with no usable area.
- Reject overflowing snapshot vectors and decreasing travel; ignore backwards Advance clocks.
- Report zero instantaneous speed after roaming expiry.
- Cancel and coalesce deferred animator attachments across tag removal and stop/restart.
- Skip incomplete streamed Motor6D endpoints and validate/copy custom action configuration.
- Run the shared roaming spec through a documented Lune math/JSON adapter in CI.
- Add mocked animator lifecycle checks, formatting checks, artifact freshness checks, and contribution templates.
- Rebuild the installable module and demo. Updated Roblox engine suites require a separate Studio run.

## 0.1.0 — 2026-10-21

- Extract procedural part-based pet rigging and client animation into reusable modules.
- Add configurable motion kind, collection tag, and per-name action options.
- Remove game-specific creature mappings, event dependencies, and custom boss art branches.
- Extract bounded curved roaming with validated snapshots and bounded catch-up.
- Preserve exact decimal currency arithmetic and fix saturation for a 41-digit carry.
- Add an asset-free demo, Studio engine suites, CLI currency checks, and Rojo project files.

