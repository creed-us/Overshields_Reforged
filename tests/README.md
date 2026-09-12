# Tests

Headless unit tests for the addon's pure logic. They load the **real** `.lua` files (via
`loadfile`, the same `(addonName, ns)` chunk call the client makes) into a throwaway
namespace, with the WoW API replaced by stubs. No game client required.

None of this ships: `tests/*` is in `.pkgmeta`'s `ignore:` list and nothing here is
referenced from the `.toc`.

## Running

From the repository root:

```sh
lua tests/run_tests.lua
```

CI pins Lua 5.1 to match the client's embedded runtime, and this repo's Windows dev setup
uses [Lua for Windows](https://github.com/rjpcomputing/luaforwindows) (5.1.5), installed at:

```
C:\Program Files (x86)\Lua\5.1\lua.exe
```

If `lua` isn't found in an already-open terminal right after installing, that shell is
still carrying the pre-install `PATH` — open a new terminal, or call the full path above.

Any Lua 5.1+ interpreter will do in a pinch (the code under test uses no version-specific
syntax), but prefer 5.1: it's what the client actually runs. With no Lua installed at all,
the VS Code Lua extension's bundled runtime can stand in via
`lua-language-server.exe -E tests/run_tests.lua`.

## Layout

| Path | Purpose |
|---|---|
| `run_tests.lua` | Entry point. Sets `package.path`, requires each spec, exits with the suite's status code. |
| `lib/luaunit.lua` | Vendored [LuaUnit](https://github.com/bluebird75/luaunit) 3.4 (BSD licence). |
| `support/load_addon.lua` | Loads real addon files into a fresh namespace per test. |
| `support/wow_stub.lua` | Stand-ins for the WoW globals (`CreateFrame`, `C_Timer`, `C_Texture`, …). |
| `support/mock_frame.lua` | Recorder-style fake frames/bars/textures; every setter is captured in `.calls`. |
| `*_spec.lua` | One spec file per module under test. |

## Adding a spec

1. Create `tests/<module>_spec.lua`.
2. Add its name (without `.lua`) to the `SPECS` list in `run_tests.lua` — specs are listed
   explicitly because plain Lua has no portable directory listing.
3. Give test classes names that are unique across **all** spec files. luaunit discovers
   them as globals, so two files declaring `TestFoo` means one set silently never runs.
   When a function moves between addon files, move its test class with it.
4. Load only the addon files the module actually needs:
   ```lua
   local ns = load_addon.NewNamespace({ "Constants.lua", "ShieldState.lua" })
   ```
   Each call returns a fresh namespace, so module-level caches and state tables start
   clean for every test. Treat this list as a dependency declaration: if the module calls
   an `ns.*` function defined in another file, that file belongs here too — and when a
   function moves between files, every spec that transitively needs it must be updated.

## Gotcha: stubs are captured at load time

`Constants.lua` aliases several globals by value (`local CreateFrame = CreateFrame`), so
the stubs must be installed *before* any addon file loads — `NewNamespace` handles that.
To change one mid-test, swap it on the namespace (`ns.IsInRaid = ...`), not on `_G`;
reassigning the global after load won't affect the captured alias.
