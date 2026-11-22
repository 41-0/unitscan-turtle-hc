# UnitScan Turtle-HC

An unofficial fork of [RetroCro/unitscan-turtle-hc](https://github.com/RetroCro/unitscan-turtle-hc) for Turtle WoW's 1.12-compatible addon interface (`11200`). It scans for dangerous elites, rares, and other named units, with a built-in list for each supported zone.

## Installation

Extract this fork and place the `unitscan-turtle-hc` folder in `Interface/AddOns`. If you download a GitHub source archive, rename the extracted folder so the path is `Interface/AddOns/unitscan-turtle-hc/unitscan-turtle-hc.toc`. Restart the client or reload the UI.

Keep one copy of the addon installed. Upgrading in the same folder keeps your saved settings, ignored names, and custom targets.

## Controls

| Control | Action |
| --- | --- |
| Minimap button, left-click | Toggle the settings window |
| Minimap button, right-click | Toggle scanning globally. The icon dims when scanning is disabled |
| Minimap button, left-drag | Move it around the minimap rim and save its position |
| Alert plate, left-click | Target the displayed unit |
| Alert plate, Ctrl + left-drag | Move the alert stack |
| Ignore This Mob | Dismiss the alert and add the name to the ignored list |
| `/unitscan options` | Toggle the settings window |
| `/unitscan on`, `/unitscan off`, `/unitscan toggle` | Set or toggle global scanning and report the resulting state in chat |
| `/unitscan` | List custom and zone targets |
| `/unitscan name` | Add or remove a custom scan target |
| `/unitscantarget` | Target the most recently detected unit if its name is eligible |

## Settings

| Setting | Default |
| --- | --- |
| Enable scanning | On |
| Pause scanning during combat or auto-attack | Off |
| Show character model | On, for the newest visible alert |
| Screen flash | On |
| Play warning sound | On |
| Warning sound | `Sound\Interface\RaidWarning.wav` |
| Alert scale | 1.0 |
| Minimum display time | 10 seconds |

Checkboxes apply immediately. Click **Apply** to save edits to the MPQ sound path, scale, or minimum display time. A blank sound field restores the default path.
The three legacy warning sounds are no longer bundled. If your saved warning sound points to one of those files, clear the field and click **Apply** to restore the game client sound.

Each plate has its own timer. After its minimum time, the plate disappears when a scan stops finding its unit. While scanning is paused, the addon checks for disappearance when scanning resumes. Turning scanning off clears all alerts immediately.

Open **Ignored Mobs** to add or remove exact names. Name matching is case-insensitive and applies to both custom targets and the [zone target list](zonetargets.lua). A custom target is consumed after its first match. To scan for it again, add it again using `/unitscan name`. Zone targets refresh when the zone changes or 90 seconds after a zone hit.

## Compatibility

The scanner briefly selects units with `TargetByName` and then restores the user's target. Other addons can react to these brief target changes. If target changes interfere with combat, enable **Pause scanning during combat or auto-attack**.

## Credits and licensing

- [shirsig/unitscan-vanilla](https://github.com/shirsig/unitscan-vanilla) is the original Vanilla scanner.
- The original Hardcore README credits [GryllsAddons/unitscan-turtle](https://github.com/GryllsAddons/unitscan-turtle) for the Turtle WoW version.
- [RetroCro/unitscan-turtle-hc](https://github.com/RetroCro/unitscan-turtle-hc) provided the Hardcore fork used as this project's base.

See [NOTICE.md](NOTICE.md) for the status of upstream code and bundled assets before publishing a release.
