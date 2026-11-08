# Spec: Enchant Queue 0.4.0

Three changes, in this order. Read CLAUDE.md first; it lists what's already proven and what this environment can't do.

## 1. Dock the panel clear of the profession tabs

**Problem.** `UI.ShowDocked` (UI.lua) anchors the panel's TOPLEFT to `ProfessionsFrame` TOPRIGHT +4. Forever has a vertical strip of profession-switching tabs on the right edge of the Enchanting window, roughly 60 px wide: Enchanting, Tailoring, a banner and Cooking icons. The panel sits on top of them. The user's screenshot shows the panel covering the tabs.

**Change.**
- At dock time, find the rightmost edge of anything attached to the right of `ProfessionsFrame`:
  - Check `ProfessionsFrame`'s shown children, plus the tab strip if you can identify it.
  - Anchor the panel's TOPLEFT to that edge with a gap of about 6 px, top-aligned with `ProfessionsFrame`.
  - Fall back to a fixed x offset of +64 if nothing is found.
- Prefer finding the real tab frame by name. Ask the user to hover a tab, type `/fstack`, and send a screenshot. Hard-code that frame if it's stable, and keep the scan as the fallback.
- Match the panel height to `ProfessionsFrame` so the two read as one unit.
- Keep the rule that docking and moving only happen out of combat. The panel contains a secure button.

**Done when** the user's screenshot shows the panel fully to the right of the tabs, top edges aligned, with no overlap.

## 2. Restyle the panel to match the Enchanting window

**Problem.**
- The panel uses `BasicFrameTemplateWithInset` and `UIPanelButtonTemplate`, which render as a plain box with red buttons.
- Blizzard's Enchanting window has a different chrome and darker buttons: "Create", "Enchant" and "Create All".
- The empty item slot is an untextured square.

**Change.**
- **Frame chrome:** use the same template family as `ProfessionsFrame`. Check in game, for example with `/dump ProfessionsFrame.NineSlice ~= nil` and by comparing title bars. `ButtonFrameTemplate` or `PortraitFrameTemplate` are likely. Use the Enchanting icon as the portrait if the template has one.
- **Buttons:** match Blizzard's Create button look. Find its template or textures from `ProfessionsFrame.CraftingPage.CreateButton`, or with `/fstack` in game. Next stays a `SecureActionButtonTemplate`, so add the visual template alongside it.
- **Target slot:**
  - an empty-slot texture with the usual item-button border
  - a quality-coloured border once filled
  - a short label "Item to enchant"
- **Queue rows:**
  - recipe icon, name, and the count right-aligned
  - hover highlight
  - the remove button as a small "x" icon button, not a red text button
- **Status line:** keep it, styled like Blizzard's small grey helper text.
- **Light touch:** no new features or settings, and every current behaviour stays.

**Done when** the user agrees it looks native next to the Enchanting window. Expect two or three screenshot rounds; send a zip each round (see CLAUDE.md).

## 3. Release on version bump, with no manual GitHub steps

**Problem.** The release workflow (`.github/workflows/release.yml`) only runs on a pushed `v*` tag, and this session can't push tags. Today the user has to create each release by hand on GitHub.

**Change.**
- Add a `VERSION` file at the repo root containing just `0.4.0`.
- Extend `release.yml`:
  - **Triggers:**
    - push of `v*` tags, kept for manual releases
    - push to `main` with `paths: [VERSION]`
  - **On a `main` push:**
    - Check out with `fetch-depth: 0` and read `VERSION`.
    - If tag `v$VERSION` already exists on the remote, exit successfully without building.
    - Otherwise, create the annotated tag on HEAD, push it with `GITHUB_TOKEN` (`permissions: contents: write`), then run `BigWigsMods/packager@v2` in the **same job**.
    - Tags pushed with `GITHUB_TOKEN` don't trigger other workflows, so there's no double run, and the packager sees the tag on HEAD and makes a release build.
  - Keep the same env as today: `GITHUB_OAUTH`, `CF_API_KEY`, `WAGO_API_TOKEN`.
- Add `VERSION` and `docs` to `.pkgmeta`'s ignore list. The `.toc` keeps `@project-version@`.
- Document "bump VERSION → push → released" in the README's Development section and in CLAUDE.md.

**Done when** bumping `VERSION` to `0.4.0` and pushing to `main` produces:
- the `v0.4.0` tag
- a GitHub Release with `EnchantQueue-v0.4.0-forever.zip`
- a CurseForge upload marked `Success!` in the run log

Confirm each with `gh run view --log` and `gh api repos/pajw/enchantqueue/releases/tags/v0.4.0`.

## Order and release

1. Do items 1 and 2.
2. Run the tests, send the user zips, and iterate on their screenshots.
3. Do item 3 last. Its first real run is the 0.4.0 release, which ships 1 and 2.
4. Don't bump `VERSION` until the user has approved the look in game.

Out of scope: new features, trade-window enchanting, Wago setup (no token yet).
