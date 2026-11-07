# Enchant Queue

<img src="media/logo.png" width="128" alt="Enchant Queue logo">

A World of Warcraft: Forever addon. Queue several enchants on one item, then apply them one key press at a time.

Built for levelling Enchanting: "Inferior Stamina ×10 on these bracers" becomes ten taps of a key, not ten rounds of select recipe → pick target → click Enchant → confirm.

## Usage

1. Open your Enchanting window. The Enchant Queue panel docks beside it.
2. Drag the item to enchant onto the panel's slot (or Alt-click it in your bags). It can be in your bags or equipped.
3. Select an enchant in the Enchanting window, type a count and click **+ Queue**. Repeat for more enchants.
4. Press **Next**. Each press fills in the Enchanting window and clicks Enchant for you. If the item already has an enchant, the button changes to **Confirm replace**, and the next press clicks Yes.

### Use the mouse wheel

WoW requires a real key press or click for every enchant, so no addon can run the queue on its own. To make it effortless, bind it to the mouse wheel:

**Esc → Options → Keybindings → AddOns → "Cast next queued enchant"** → scroll down once.

Then scroll gently to work through the queue. Presses that land while an enchant is still casting are ignored.

## Commands

| Command | |
|---|---|
| `/eqq` (or `/enchantqueue`) | Show or hide the panel |
| `/eqq clear` | Empty the queue |
| `/eqq status` | Print diagnostics (include this in bug reports) |
| `/eqq debug` | Toggle detailed chat output |

`/eq` works too, unless another addon already uses it.

## Notes

- The queue is saved per character and follows the item if you move it between bags or equip it.
- If the item is sold or destroyed, the queue pauses and shows "Item not found".
- Enchanting other players' items through the trade window isn't supported.

## Development

Plain Lua 5.1, no build step. Tests run outside the game:

```bash
lua5.1 tests/queue_test.lua
```

```bash
lua5.1 tests/smoke_test.lua
```

The smoke test loads the whole addon against a stubbed WoW API. It catches wiring bugs, not taint or real API behaviour.

Releases are built by [BigWigs packager](https://github.com/BigWigsMods/packager): push a `v*` tag and the zip is attached to a GitHub Release, and uploaded to CurseForge and Wago when those are configured.
