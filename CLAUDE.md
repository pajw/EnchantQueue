# Enchant Queue: notes for Claude sessions

A World of Warcraft: Forever addon (Lua 5.1, no build step). It queues several enchants on one item, and each press of Next applies the next one. See README.md for user-facing behaviour.

## How it works (proven in game, don't redesign)

- **Next** is a `SecureActionButtonTemplate` button (`EnchantQueueNextButton`).
  - In `PreClick` (insecure), `Cast.lua` stages the head recipe and the target item into Blizzard's Enchanting window:
    - `C_TradeSkillUI.OpenRecipe(recipeID)`
    - `SchematicForm:GetTransaction():SetEnchantAllocation(Item:CreateFromItemLocation(loc))`
    - `enchantSlot:SetItem(item)`
  - The secure click then hits `ProfessionsFrame.CraftingPage.CreateButton` (`type=click`). Forever does **not** block this as taint; tested in game.
- When the item already has an enchant, Forever shows the popup `REPLACE_TRADESKILL_ENCHANT`. The next press of Next clicks its Yes button.
- Next is disarmed during any player cast (`UNIT_SPELLCAST_START`/`STOP`), so mouse-wheel spam is harmless.
- Every craft needs a hardware event. Never try to automate casting.
- Ruled out in game:
  - `/cast <enchant name>` macros do nothing in Forever.
  - Checklist-only mode was dropped.
- `/eq` clashes with another addon the user has. `/eqq` and `/enchantqueue` are the reliable commands.

## Forever facts

- TOC `## Interface: 16001`. The release packager recognises the flavour as `forever` and CurseForge accepts game version `1.60.1`.
- Addon path on the user's PC: `World of Warcraft/_forever_/Interface/AddOns/EnchantQueue/`.
- Lua errors are hidden in game by default. `ns.SafeCall` prints them to chat.
- `/eqq status` prints diagnostics. Ask the user for a screenshot of it when debugging.

## Dev loop

- Install Lua first: `apt-get install -y lua5.1`.
- Syntax check:
  ```bash
  for f in *.lua; do luac5.1 -p "$f"; done
  ```
- Queue tests:
  ```bash
  lua5.1 tests/queue_test.lua
  ```
- Smoke test (loads the whole addon against stubbed WoW APIs):
  ```bash
  lua5.1 tests/smoke_test.lua
  ```
  Extend the stubs when you touch new APIs. Stub frames return nil for lower-case fields, as WoW does.
- Nothing can run WoW here. To get the addon to the user for testing:
  1. Copy the `.lua`, `.toc` and `Bindings.xml` files to a scratch folder named `EnchantQueue`.
  2. Replace `@project-version@` in the copied `.toc` with the version.
  3. **Preferred: install it directly.** The user wants this route. Call `list_computer_folders`.
     - If their AddOns folder (or its parent `_forever_`) is listed and online, attach it with `request_computer_folder`.
     - Copy the built folder to `AddOns/EnchantQueue/`, replacing the old one.
     - Tell the user to type `/reload`. A `.toc` change or a new file needs a full game restart instead.
  4. **Fallback: send a zip.** Use this if the folder isn't listed, is offline, or the request is refused. Zip the folder, send it with SendUserFile, and say why the direct install didn't work.
  5. Either way, ask for screenshots.

## Releasing

- Bump `VERSION` and push to `main`. That's the whole release.
  - `.github/workflows/release.yml` runs the tests, creates and pushes tag `v<VERSION>` with `GITHUB_TOKEN`, then runs the packager in the same job.
  - If the tag already exists, the job exits without building.
  - The `.toc` keeps `@project-version@`; the packager fills it in.
- Only bump `VERSION` once the user has approved the build in game.
- Check the result:
  - `gh run list --workflow Release`, then `gh run view <id> --log` (look for CurseForge `Success!`).
  - `gh api repos/pajw/enchantqueue/releases/tags/v<VERSION>` for the GitHub Release and its zip.

## Environment limits (cloud session)

- You can push commits to `main`.
- You **cannot**:
  - push tags (the proxy returns 403). The Release workflow tags for you; see Releasing.
  - create repositories
  - read or set Actions secrets
  - use GitHub GraphQL. `gh release view` and `gh pr view` fail; use `gh api repos/pajw/enchantqueue/...` (REST) instead.
- `gh run list` and `gh run view --log` work, so you can watch workflows.
- Secrets already set in the repo: `CF_API_KEY`. `WAGO_API_TOKEN` is not set. CurseForge project ID: 1789836, in the TOC.

## Commits

End commit messages with the attribution lines the session provides. Don't put model names in commits or code.
