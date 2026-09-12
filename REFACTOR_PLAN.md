# Refactor Plan: The Frame Update Pipeline & Options Layer

**Audience:** an executing model (or contributor) that will run this plan one stage at a
time, possibly in separate sessions with no memory of this planning conversation.
**Status:** planning only. No production code has been moved as part of this document.
**Written against:** commit state as of 2026-09-11 (immediately after the dead-code sweep
that removed `ns.RestoreAllFramesToVanilla`, the dead `anchorShieldToHealth` branch, the
unreachable `C_Timer` fallbacks, and alpha-gated the `AceGUI-3.0` embed).

---

## 0. Why this, and why now

Two files carry most of the addon's real complexity and have absorbed every new feature
for a year without ever being split up:

| File | Lines | Distinct concerns tangled together |
|---|---|---|
| `CompactUnitFrame.lua` | 439 | bar creation/pooling, update batching + retry scheduling, per-frame decision logic (native-vs-custom, anchor mode), cache lifecycle/cleanup |
| `AppearanceManager.lua` | 466 | style-state caching, color/texture/blend application, frame-pool iteration/discovery, the top-level "refresh everything" entrypoint |
| `Options.lua` | 509 | AceDB defaults + profile migration, anchor-mode validation, a 50-entry inline texture data table, dropdown-value builders, the AceConfig options schema |

None of these files do one thing. `CompactUnitFrame.lua` and `AppearanceManager.lua`
together implement one pipeline — *find frames → decide what state each is in → paint
it* — but the three stages of that pipeline are interleaved rather than separated, and a
fourth concern (bar/cache *lifecycle*) is smeared across both files and part of
`Utilities.lua`. `Options.lua` mixes a UI schema with unrelated data and migration logic
that happens to be needed by that schema.

This plan splits both problems into one cohesive module per concern, in small stages,
each independently revertable, each leaving the addon loadable and (from Stage 0 onward)
covered by unit tests that must stay green.

**Decisions already made for this plan (do not re-litigate without asking the user):**
1. Scope: frame update pipeline first (Phase 1), options/config layer second (Phase 2).
2. Verification: introduce a headless Lua test harness (no WoW client needed) as the
   primary "is this still green" signal, backed by manual in-game smoke checks for things
   the harness can't see (actual rendering).
3. This is *not* required to be a byte-for-byte behavior-preserving move. Small,
   opportunistic fixes are allowed mid-stage, but **every one must be called out by name
   in that stage's commit message and in the stage's checklist below** — a reviewer must
   be able to tell "moved code" apart from "changed code" without reading a diff twice.
4. The `--@alpha@ ns.Debug.Inc(...) --@end-alpha@` instrumentation calls threaded through
   the pipeline (36 call sites across 4 files, enumerated in Stage 6) get decoupled as
   part of this refactor, not left for later.

---

## 1. Standing rules (read this before every stage, not just once)

### 1.1 Re-verify before you touch anything

This document cites function names, line numbers, and call counts **as they existed when
it was written**. Earlier stages in this same plan will change all of that for later
stages. Before starting stage *N*:

1. Re-run the grep/read commands that stage's "Preconditions" section lists, against the
   *current* repository — not against what this document says the repository looks like.
2. If what you find matches this document, proceed.
3. If it doesn't match — a function was renamed, a line moved, a file already doesn't
   exist — **stop and reconcile before editing.** Do not guess which version is right.
   Either a previous stage was done differently than planned (update this document to
   match reality before continuing) or something else changed the file (find out what
   before proceeding).

This is the "fresh-context review" the plan is required to support: every stage boundary
is a checkpoint where assumptions get re-derived from the actual code, not carried forward
on trust.

### 1.2 Definition of "green"

Every stage below ends with "Verify (see §1.2)". That means all of the following:

- **G1 — Tests pass.** `lua tests/run_tests.lua` (introduced in Stage 0) exits 0.
- **G2 — TOC integrity.** Every file listed in `Overshields_Reforged.toc` exists on disk,
  and no `.lua` file that should be loaded is missing from it. (`git diff` on the `.toc`
  should be the only place file lists change; check it by eye every stage.)
- **G3 — Syntax-clean.** Every `.lua` file in the repo root and under `tests/` parses.
  CI enforces this automatically (see the syntax-check step in `test.yml`); locally,
  `luac -p <files>` does the same in one shot.
- **G4 — CI is green.** The GitHub Actions check introduced in Stage 0 passes on the
  commit/PR.
- **G5 — In-game smoke check.** Each stage lists a specific, short manual check. Run it in
  a live client. `/console scriptErrors 1` should be on; zero Lua errors during the check.
- **G6 — Diff matches intent.** `git diff --stat` for the stage's commit touches only the
  files that stage says it will touch, plus the `.toc` if a file was added/removed/moved.

### 1.3 Git workflow

