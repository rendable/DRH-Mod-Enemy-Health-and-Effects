# This mod likely will not be maintained

I no longer really play the game, so ongoing updates and fixes are unlikely.

# Enemy Health and Effects

<!-- drh:show -->
Adds numerical enemy HP, encounter-specific boss panels, player mana bars and buff/debuff icons for other players.

- Native enemy and breakable-prop HP bars with readable white values, revealed after damage.
- Compact encounter-specific boss panels, capped at three rows, while retaining numerical overhead HP bars.
- Three number-free Golem segments track its lava-pool objectives.
- Other players get numerical HP and purple mana bars, with profile-picture spacing.
- Other players' buff/debuff icons show stacks without estimated countdowns. Enemies and boss panels have no added status icons.
<!-- /drh:show -->

## Performance (0.9.0)

A profile flagged `Main.update` as a heavy cost: it rescanned every actor on the floor and recomputed everything from scratch on every single frame. 0.9.0 keeps the same behavior but changes *when* things run:

- Who qualifies as a tracked enemy, boss status, and the golem-pool state are rechecked a few times a second instead of every frame; only HP/position/visibility for already-tracked enemies run every frame now.
- The two separate full-actor scans (golem pools, then enemies) are merged into one pass.
- Per-enemy static facts (map constant, nametag offset, health-bar scale) are read once and cached instead of re-read from the game object every frame.
- Enemy HP is read once from the game's own HP-change event instead of also being polled every frame.
- The HUD-layer coordinate conversion only recomputes when the view is actually resized.
- Remote players' buff/debuff icon strips only rebuild when a buff actually changes, not every frame.

No visible behavior should differ; file an issue if something looks off after updating. Verified loading cleanly under DRH Mod API 1.4.0 on V17 (`last-run.json` status `ok`), hence the API requirement bump to 1.4 in this release.

## Performance (0.9.2)

Follow-up to 0.9.0 after the mod owner's measured per-frame cost dropped from +1.0ms to +0.4ms but was still the most expensive mod on the list:

- The per-frame loop skips enemies that were never hit and aren't a boss before doing any on-screen work, instead of running the coordinate conversion and bounds checks for every tracked enemy on the floor.
- Decorations/HP-bar/panel visibility are only touched when an enemy's shown state actually changes, instead of being reset to hidden and reapplied every frame.
- Loop variables over the enemy/player maps are explicitly typed instead of left to per-frame dynamic field lookups.
- Remote-player membership (who's a tracked player) moved onto the same throttled scan as enemy membership, instead of copying the floor's player list every frame.

### 0.9.3 fix

Moving player membership onto a throttled scan meant a hero destroyed between scans (e.g. leaving the dungeon mid-floor) could still reach `PlayerManaEntry.update` for up to ~200ms, which read `hero.actorNametag` before checking `hero.isDestroyed` and could throw. 0.9.3 checks `isDestroyed`/`isDead` first and returns before touching the hero.

## Requirements

Dungeon Rampage Haxe V17 and DRH Mod API 1.4 or a compatible later 1.x release. The launcher resolves the API dependency. This mod uses game internals and may need updates for later game releases.

## Installation

Install the release ZIP through the DRH Launcher Mods page. Do not use GitHub's automatic source-code ZIP as the release artifact.

To test a source checkout, run this from its repository folder with your launcher path:

```powershell
& "C:\Path\To\DRH-Launcher.com" --run-mod (Get-Location).Path
```

## Publishing

The included official workflow drafts a release when you push a `v<version>` tag matching `mod.json`. Test the generated ZIP before publishing the draft. Follow [Making a mod](https://github.com/Tutez64/Dungeon-Rampage-Haxe/blob/master/docs/making-a-mod.md) to submit the published release to the mod index.

## License

MIT. See [LICENSE](LICENSE).
