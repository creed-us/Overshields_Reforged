# Architecture

How Overshields Reforged is put together, and the handful of rules that keep it that way.
Read this before moving code between files.

## What the addon does

Blizzard's compact raid/party frames draw damage-absorption shields, but stop telling you
how much absorb is left once a unit is at full health. This addon hooks Blizzard's
heal-prediction update, draws its own absorb and overlay bars over the affected frames, and
hands the frames back to Blizzard untouched whenever it stops managing them.

## The pipeline

One hook fires a lot, so the work is batched rather than done inline:

```
CompactUnitFrame_UpdateHealPrediction  (Blizzard, hooked in Core.lua)
            │
            ▼
      FrameDiscovery ──► UpdateQueue ──► FrameUpdate ──► AppearanceManager
    which frames?        when to run?    what does this   how is a bar
                                         frame need?      painted?
            │                                 │
            └──────────► FrameRegistry ◄──────┘        BarLifecycle
                         what do we own?                giving frames back
```

`FrameDiscovery` finds candidate frames and queues them. `UpdateQueue` batches them onto a
single `OnUpdate` pass, with retries for frames whose health bar isn't built yet.
`FrameUpdate` decides what each frame needs — early exit, defer to Blizzard's own bars, or
draw ours. `AppearanceManager` does the painting. `FrameRegistry` tracks which frames have
bars; `BarLifecycle` restores frames to vanilla when we let go of them.

## Files

Load order below matches the TOC. Nothing here should exceed ~300 lines; if a file grows
past that, it has probably taken on a second job.

| File | Lines | The question it answers |
|---|---|---|
| `Constants.lua` | 25 | which WoW globals do we alias for speed? |
| `Instrumentation.lua` | 26 | who, if anyone, is listening to diagnostics? |
| `Utilities.lua` | 31 | is this frame safe to touch; is this setting on? |
| `BarLifecycle.lua` | 197 | how do we hand a frame back to Blizzard? |
| `Core.lua` | 58 | bootstrap, the Blizzard hook, event wiring |
| `UnitContext.lua` | 43 | is this unit party, raid, or pet? |
| `Hibernate.lua` | 121 | should we be doing anything at all right now? |
| `ShieldState.lua` | 63 | shielded, overshielded, or neither? |
| `AnchorStrategy.lua` | 37 | where does a bar sit for a given anchor mode? |
| `ProfileDefaults.lua` | 36 | what does a fresh profile look like? |
| `ProfileMigration.lua` | 61 | how does an old saved profile become a current one? |
| `GlowTextureCatalog.lua` | 58 | which glow textures do we offer? (data only) |
| `OptionsDropdowns.lua` | 79 | what goes in the texture dropdowns, incl. LibSharedMedia? |
| `Options.lua` | 301 | the AceConfig schema and database setup |
| `ChatCommands.lua` | 107 | `/osr` handling |
| `FrameRegistry.lua` | 102 | which frames have bars, and how are they released? |
| `UpdateQueue.lua` | 145 | batching, retries, and the OnUpdate driver |
| `FrameUpdate.lua` | 203 | what does this one frame need? |
| `FrameDiscovery.lua` | 129 | which frames are worth processing? |
| `AppearanceManager.lua` | 286 | how is a bar actually painted? |
| `Debug.lua` | 410 | alpha-only counters and diagnostics window |

## Rules that are easy to break by accident

### 1. Every file shares one namespace table

Each file starts `local _, ns = ...` and hangs its exports off `ns`. Because function
bodies resolve `ns.Foo` at *call* time, not load time, TOC order mostly doesn't matter —
by the time anything runs, every file has loaded.

The exceptions are statements that execute *during load*:

- **`Constants.lua` must load first.** Other files call `ns.CreateFrame(...)` at load time
  to build their frames.
- **`Instrumentation.lua` must load before `Debug.lua`.** `Debug.lua` attaches itself as
  the instrumentation sink at load time.
- **`Core.lua` must load before `Options.lua` and `ChatCommands.lua`.** Both define methods
  on the global `OvershieldsReforged`, which `Core.lua` creates via AceAddon. `Options.lua`
  has no guard and fails hard if this is violated; a test asserts the TOC order.

### 2. Alpha-only code is stripped at packaging time

Diagnostics are wrapped in `--@alpha@` / `--@end-alpha@`. The packager comments those
blocks out for non-alpha releases, so they cost nothing in a normal build — but it also
means **a local declared inside such a block cannot be referenced outside it**. That would
parse fine and then read as a nil global in release builds only. `Debug.lua` is likewise
excluded from the TOC outside alpha, and `AceGUI-3.0` (which only `Debug.lua` uses) is
gated the same way in `embeds.xml`.

### 3. Pipeline code never calls `Debug` directly

It calls `ns.Emit("eventName")`, which is a no-op unless something registered a handler.
`Debug.lua` registers one and decides how each event is recorded. Adding an event means
adding it to `Debug.lua`'s `counters` table too — an unknown event name is a nil-arithmetic
error in alpha builds. `tests/debug_sink_spec.lua` checks every emitted name against the
real sink.

### 4. Anchor modes are defined in two places on purpose

`ProfileMigration.lua` holds the user-facing *labels*; `AnchorStrategy.lua` holds the
positioning *handlers*. Presentation and behaviour legitimately live apart, but the key
sets must not drift — a label with no handler silently falls back to default positioning.
`TestAnchorModeCoverage` fails if they diverge.

## Accepted compromises

Some modules reference each other in both directions: `FrameRegistry` ↔ `UpdateQueue`,
`FrameRegistry` ↔ `BarLifecycle`, `FrameRegistry` ↔ `AppearanceManager` (via the style
cache), and `UpdateQueue` ↔ `FrameDiscovery`. These resolve at call time through the shared
namespace, so they work, and breaking them would mean dependency-injection ceremony that
isn't worth it at this size. They are known, not accidental.

`AppearanceManager.lua` is the largest file and the one most likely to need splitting next
if it grows.

## Tests

```sh
lua tests/run_tests.lua
```

See `tests/README.md` for running details. Two conventions matter when adding to the suite:

- **A spec's `FILES` list is a dependency declaration.** If the module under test calls an
  `ns.*` function defined elsewhere, that file belongs in the list — and moving a function
  between files will break the list of every spec that transitively needs it. That is the
  suite doing its job, not a nuisance.
- **Mutation-test new specs before trusting them.** Break the thing the spec is meant to
  protect, confirm it fails, and confirm the mutant still *parses* first — a file that
  doesn't compile makes every test fail and proves nothing about the assertions.