- One branch for the whole effort: `refactor/frame-pipeline-and-options`.
- One commit per stage. Commit message states which functions moved, from where, to
  where, and lists any opportunistic fix by name (per decision #3 above).
- Open a PR after Stage 0 (harness) lands, then again after Phase 1 (Stage 6) completes,
  and again after Phase 2 (Stage 10) completes — three review points, not eleven. Adjust
  if the user prefers otherwise; this isn't fixed by anything they've said, just a
  reasonable default.

### 1.4 The one real load-order constraint

Every file in this codebase uses `local _, ns = ...` and then either defines
`function ns.Foo(...)` (body runs later, at call time) or does work inside an event
callback (also runs later). **TOC order essentially does not matter** for those, because
`ns` is a single shared table and by the time any function actually *executes*, every file
has already loaded and populated it.

There are exactly two kinds of exception, and only one applies here:
- Immediate top-level statements that call an `ns.*` function *during file load itself*
  (e.g. `local batchFrame = ns.CreateFrame(...)` at the top of the old
  `CompactUnitFrame.lua`). These need `Constants.lua` (which defines `ns.CreateFrame`
  etc.) loaded first. It already is, and stays first through every stage in this plan.
- Stage 6 introduces one new immediate top-level call: `Debug.lua` will call
  `ns.SetInstrumentationHandler(...)` at load time. This needs `Instrumentation.lua`
  (Stage 6) loaded before `Debug.lua`. Since `Debug.lua` is already the last file in the
  TOC (wrapped in `#@alpha@`), and `Instrumentation.lua` will be the second file loaded,
  this is satisfied automatically — just don't move `Debug.lua` earlier or
  `Instrumentation.lua` later than described.

Beyond those two points, don't spend time worrying about TOC order; place new files near
the other files in their concern group for human readability, not because load order
demands it.

---

## Phase 0 — Safety net

### Stage 0: Headless test harness + characterization tests for existing pure-logic modules

**Goal:** make "green" mean something before any production code moves.

**Preconditions to verify:**
- No `tests/` directory exists yet (`ls` the repo root).
- Confirm current pure-logic files and their public surface (re-read, don't trust the
  summary): `UnitContext.lua` (`ns.GetUnitContext`, `ns.IsUnitContextEnabledFromProfile`),
  `ShieldState.lua` (`ns.ResolveShieldState`, `ns.ResolveAnchorMode`,
  `ns.ShouldUseNativeVisualOnly`, `ns.NormalizeAnchorMode`), `AnchorStrategy.lua`
  (`ns.ApplyAnchorStrategy` + the `anchorHandlers` table keys:
  `health_left`/`health_right`/`frame_left`/`frame_right`/`default`), `Utilities.lua`
  (`ns.FrameIsForbidden`, `ns.IsSettingEnabled`, `ns.IsAtlasAsset`, `ns.WipeAtlasCache`).

**What to build (no production files change):**
1. `tests/lib/luaunit.lua` — vendor the single-file BSD-licensed
   [luaunit](https://github.com/bluebird75/luaunit) framework. Add `tests/*` to
   `.pkgmeta`'s `ignore:` list (the whole directory — specs, stubs, mocks, and the
   runner, not just this file — must never ship in the CurseForge zip) and do **not**
   add anything under `tests/` to the TOC (none of it is ever loaded by WoW, only by the
   standalone test runner under plain Lua).
2. `tests/support/wow_stub.lua` — sets WoW-only globals that pure-logic modules read at
   load time or call at runtime, so the modules can be `loadfile`d under vanilla Lua.
   Minimum viable set for Phase 0 + Phase 1's modules: `CreateFrame`, `UnitExists`,
   `UnitGetTotalAbsorbs`, `GetTime`, `IsInRaid`, `IsInGroup`, `C_Timer` (`After`,
   `NewTicker`), `C_Texture` (`GetAtlasInfo`), `hooksecurefunc`, `wipe`, `next`. Expand
   this file in later stages only if a new module needs a WoW global it doesn't already
   stub — don't front-load stubs nothing uses yet.
3. `tests/support/load_addon.lua` — a tiny loader:
   ```lua
   local function LoadIntoNamespace(ns, path)
       local chunk = assert(loadfile(path))
       return chunk("OvershieldsReforged", ns)
   end
   ```
   Test files build up exactly the subset of real addon files a module needs (e.g. the
   `ShieldState` spec loads `Constants.lua` then `ShieldState.lua` into a fresh `ns`
   table) — this exercises the *real* production files, not copies.
4. `tests/support/mock_frame.lua` — a factory returning recorder-style fake frames/bars:
   every setter call appends to a `.calls` list and updates tracked state (e.g. `SetPoint`
   records the anchor args, `SetReverseFill` records the flag, `Show`/`Hide`/`IsShown`
   track a boolean). Build only the methods the modules under test actually call — check
   by reading each module before deciding the mock's shape, don't guess a generic API.
5. `tests/run_tests.lua` — adds `tests/lib` and `tests/support` to `package.path`, requires
   luaunit, requires each spec, exits with luaunit's status code. Specs are listed
   explicitly in a `SPECS` table rather than auto-discovered: plain Lua has no portable
   directory listing, and `io.popen("ls"/"dir")` would differ between the Windows dev
   machine and the Linux CI runner. Adding a spec means adding a line to that list.
6. Characterization tests (write these against the **current**, unmoved code — they pin
   today's behavior so later stages can prove they didn't change it):
   - `tests/unitcontext_spec.lua` — `GetUnitContext` for every prefix
     (`"raidpet1"`, `"partypet1"`, `"raid3"`, `"party2"`, `"player"`, `nil`) and
     `IsUnitContextEnabledFromProfile` for each context with enable flags on/off.
   - `tests/shieldstate_spec.lua` — `ResolveShieldState` (glow visible / native absorb
     shown / native overlay shown / neither), `ResolveAnchorMode`,
     `ShouldUseNativeVisualOnly`, `NormalizeAnchorMode` (valid modes, invalid mode,
     health-mode without a texture).
   - `tests/anchorstrategy_spec.lua` — `ApplyAnchorStrategy` against a mock bar for each
     of the five modes, asserting the right `SetPoint`/`SetReverseFill` calls happened.
   - `tests/utilities_spec.lua` — `FrameIsForbidden` (nil, non-table, forbidden frame,
     normal frame), `IsSettingEnabled` (`true`/`false`/`nil`), `IsAtlasAsset`/
     `WipeAtlasCache` (with a stub `C_Texture.GetAtlasInfo` returning true/nil, and
     confirming the cache is actually consulted — call twice, assert the stub was hit
     once).
7. `.github/workflows/test.yml` — new workflow (separate from `release.yml`), triggers on
   `push` and `pull_request`, installs Lua 5.1 (e.g. `leafo/gh-actions-lua`, or manual
   `apt-get install lua5.1`), runs `lua5.1 tests/run_tests.lua`.

**Known limitation to record, not solve here:** `Hibernate.lua`'s decision function
(`ComputeAutoHibernateState`) is a local, not exported — it can only be exercised through
the public surface (`ns.EvaluateHibernation()` + reading `ns.hibernating` afterward), which
requires faking `OvershieldsReforged.db.profile` and the group-state globals. Write that
test only if it's cheap; otherwise note it as a gap in the test file's header comment and
move on — don't let one hard-to-test function block the whole stage.

**Dev environment note:** these modules don't use any Lua-5.1-specific syntax (no bitwise
ops, no goto), so the tests will also run fine under Lua 5.3/5.4 if 5.1 isn't installed
locally. Match 5.1 in CI regardless, since that's what the WoW client actually embeds.

**Verify (see §1.2):** G1–G4 apply (there's no production code to smoke-test yet, so G5 is
N/A this stage only). Confirm `lua tests/run_tests.lua` reports all specs passing, and that
the new GitHub Actions check appears and goes green on the commit.

#### Stage 0 status: DONE (2026-09-11)

Shipped: `tests/lib/luaunit.lua` (LuaUnit 3.4), `tests/support/{wow_stub,load_addon,mock_frame}.lua`,
`tests/run_tests.lua`, four specs (`unitcontext`, `shieldstate`, `anchorstrategy`,
`utilities`) totalling **54 passing tests**, `tests/README.md`,
`.github/workflows/test.yml`, and `tests/*` + `REFACTOR_PLAN.md` added to `.pkgmeta`'s
`ignore:` list. No production `.lua` file was modified.

Deviations from the stage as originally written, all deliberate:
- LuaUnit is BSD-licensed, not MIT (corrected above).
- Specs are listed explicitly instead of auto-discovered (reason recorded above).
- `tests/README.md` was added (not in the original stage list) to document how to run the
  suite on this machine.
- `.github/workflows/test.yml` gained a **syntax-check step** beyond what the stage
  called for: it `loadfile`s every `.lua` file in the repo root and under `tests/`. The
  suite alone only parses the files its specs happen to load, which leaves most of the
  addon unchecked — and Phase 1 creates and splits files constantly, exactly when a typo
  would otherwise sit undetected until an in-game load. This makes G3 automatic rather
  than a manual per-stage chore.

**Local interpreter:** Lua for Windows (5.1.5) is installed at
`C:\Program Files (x86)\Lua\5.1\lua.exe` — the same major version the client embeds and
the same one CI pins, so local runs and CI now agree exactly. Run from the repo root with
`lua tests/run_tests.lua`. If a shell that predates the install can't find `lua`, it's
carrying a stale `PATH`; open a new terminal or use the full path. `luac.exe` sits
alongside it, so `luac -p <files>` is available for a quick parse check.

**The suite was mutation-tested**, not just run: copies of `UnitContext.lua` and
`AnchorStrategy.lua` were deliberately broken in a scratch directory (pet classification
changed, a fill direction flipped) and the suite produced 7 failures pinpointing both.
Do this again after writing each stage's new specs — a characterization test that passes
against broken code protects nothing, and the whole plan leans on these tests being real.

---

## Phase 1 — Frame update pipeline

Target decomposition of `CompactUnitFrame.lua` + `AppearanceManager.lua` (2486 combined
lines → the same logic across ~7 focused modules of roughly 60–250 lines each):

```
Discovery  → Queue → Update (orchestration) → AppearanceManager (styling) → BarLifecycle (reset/release)
                                                                                  ↑
                                                                          FrameRegistry (tracking)
```

