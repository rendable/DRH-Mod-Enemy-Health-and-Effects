# This mod likely will not be maintained

I no longer really play the game, so ongoing updates and fixes are unlikely.

# Enemy Health and Effects

<!-- drh:show -->
Adds numerical enemy HP, encounter-specific boss panels, player mana bars and active buff/debuff icons.
<!-- /drh:show -->

- Native enemy and breakable-prop HP bars with readable white values, revealed after damage.
- Compact encounter-specific boss panels, capped at three rows, while retaining numerical overhead HP bars.
- Three number-free Golem segments track its lava-pool objectives.
- Other players get numerical HP and purple mana bars, with profile-picture spacing.
- Enemy, boss and remote-player buff/debuff icons show stacks without estimated countdowns.


## Requirements

Dungeon Rampage Haxe V17 and DRH Mod API 1.2 or a compatible later 1.x release. The launcher resolves the API dependency. This mod uses game internals and may need updates for later game releases.

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