| New/changed file | Concern | Sourced from |
|---|---|---|
| `BarLifecycle.lua` (new) | reset a bar/frame to vanilla state, release custom bars | `Utilities.lua` |
| `FrameRegistry.lua` (new) | which frames/bars are tracked; bulk release; stale-entry cleanup | `CompactUnitFrame.lua` |
| `UpdateQueue.lua` (new) | batching, retry counting, the `OnUpdate` loop, the public `QueueCompactUnitFrameUpdate` API | `CompactUnitFrame.lua` |
| `FrameUpdate.lua` (new, replaces `CompactUnitFrame.lua`) | per-frame decision logic: is this frame known, native-only-vs-custom, anchor updates | `CompactUnitFrame.lua` |
| `FrameDiscovery.lua` (new) | walk frame pools, classify shown/hidden, the top-level "refresh everything" entrypoint | `AppearanceManager.lua` |
| `AppearanceManager.lua` (trimmed, stays) | style-state caching, color/texture/blend application | itself, minus the above |
| `Instrumentation.lua` (new, Stage 6) | generic event emission, decoupling pipeline code from `Debug.lua`'s API | new |

### Stage 1: Extract `BarLifecycle.lua` from `Utilities.lua`

**Preconditions to verify:** re-read `Utilities.lua` in full and confirm it still contains,
in this order: `ns.VanillaDefaults` (table), `ns.FrameIsForbidden`, `ns.IsSettingEnabled`,
the atlas cache (`ns.IsAtlasAsset`, `ns.WipeAtlasCache`), a local `ResetCustomBar`,
`ns.HideCustomBars`, a local `RestoreRegionToVanilla`, `ns.RestoreNativeAbsorbVisuals`,
`ns.ReleaseFrame`, `ns.IsGlowVisible`. (226 lines total as of this writing.) Confirm no
other file defines a same-named local that would collide.

**Tests required before this stage starts:** none of the functions being moved have tests
yet (Stage 0 only covered `FrameIsForbidden`/`IsSettingEnabled`/atlas cache, which are
**not** moving). Before moving anything, add:
- `tests/barlifecycle_spec.lua` (name it for the *destination* file even though the code
  hasn't moved yet) — covering `ReleaseFrame`, `HideCustomBars`,
  `RestoreNativeAbsorbVisuals`, `IsGlowVisible` against mock frames/bars built with Stage
  0's `mock_frame.lua`. Load these functions from the **current** `Utilities.lua` (they
  haven't moved yet at test-writing time). Confirm green.

**Move:**
1. Create `BarLifecycle.lua` containing exactly: `ns.VanillaDefaults`, `ResetCustomBar`
   (local), `ns.HideCustomBars`, `RestoreRegionToVanilla` (local),
   `ns.RestoreNativeAbsorbVisuals`, `ns.ReleaseFrame`, `ns.IsGlowVisible`. Leave
   `ns.FrameIsForbidden`, `ns.IsSettingEnabled`, and the atlas cache functions in
   `Utilities.lua`.
2. Update `Overshields_Reforged.toc`: insert `BarLifecycle.lua` immediately after
   `Utilities.lua`.
3. Update `tests/barlifecycle_spec.lua`'s load list to load `BarLifecycle.lua` instead of
   `Utilities.lua` (it will still need `Constants.lua` and `Utilities.lua` loaded first,
   since `ns.FrameIsForbidden` and `ns.wipe` are called at runtime from the moved code).
4. Re-read `Hibernate.lua` and grep the whole repo for `RestoreNativeAbsorbVisuals\|ReleaseFrame\|HideCustomBars\|IsGlowVisible\|VanillaDefaults` to confirm every caller still resolves correctly (they all go through `ns.*`, so they should — this grep is a sanity check, not an expectation of needed edits).

**Verify (see §1.2).** G5 specifically: `/reload`, get a shield/absorb on a party or raid
member (or yourself if solo-testable via a shield spell), confirm the custom bar still
renders and that toggling the frame-scope checkboxes off/on in Options still cleanly
releases and restores it.

#### Stage 1 status: DONE — all of G1–G6 verified, G5 confirmed in-game (2026-09-11)

`BarLifecycle.lua` (196 lines) now holds `VanillaDefaults`, `ResetCustomBar`,
`HideCustomBars`, `RestoreRegionToVanilla`, `RestoreNativeAbsorbVisuals`, `ReleaseFrame`,
and `IsGlowVisible`. `Utilities.lua` is down to 31 lines (`FrameIsForbidden`,
`IsSettingEnabled`, the atlas cache). TOC updated. No caller needed editing — every one
goes through `ns.*`.

The move was done by extracting line ranges verbatim rather than retyping, then diffing
the before/after line sets to prove nothing was added, lost, or altered.

Tests: `tests/barlifecycle_spec.lua` (22 tests) was written first against the code in its
old home, confirmed green, then mutation-tested (3 mutations → 6 targeted failures) before
the move was attempted. Suite is 76 passing.

Three things worth knowing for later stages:
- **The harness caught a real coupling.** `ShieldState.lua` calls `ns.IsGlowVisible`, so
  moving that function broke `shieldstate_spec` until `BarLifecycle.lua` was added to its
  FILES list. Production was never at risk (all files share one `ns`, resolved at call
  time) — but it means **a spec's FILES list is a dependency declaration**, and moving a
  function between files will break the FILES list of every spec that transitively needs
  it. Expect this each stage; it's a feature, not a nuisance.
- **Test class names are globals.** luaunit collects globals, so two spec files declaring
  `TestVanillaDefaults` would silently drop one set from the run. Keep class names unique
  across spec files; when a function moves, move its test class with it rather than
  duplicating.
- Incidental fix: `BarLifecycle.lua` got a trailing newline that `Utilities.lua` never had.

G5 was run in the client by the maintainer and passed.

### Stage 2: Extract `FrameRegistry.lua` from `CompactUnitFrame.lua`

**Preconditions to verify:** re-read `CompactUnitFrame.lua` and confirm it still contains
(current line numbers, re-derive them): the `containers`/`overlayContainers`/`retryCount`
locals, `ns.absorbCache`/`ns.overlayCache` exports, a local `GetOrCreate(cache, frame,
levelOffset)`, `ns.ReleaseAllBars`, `ns.CleanupStaleCacheEntries`, and a `cleanupEventFrame`
event frame registered for `PLAYER_ENTERING_WORLD`/`GROUP_ROSTER_UPDATE`.

**Tests required before this stage starts:**
- `tests/frameregistry_spec.lua` covering `GetOrCreate`-equivalent behavior (returns the
  same bar on a second call for the same frame; returns `nil` when `frame.healthBar` is
  nil), `ReleaseAllBars` (clears both caches, calls release on every previously-cached
  frame), `CleanupStaleCacheEntries` (removes entries for frames that are hidden or lack
  `displayedUnit`, leaves others). Write against the current code, confirm green.

**Move:**
1. Create `FrameRegistry.lua` containing: the two cache tables (rename the locals however
   reads best, e.g. keep `containers`/`overlayContainers`), `ns.absorbCache`/
   `ns.overlayCache`, `GetOrCreate` — **export it** as `ns.GetOrCreateBar` since
   `FrameUpdate.lua` (Stage 4) will need to call it across a file boundary — 
   `ns.ReleaseAllBars`, `ns.CleanupStaleCacheEntries`, `cleanupEventFrame` and its wiring.
2. `CompactUnitFrame.lua` (still shrinking, not yet deleted): remove everything moved;
   replace internal calls to local `GetOrCreate(...)` with `ns.GetOrCreateBar(...)`.
3. TOC: insert `FrameRegistry.lua` — placement doesn't matter for load order (§1.4), put
   it near where `CompactUnitFrame.lua` currently sits for readability.
4. Note: `updateQueue`, `retryCount`, `MAX_RETRIES`, and the `batchFrame`/`OnUpdate` loop
   stay in `CompactUnitFrame.lua` for now — those are Stage 3's concern, not this one's.
   Don't move them early even though they're adjacent in the current file.

**Verify (see §1.2).** G5: join a group, confirm shields still appear on party/raid
frames; leave the group (or toggle a scope off) and confirm `CleanupStaleCacheEntries`
still runs on `GROUP_ROSTER_UPDATE` without errors.

#### Stage 2 status: DONE — all of G1–G6 verified, G5 confirmed in-game (2026-09-11)

`FrameRegistry.lua` (102 lines) now owns the `containers`/`overlayContainers` caches, the
`ns.absorbCache`/`ns.overlayCache` exports, `ns.GetOrCreateBar`, `ns.ReleaseAllBars`,
`ns.CleanupStaleCacheEntries`, and the cleanup event frame. `CompactUnitFrame.lua` is down
from 450 to 347 lines. TOC updated. Suite is 93 passing.

**The plan was wrong about one thing, and this matters for Stage 3.** `ReleaseAllBars`
doesn't only touch registry state — it also wiped `updateQueue` and `retryCount`, bumped
`pendingRecoveryRefreshToken`, and hid `batchFrame`, all of which are *queue* state that
doesn't move until Stage 3. Moving the function as written would have orphaned those
references.

Resolved with the same indirection trick the plan already uses in Stage 3: the queue side
now exposes `ns.ResetUpdateQueue()` (wipes the queue, wipes retry counts, bumps the
recovery token, hides the batch frame) and `ReleaseAllBars` calls it. This was introduced
as a *pre-move, behaviour-identical* edit — same statements, same order — so it could be
tested before anything relocated. **Stage 3 must move `ns.ResetUpdateQueue` into
`UpdateQueue.lua`; `FrameRegistry.lua` then needs no further edits.**

Also done in this stage:
- `GetOrCreate` was exported as `ns.GetOrCreateBar` *before* the move (as a temporary
  alias), so the spec could reach it while it was still a file-local. The move turned the
  alias into a real export and deleted the alias.
- **Harness:** `load_addon.NewNamespace` now installs a recording `ns.Debug` stub
  (`Inc`/`Set`/`Max`). The `--@alpha@` markers are only stripped at packaging time, so in
  raw source those 36 instrumentation calls are live and every pipeline spec would error
  without it. Specs can assert on the recorded counts — `frameregistry_spec` uses this to
  prove the create-vs-reuse cache path.

**Mutation-testing lesson worth repeating:** the first attempt used a `sed` pattern that
also rewrote the function *declaration*, producing a file that didn't parse. Every test
"failed", which looks like a great result and proves nothing — a non-parsing file can't
distinguish a good assertion from a vacuous one. Re-run with precise, *parseable*
mutations: 2 mutations produced exactly 2 targeted failures with the other 15 still
passing. **Always confirm the mutant still compiles before believing the mutation test.**

### Stage 3: Extract `UpdateQueue.lua` from `CompactUnitFrame.lua`

This is the trickiest stage in Phase 1 because the `OnUpdate` loop currently calls a local
function, `HandleCompactUnitFrameUpdate`, that is *not* moving yet (it moves in Stage 4).
Resolve this with one indirection point instead of moving everything at once.

**Preconditions to verify:** re-read the remaining `CompactUnitFrame.lua` and confirm it
still contains: `batchFrame`, `updateQueue`, `retryCount`, `MAX_RETRIES`,
`CACHE_CLEANUP_INTERVAL`, `FULL_REFRESH_RECOVERY_DELAY`, `lastCleanupAt`,
`pendingRecoveryRefreshToken`, `ScheduleRecoveryRefresh`, `ns.QueueCompactUnitFrameUpdate`,
the `batchFrame:SetScript("OnUpdate", ...)` loop, and — still in this file — a local
`HandleCompactUnitFrameUpdate` that the loop calls directly.

**Tests required before this stage starts:**
- `tests/updatequeue_spec.lua` — inject a **fake** `ns.ProcessQueuedFrame` (a stub you
  control that records calls and returns a configurable `true`/`false`) and test:
  `QueueCompactUnitFrameUpdate`'s dedupe (queuing the same frame twice only queues once),
  its disabled-context path (releases immediately, doesn't queue), and the `OnUpdate`
  loop's retry/drop behavior (a frame that returns `false` gets retried up to
  `MAX_RETRIES` times, then dropped and `ScheduleRecoveryRefresh` fires). Since the real
  `HandleCompactUnitFrameUpdate` doesn't exist as `ns.ProcessQueuedFrame` yet, write these
  tests to load a **temporary local stub** standing in for the eventual contract — the
  point is to lock down the *queue's* behavior independent of what "processing a frame"
  actually does. These tests should still be meaningful after Stage 4 relocates the real
  implementation underneath the same name.

**Move:**
0. **Added by Stage 2:** `ns.ResetUpdateQueue` already exists in `CompactUnitFrame.lua`
   and must move into `UpdateQueue.lua` along with the queue state it touches
   (`updateQueue`, `retryCount`, `pendingRecoveryRefreshToken`, `batchFrame`).
   `FrameRegistry.lua`'s `ReleaseAllBars` calls it through `ns.`, so it needs no edit —
   but the Stage 2 spec asserts the delegation happens, so don't inline it away.
1. Create `UpdateQueue.lua` containing everything listed in Preconditions above.
2. Change the `OnUpdate` loop's call from the local `HandleCompactUnitFrameUpdate(frame,
   profile)` to `ns.ProcessQueuedFrame(frame, profile)`.
3. At the bottom of the still-not-deleted `CompactUnitFrame.lua`, add one line:
   `ns.ProcessQueuedFrame = HandleCompactUnitFrameUpdate` — a pure alias, zero logic
   change, that satisfies the new contract until Stage 4 removes this line and assigns
   directly.
4. TOC: insert `UpdateQueue.lua`.

**Verify (see §1.2).** G5: during normal group play, confirm a shield landing on a frame
still produces a visible custom bar (proves the queue → alias → real handler chain still
fires end to end). The retry/drop path is exercised by the unit test, not realistically
forceable in-game — that's expected and fine.

#### Stage 3 status: DONE — all of G1–G6 verified, G5 confirmed in-game (2026-09-11)

`UpdateQueue.lua` (145 lines) now owns `batchFrame`, `updateQueue`, `retryCount`, the four
timing/retry constants, `ScheduleRecoveryRefresh`, the `OnUpdate` batch loop,
`ns.QueueCompactUnitFrameUpdate`, and `ns.ResetUpdateQueue`. `CompactUnitFrame.lua` is
down to 208 lines and now holds *only* Stage 4's payload. Suite is 110 passing.

The seam went in first as a behaviour-identical edit (the loop calling
`ns.ProcessQueuedFrame(frame, profile)` with `ns.ProcessQueuedFrame =
HandleCompactUnitFrameUpdate` aliased beside the local), so the queue could be tested
against a contract before anything moved. The extraction itself was verbatim: the
before/after line sets are identical, so this stage changed no behaviour at all.

**Harness additions** (both will be needed by Stages 4–5):
- `wow_stub.InstallAddonStub{ profile = …, contextEnabled = … }` — stands in for the
  `OvershieldsReforged` object that `Core.lua` normally builds through AceAddon, which is
  far too heavy to load in a unit test.
- `wow_stub.FindOnUpdateDriver()` — returns the frame carrying the `OnUpdate` script so a
  spec can run a batch cycle by hand instead of waiting on a real frame loop. This is how
  every retry/drop/cleanup-interval test drives the queue deterministically.

**Latent fragility found in `IsKnownCompactUnitFrame` — for Stage 4 to decide on.** The
first run of the new spec failed because an unrelated frame was classified as a compact
unit frame. Cause: the function compares `frame:GetParent()` against the globals
`CompactPartyFrame` and `CompactRaidFrameContainer`, and the test environment hadn't
defined them — so `nil == nil` matched and *every unparented frame* looked like one of
ours. The stub now defines both as real distinct objects, which is faithful to the client.

In the live client those globals always exist, so this is latent rather than an active
bug. But the guard is one missing global away from claiming every frame in the UI, and
Stage 4 owns this function — that's the moment to decide whether to harden it (an explicit
`parent ~= nil` check) as an opportunistic fix under decision #3, or leave it and keep the
stage a pure move.

### Stage 4: Extract `FrameUpdate.lua` — the last of `CompactUnitFrame.lua`

**Preconditions to verify:** re-read what's left of `CompactUnitFrame.lua` and confirm it
now contains only: `IsKnownCompactUnitFrame`, `EnforceNativeAbsorbVisibility`,
`SuppressNativeAbsorbVisuals`, `ApplyNativeVisualOnlyShielded`, `UpdateBarAnchor`,
`ApplyCustomBars`, `HandleCompactUnitFrameUpdate`, and the `ns.ProcessQueuedFrame = ...`
alias line added in Stage 3.

**Tests required before this stage starts:**
- `tests/frameupdate_spec.lua` — `IsKnownCompactUnitFrame` (name-prefix match for each of
  the four prefixes, parent-is-`CompactPartyFrame`/`CompactRaidFrameContainer` match, the
  nested-grandparent "Separate Groups" case, and the false/forbidden case);
  `HandleCompactUnitFrameUpdate`'s branches (context-disabled release, missing-unit early
  exit, forbidden-glow early exit, missing-healthBar returns `false`, native-visual-only
  path, custom-bars path) using mock frames and a fake profile. Write against the current
  code (still in `CompactUnitFrame.lua`), confirm green.

**Move:**
1. Create `FrameUpdate.lua` containing everything listed in Preconditions. The final
   function assigns directly: `function ns.ProcessQueuedFrame(frame, profile) ... end`
   (this **replaces** `local function HandleCompactUnitFrameUpdate` — rename it at the
   same time you give it its permanent export name, and delete the Stage-3 alias line).
2. Delete `CompactUnitFrame.lua` — it should now be empty of real content.
3. Update `Overshields_Reforged.toc`: remove the `CompactUnitFrame.lua` line, insert
   `FrameUpdate.lua` in a sensible spot near `UpdateQueue.lua`/`FrameRegistry.lua`.
4. Update `tests/updatequeue_spec.lua`'s fake `ns.ProcessQueuedFrame` situation: decide
   whether to keep it as an isolation stub (recommended — it keeps the queue tests fast
   and independent of frame-update internals) or point it at the real function now that
   it exists. Recommendation: keep the stub; add a small *integration* test instead
   (`tests/pipeline_integration_spec.lua`) that wires the real `UpdateQueue.lua` +
   `FrameUpdate.lua` together for one end-to-end "a queued frame gets its bars updated"
   case, so the seam itself is proven at least once.

**Verify (see §1.2).** This is the riskiest stage in Phase 1 (a file deletion + TOC edit).
G5, full pass: `/reload`; join/simulate a group; confirm shields and overshields render
correctly; change the shielded/overshielded anchor dropdowns and confirm the reload
prompt still repositions bars correctly after reload; run `/osr hibernate off` then
`/osr hibernate on` and confirm bars cleanly disappear/reappear; watch
`/console scriptErrors 1` for the whole pass.

#### Stage 4 status: DONE — all of G1–G6 verified, full in-game pass confirmed (2026-09-11)

`CompactUnitFrame.lua` **no longer exists.** Its remaining contents are now
`FrameUpdate.lua` (203 lines): `SuppressNativeAbsorbVisuals`,
`ns.IsKnownCompactUnitFrame`, `ns.EnforceNativeAbsorbVisibility`,
`ApplyNativeVisualOnlyShielded`, `UpdateBarAnchor`, `ApplyCustomBars`, and
`ns.ProcessQueuedFrame` (the former local `HandleCompactUnitFrameUpdate`, renamed to its
permanent exported name, with the Stage 3 alias deleted). TOC swapped. Suite is 139
passing.

The extraction diff contained exactly two changes beyond relocation — the rename and the
removal of the Stage 3 seam comment/alias — verified line by line before the old file was
deleted.

**Phase 1's original monolith is now fully decomposed:** 450 lines of
`CompactUnitFrame.lua` became `FrameRegistry.lua` (102), `UpdateQueue.lua` (145), and
`FrameUpdate.lua` (203), each with one job.

**Integration spec added** (`tests/pipeline_integration_spec.lua`, 3 tests), as this stage
recommended. It matters more than it looks: `updatequeue_spec` fakes
`ns.ProcessQueuedFrame` and `frameupdate_spec` fakes the appearance layer — both correct
choices for unit tests, but between them *no spec ever ran the real queue against the real
frame update against the real painting*. A broken seam could have hidden behind two green
files. The integration spec drives one full cycle — queue a frame, run the batch driver,
assert the bar exists, is scaled to the unit's absorb, and was actually painted by
`AppearanceManager` — then releases everything and checks the frame is handed back to
Blizzard's defaults.

**`IsKnownCompactUnitFrame` hardening was deliberately NOT done here.** The nil-equality
fragility recorded under Stage 3 is still open. Folding a behaviour change into the stage
that deletes a file and rewrites the TOC would make any in-game regression ambiguous —
"was it the move or the fix?" — so this stayed a pure move. It remains a good small
follow-up: an explicit `parent ~= nil` guard, with a test proving an unparented frame is
rejected even when the container globals are missing.

### Stage 5: Extract `FrameDiscovery.lua` from `AppearanceManager.lua`

**Preconditions to verify:** re-read `AppearanceManager.lua` and confirm it still contains
(besides the styling functions that are staying): `UpdateFramePool`, a local `ProcessFrame`,
`IsPartyUnit`/`IsRaidUnit`/`IsPetUnit`, `HideCachedBarsByPredicate`,
`ns.UpdateAllFrameAppearances`.

**Tests required before this stage starts:**
- `tests/framediscovery_spec.lua` — `UpdateFramePool`'s two paths: a mock container with
  `.flowFrames` (modern path) vs. no `.flowFrames` (legacy `_G[prefix..i]` walk — stub a
  couple of `_G` entries in the test); `ProcessFrame`'s shown → queue vs. hidden → release
  branching (use a fake `ns.QueueCompactUnitFrameUpdate`/`ns.ReleaseFrame` to isolate this
  from the real queue/lifecycle code, consistent with Stage 3's isolation approach).

**Move:**
1. Create `FrameDiscovery.lua` containing everything listed in Preconditions.
2. `AppearanceManager.lua` keeps only: `GetStyleState`, `SetTextureOrAtlas`,
   `ApplyStatusBarColor`, `ApplyStatusBarTextureAndBlend`, `ApplyTextureRegionStyle`,
   `ns.ApplyAppearanceToBar`, `ns.ApplyAppearanceToNativeBar`, `ns.ApplyAppearanceToOverlay`,
   `ns.ApplyAppearanceToNativeOverlay`, `ns.ApplyAppearanceToOverAbsorbGlow`,
   `ns.ApplyAppearanceToNativeOverAbsorbGlow`, `IsNativeVisualOnlyShielded`,
   `ns.ApplyAppearanceToFrame`, `ns.wipeStyleCache`, `ns.GetStyleCacheSize`.
3. TOC: insert `FrameDiscovery.lua` near `AppearanceManager.lua`.

**Verify (see §1.2).** G5: toggle each of Party/Raid/Pets off in Options and confirm
frames in that scope release immediately; toggle back on and confirm they restyle
immediately (this exercises `UpdateAllFrameAppearances` → `UpdateFramePool` →
`ProcessFrame` → the queue → the real update handler, i.e. the whole pipeline end to end).

#### Stage 5 status: CODE COMPLETE — G5 (in-game) still outstanding (2026-09-11)

`FrameDiscovery.lua` (129 lines) now owns `ProcessFrame`, the party/raid/pet predicates,
`HideCachedBarsByPredicate`, `UpdateFramePool`, and `ns.UpdateAllFrameAppearances`.
`AppearanceManager.lua` is down from 466 to 338 lines and is finally just styling.
Everything moving was one contiguous block, so this was a clean verbatim extraction —
before/after line sets identical. Suite is 155 passing.

The 16 new tests drive the public entry point (`ns.UpdateAllFrameAppearances`) rather than
the file-local helpers underneath it, which is why they survived the move untouched apart
from the FILES list. They cover both pool-walk paths (modern `flowFrames` vs. the legacy
`_G[prefix..i]` fallback), the shown-vs-hidden branch, all three scope toggles, and the
hibernate/no-profile guards.

**Harness fix worth knowing about:** `wow_stub.Reset()` now rebuilds `UIParent`,
`CompactPartyFrame`, and `CompactRaidFrameContainer` on every namespace, and clears the
160 legacy `Compact*Frame<N>` globals. Previously the containers were created once at
install time, so a spec attaching `flowFrames` or `displayPets` to one would leak that
into every later test in the run — an ordering-dependent false pass waiting to happen.

### Stage 6: Instrumentation decoupling

**Goal:** pipeline files currently call `ns.Debug.Inc(name)` / `ns.Debug.Set(name, value)`
/ `ns.Debug.Max(name, value)` directly — 36 call sites across `Hibernate.lua`,
`CompactUnitFrame.lua` (now spread across `FrameRegistry.lua`/`UpdateQueue.lua`/
`FrameUpdate.lua`/`FrameDiscovery.lua` after Stages 2–5), `Core.lua`, and
`AppearanceManager.lua`. Every one of those files has to know `Debug.lua`'s three-method
API shape and the exact counter-name-to-method mapping. Replace that with a single
generic `ns.Emit(name, amount)` that pipeline code calls without knowing what (if
anything) is listening, keeping the **same `--@alpha@` stripping** so there is still zero
runtime cost in non-alpha builds.

**Preconditions to verify:** re-run this exact grep and confirm the count and file list
still matches (files will have changed names since Stages 2–5 moved their contents out of
`CompactUnitFrame.lua`/`AppearanceManager.lua` — that's expected and fine, the *call
sites* moved with their surrounding code):
```
grep -rn "ns\.Debug\.\(Inc\|Set\|Max\)(" --include=*.lua .
```
As of this writing: 36 call sites, 31 distinct counter names. The exact name → method
mapping that must be preserved (transcribe this into `Debug.lua`'s new dispatch table
verbatim — do not re-derive it from `counters` table's initial value types, since
`poolFramesProcessed` is numeric but uses `Set` semantics, not `Inc`):

| Method | Counter names |
|---|---|
| `Inc` | `hookFires`, `queueAttempts`, `queueAdds`, `queueSkipsDuplicate`, `queueSkipsDisabled`, `batchCycles`, `batchFramesTotal`, `frameUpdates`, `earlyExits`, `retryAttempts`, `retrySuccesses`, `retryDrops`, `barCreates`, `barReuses`, `anchorModeChanges`, `nativeBarsSuppressed`, `colorApplied`, `colorSkipped`, `textureApplied`, `textureSkipped`, `blendApplied`, `blendSkipped`, `contextDisabled`, `framesShown`, `framesHidden`, `fullRefreshes`, `hibernateEvals`, `hibernateTransitions` |
| `Set` | `poolPath`, `poolFramesProcessed`, `lastRefreshTime` |
| `Max` | `peakBatchSize` |

**Tests required before this stage starts:**
- `tests/instrumentation_spec.lua` — `ns.Emit` is a no-op when no handler is registered
  (doesn't error); after `ns.SetInstrumentationHandler(fn)`, `ns.Emit(name, amount)` calls
  `fn(name, amount)` exactly once with the right arguments.
- Update one existing spec per moved file (pick `tests/frameregistry_spec.lua` and
  `tests/updatequeue_spec.lua` at minimum) to assert that the real call sites now invoke
  `ns.Emit` with the expected event name, via a test double registered as the handler —
  proving the wiring at a couple of representative points, not exhaustively re-testing
  every one of the 36 sites (that's what the mapping table + in-game check are for).

**Move:**
1. Create `Instrumentation.lua`:
   ```lua
   local _, ns = ...
   local handler = nil

   function ns.Emit(name, amount)
       if handler then handler(name, amount) end
   end

   function ns.SetInstrumentationHandler(fn)
       handler = fn
   end
   ```
2. TOC: insert `Instrumentation.lua` immediately after `Constants.lua` (see §1.4 — this
   is the one real load-order constraint in this plan).
3. In every file with a call site from the grep above, change
   `ns.Debug.Inc("name")` → `ns.Emit("name")` (and the `Set`/`Max` equivalents to
   `ns.Emit("name", value)`), keeping the exact same `--@alpha@ ... --@end-alpha@`
   wrapping each call already has.
4. In `Debug.lua`, add the dispatch table from the mapping above and register it:
   ```lua
   local EVENT_KIND = { poolPath = "set", poolFramesProcessed = "set",
                        lastRefreshTime = "set", peakBatchSize = "max" } -- default: "inc"

   ns.SetInstrumentationHandler(function(name, amount)
       local kind = EVENT_KIND[name] or "inc"
       if kind == "set" then Set(name, amount)
       elseif kind == "max" then Max(name, amount)
       else Inc(name, amount) end
   end)
   ```
   Place this call near the top of `Debug.lua`, after `Inc`/`Set`/`Max` are defined.

**Verify (see §1.2).** G5, this is the one stage worth a real before/after comparison:
build and run an **alpha** package (or just load the addon with `Debug.lua` included),
open `/osr debug`, trigger a few shield events, and confirm every counter still
increments — a typo'd event name is easy to make and silently drops a counter with no
error, so eyeball the debug window against the mapping table above rather than trusting
"no errors" alone.

#### Stage 6 status: CODE COMPLETE — G5 (in-game) still outstanding (2026-09-11)

`Instrumentation.lua` (26 lines) provides `ns.Emit(name, amount)` and
`ns.SetInstrumentationHandler(fn)`. All 36 call sites across 7 files now call `ns.Emit`;
no pipeline file references `ns.Debug` any more. `Debug.lua` attaches itself as the
handler at load and owns the `EVENT_KIND` dispatch. The `--@alpha@` wrapping is unchanged,
so non-alpha builds still strip the calls entirely and pay nothing. Suite is 167 passing.

**Correction to this stage's own preconditions:** the count is **32** distinct event names
(28 accumulating, 3 snapshot, 1 peak), not the 31 stated above. The re-verification step
in §1.1 is what surfaced it.

**The eyeball-the-debug-window check above is now largely automated.**
`tests/debug_sink_spec.lua` loads the *real* `Debug.lua` (a one-line `LibStub` stub is
enough — its AceGUI use is confined to building the window) and emits all 32 event names
through the real sink. This catches the exact failure this stage risks: `Debug.Inc` does
`counters[key] + amount`, so an event the sink doesn't know about is a nil-arithmetic
*error* in alpha builds, and no other spec can catch it because they all record through
the harness instead. Mutation-tested by deleting a counter and a kind entry: both were
caught, with the offending event named. Still worth one pass of the manual check, but it's
now a confirmation rather than the only line of defence.

**A harness bug this spec exposed immediately:** `load_addon` attached its recorder *after*
loading files, and `Debug.lua` replaces `ns.Debug` with its own table — so
`ns.Debug.Record` was nil and the attach silently *detached* Debug's handler. Every
counter read zero. The attach is now skipped when the real `Debug.lua` is loaded. Worth
remembering: `SetInstrumentationHandler` is last-writer-wins by design, so anything
attaching late wins, including a test helper.

Small cleanup, called out per decision #3: `Debug.Inc` / `Debug.Set` / `Debug.Max` are no
longer exported on the `Debug` table. Nothing referenced them once the call sites moved to
`ns.Emit`, and leaving them would invite calls that bypass the new seam. The local
functions remain — the handler uses them.

---

## Phase 1 complete

`CompactUnitFrame.lua` (450 lines) and `AppearanceManager.lua` (466 lines) are now eight
files, none over ~340 lines, each answering one question:

| File | Lines | Question it answers |
|---|---|---|
| `FrameDiscovery.lua` | 129 | which frames are worth processing? |
| `UpdateQueue.lua` | 145 | when does work actually run? |
| `FrameUpdate.lua` | 203 | what does this frame need? |
| `AppearanceManager.lua` | 338 | how is a bar painted? |
| `FrameRegistry.lua` | 102 | what are we tracking? |
| `BarLifecycle.lua` | 197 | how do we hand a frame back? |
| `Instrumentation.lua` | 26 | who's listening? |
| `Utilities.lua` | 31 | generic guards |

Backed by 167 tests, every one of them mutation-tested before being trusted with a move.
Open the Phase 1 PR per §1.3 before starting Phase 2.

**End of Phase 1.** `CompactUnitFrame.lua` and the pre-refactor `AppearanceManager.lua` no
longer exist as monoliths; the pipeline is now 7 files, each with one job. Open/merge the
Phase 1 PR here per §1.3 before starting Phase 2.

---

## Phase 2 — Options / config layer

Target decomposition of `Options.lua` (509 lines → ~230 lines, plus 3 new small files):

| New/changed file | Concern | Sourced from |
|---|---|---|
| `GlowTextureCatalog.lua` (new) | pure data: the ~50-entry spark/pip texture list | `Options.lua` |
| `ProfileMigration.lua` (new) | profile versioning, anchor-mode validation | `Options.lua` |
| `OptionsDropdowns.lua` (new) | dropdown-value builders (texture/glow), LSM wiring | `Options.lua` |
| `Options.lua` (trimmed, stays) | AceDB defaults, the AceConfig options schema, `InitializeDatabase`, `OpenOptions` | itself, minus the above |

### Stage 7: Extract `GlowTextureCatalog.lua` (pure data) from `Options.lua`

**Preconditions to verify:** re-read `Options.lua`'s `OverAbsorbGlowTextureDropdownValues`
function and confirm the inline table literal passed to `BuildGlowTextureValues(...)` is
still there, still roughly 50 entries of `{ assetPath, displayName }` pairs.

**Tests required before this stage starts:**
- `tests/optionsdropdowns_spec.lua` (create it now even though `OptionsDropdowns.lua`
  doesn't exist until Stage 9 — it can test the *current* `Options.lua` functions by
  loading `Options.lua` directly for now, then get its load list updated in Stage 9): a
  snapshot assertion — record `#<the inline table>` and a couple of specific entries
  (e.g. first entry is `Interface\RaidFrame\Shield-Overshield` / `"Default Glow"`, last
  entry is `XPBarAnim-OrangeSpark` / `"Orange XP Spark"`) before the move, confirm green.

**Move:**
1. Create `GlowTextureCatalog.lua`:
   ```lua
   local _, ns = ...
   ns.GlowTextureCatalog = {
       { "Interface\\RaidFrame\\Shield-Overshield", "Default Glow" },
       -- ... every entry, moved verbatim, in the same order
   }
   ```
2. In `Options.lua`, change `OverAbsorbGlowTextureDropdownValues` to call
   `BuildGlowTextureValues(ns.GlowTextureCatalog)` instead of the inline literal.
3. TOC: insert `GlowTextureCatalog.lua` before `Options.lua`.
4. Update the Stage-7 test to assert against `ns.GlowTextureCatalog` post-move; same
   count, same spot-checked entries.

**Verify (see §1.2).** G5: Options → Overshields tab → Overshield Glow group → Texture
dropdown — confirm the full spark/pip list still renders, same entries, same order.

### Stage 8: Extract `ProfileMigration.lua` from `Options.lua`

**Preconditions to verify:** re-read `Options.lua` and confirm it still contains:
`CURRENT_DB_VERSION`, `MigrateProfile`, `local ANCHOR_MODES` (display-label map),
`IsValidAnchorMode`, `NormalizeAnchorModeSettings`. Confirm `NormalizeAnchorModeSettings`
is currently the simplified version (just `profile.anchorModeShielded =
defaults.profile.anchorModeShielded` when nil — **not** the old dead
`anchorShieldToHealth` branch; that was already removed in the dead-code sweep that
preceded this plan). If it's *not* simplified, something reverted that change — stop and
find out why before proceeding.

**Tests required before this stage starts:**
- `tests/profilemigration_spec.lua` — `MigrateProfile` (a profile with `profileVersion =
  nil` and old keys set gets those keys nilled and `profileVersion` set to
  `CURRENT_DB_VERSION`; a profile already at `CURRENT_DB_VERSION` is left alone);
  `IsValidAnchorMode`/`NormalizeAnchorModeSettings` (all four valid modes pass through
  unchanged; an invalid or nil value falls back to `defaults.profile.anchorModeShielded`/
  `anchorModeOvershielded`). Write against current `Options.lua`, confirm green.

**Move:**
1. Create `ProfileMigration.lua` containing: `CURRENT_DB_VERSION`, `MigrateProfile`
   (export as `ns.MigrateProfile`), `ANCHOR_MODES` (export as `ns.AnchorModeLabels`),
   `IsValidAnchorMode` (export as `ns.IsValidAnchorMode`), `NormalizeAnchorModeSettings`
   (export as `ns.NormalizeAnchorModeSettings`). Note this file needs `defaults.profile`
   for its fallback values — since `defaults` is a local table defined in `Options.lua`,
   either (a) also move the `defaults` table into `ProfileMigration.lua` and have
   `Options.lua` read it back via `ns.ProfileDefaults`, or (b) pass the fallback values in
   as parameters instead of reaching for a shared `defaults` local. Prefer (a): it keeps
   "what a fresh profile looks like" and "how an old profile gets migrated to that shape"
   in the same file, which is the more honest coupling. If you choose (a), also update
   every other `defaults.profile.X` reference remaining in `Options.lua` (the appearance
   group factory's reset buttons, the anchor-mode `get` fallbacks) to `ns.ProfileDefaults.X`.
2. `Options.lua`: replace local `MigrateProfile`/`NormalizeAnchorModeSettings` calls in
   `InitializeDatabase`/`OnProfileChanged` with `ns.MigrateProfile`/
   `ns.NormalizeAnchorModeSettings`; replace `ANCHOR_MODES` references (the `values =`
   field in the two anchor-mode option entries) with `ns.AnchorModeLabels`; replace
   `IsValidAnchorMode` calls with `ns.IsValidAnchorMode`.
3. TOC: insert `ProfileMigration.lua` before `Options.lua`.
4. **Opportunistic-fix candidate to consider, not required:** `ns.AnchorModeLabels`'s key
   set (`health_left`/`health_right`/`frame_left`/`frame_right`) is hand-duplicated
   against `AnchorStrategy.lua`'s `anchorHandlers` table keys (same four, plus
   `default`). If you want to remove that duplication while you're already touching this
   file, derive the valid-mode check from `AnchorStrategy.lua`'s handler keys instead of a
   separately-maintained list — but if you do this, call it out explicitly as an
   opportunistic fix per decision #3, and add a test proving the two can no longer drift.

**Verify (see §1.2).** G5: `/osr reset`, confirm the fresh profile ends up with valid
default anchor modes in the options panel. The invalid-value-recovery path is awkward to
trigger manually (would need to hand-edit SavedVariables) — the unit test is the real
safety net here; treat the manual check as optional/best-effort for this stage only.

### Stage 9: Extract `OptionsDropdowns.lua` from `Options.lua`

**Preconditions to verify:** re-read `Options.lua` and confirm it still contains:
`cachedTextureValues`/`cachedGlowTextureValues` locals, `InvalidateDropdownCaches`,
`TextureDropdownValues`, `BuildGlowTextureOptionLabel`, `BuildGlowTextureValues`,
`OverAbsorbGlowTextureDropdownValues`, and the `LSM.RegisterCallback(...)` line. Confirm
`GlowTextureCatalog.lua` (Stage 7) already exists and is referenced correctly.

**Tests required before this stage starts:** the Stage 7 test
(`tests/optionsdropdowns_spec.lua`) already exists; extend it now with: a stub LSM object
providing one or two fake `statusbar`/`spark` entries, confirming
`TextureDropdownValues()`/`OverAbsorbGlowTextureDropdownValues()` merge them in (exercises
the LSM-present branch, currently untested); confirm `InvalidateDropdownCaches` actually
clears the memoized tables (call once, mutate the stub LSM, call
`InvalidateDropdownCaches`, call again, confirm the new entry shows up — proves the cache
isn't stale).

**Move:**
1. Create `OptionsDropdowns.lua` containing everything listed in Preconditions, exporting
   `ns.TextureDropdownValues` and `ns.OverAbsorbGlowTextureDropdownValues` (the two
   `Local BuildGlowTextureOptionLabel`/`BuildGlowTextureValues` helpers can stay local to
   this file — nothing outside it calls them).
2. `Options.lua`'s `SetupOptions`: replace the `values = TextureDropdownValues`/
   `values = OverAbsorbGlowTextureDropdownValues` references with
   `ns.TextureDropdownValues`/`ns.OverAbsorbGlowTextureDropdownValues`.
3. TOC: insert `OptionsDropdowns.lua` after `GlowTextureCatalog.lua`, before `Options.lua`.
4. Update `tests/optionsdropdowns_spec.lua`'s load list to load `OptionsDropdowns.lua`
   (plus its `GlowTextureCatalog.lua` dependency) instead of `Options.lua`.

**Verify (see §1.2).** G5: same dropdown check as Stage 7, plus — if there's a test
LibSharedMedia-registering addon handy, or a way to fake a late LSM registration —
confirm a newly registered texture still shows up live via the `InvalidateDropdownCaches`
callback without a `/reload`.

### Stage 10: Final shape confirmation + docs

No code moves this stage — it's a checkpoint.

1. Re-read `Options.lua` top to bottom and confirm it now contains only: `defaults` (or
   `ns.ProfileDefaults` if Stage 8 chose option (a)), the
   `OVERSHIELDS_REFORGED_RELOAD_ANCHOR` `StaticPopupDialogs` entry, `OnAppearanceChanged`
   + its debounce token, `BLEND_MODES`, `SetupOptions`/`MakeAppearanceGroup`/the options
   table, `InitializeDatabase`, `OpenOptions`, `IsUnitContextEnabled`/
   `IsFrameContextEnabled`. If anything else is still in there, decide now whether it
   belongs in one of the three new files or is genuinely options-schema-shaped and should
   stay — don't leave stragglers "for later."
2. Confirm `.pkgmeta` doesn't need changes (it packages by TOC reference plus the
   `ignore:`/`externals:` blocks, which this plan doesn't touch except Stage 0's
   `tests/lib/luaunit.lua` addition to `ignore:`).
3. Add a short module map to `README.md` (or a new `ARCHITECTURE.md` if that reads
   better) listing every `.lua` file and its one-sentence responsibility, generated from
   the two tables at the top of Phase 1 and Phase 2 in this document. This is what keeps
   the split from silently re-merging back into a monolith over the next year of feature
   work — point future contributors at it in review.
4. Full regression pass: repeat Stage 4's in-game checklist end to end once more, on the
   final state of the whole branch, not just the last stage's diff.

**Verify (see §1.2).** All of G1–G6, plus: confirm the Phase 2 PR diff, read as a whole,
tells the same story as the two tables at the top of this document — if it doesn't, the
plan or the execution drifted somewhere and it's worth finding out which.

---

## Appendix A: Current file inventory (as of this writing)

| File | Lines | Role |
|---|---|---|
| `Constants.lua` | 25 | global → `ns.*` aliases |
| `Utilities.lua` | 226 | forbidden-frame guard, setting-enabled guard, atlas cache, vanilla-restore helpers (splitting in Stage 1) |
| `Core.lua` | 58 | AceAddon bootstrap, heal-prediction hook wiring |
| `UnitContext.lua` | 43 | unit-token → context classification |
| `Hibernate.lua` | 121 | auto/manual hibernate state machine |
| `ShieldState.lua` | 63 | shield/overshield state resolution, anchor-mode resolution |
| `AnchorStrategy.lua` | 37 | anchor-mode → bar positioning |
| `Options.lua` | 509 | AceDB defaults/migration, dropdown data+builders, AceConfig schema (splitting in Phase 2) |
| `ChatCommands.lua` | 107 | slash command dispatch |
| `CompactUnitFrame.lua` | 439 | bar pooling, update batching, per-frame decisions, cache lifecycle (splitting in Phase 1) |
| `AppearanceManager.lua` | 466 | style caching + application, frame-pool iteration (splitting in Phase 1) |
| `Debug.lua` | 392 | alpha-only counters + AceGUI debug window |

## Appendix B: Target file inventory (post Phase 1 + Phase 2)

See the two per-phase tables above for the new files. `CompactUnitFrame.lua` is deleted.
`Options.lua` and `AppearanceManager.lua` shrink substantially; `Utilities.lua` shrinks
slightly. No file in the final state should exceed roughly 250 lines; if one does when you
get there, that's a signal this plan under-split something — flag it rather than shipping
it, but don't invent a new stage to fix it without the user's sign-off, since that's scope
this document didn't originally plan for.
