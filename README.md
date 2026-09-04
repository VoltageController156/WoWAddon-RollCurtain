<div align="center">

# Roll Curtain

<img src="assets/roll-curtain-icon.png" alt="Roll Curtain icon" width="180">

**Hide unwanted bonus-roll prompts by activity type and raid difficulty.**

<p>
  <a href="https://www.curseforge.com/wow/addons/roll-curtain"><img alt="CurseForge" src="https://img.shields.io/badge/CurseForge-Roll%20Curtain-F16436?logo=curseforge&logoColor=white"></a>
  <a href="https://github.com/VoltageController156/WoWAddon-RollCurtain/releases/latest"><img alt="Latest Release" src="https://img.shields.io/github/v/release/VoltageController156/WoWAddon-RollCurtain?display_name=tag&sort=semver&label=Release"></a>
  <a href="https://github.com/VoltageController156/WoWAddon-RollCurtain/actions/workflows/release.yml?query=branch%3Abeta"><img alt="Beta CI" src="https://github.com/VoltageController156/WoWAddon-RollCurtain/actions/workflows/release.yml/badge.svg?branch=beta"></a>
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/License-MIT-blue.svg"></a>
  <a href="https://worldofwarcraft.blizzard.com/"><img alt="WoW Retail" src="https://img.shields.io/badge/WoW-Retail%2012.1.x-7d5fff"></a>
</p>

[CurseForge](https://www.curseforge.com/wow/addons/roll-curtain) • [Releases](https://github.com/VoltageController156/WoWAddon-RollCurtain/releases) • [Changelog](CHANGELOG.md) • [Report a Bug](https://github.com/VoltageController156/WoWAddon-RollCurtain/issues/new)

</div>

Roll Curtain is a lightweight World of Warcraft Retail add-on that hides bonus-roll prompts in the activities you choose, keeps suppressed rolls recoverable until they expire, and can add a confirmation step before a bonus-roll token is spent.

## Highlights

- Activity-specific suppression for Delves, Prey hunts, outdoor content, dungeons, raids, and scenarios.
- Per-difficulty controls for Normal, Heroic, Mythic, and Mythic+ dungeons and Story, LFR, Normal, Heroic, and Mythic raids.
- Recoverable hidden rolls with a clickable **[Restore Bonus Roll]** chat link and minimap recovery indicator.
- Optional confirmation before spending a bonus-roll token, including loot specialization and remaining token count.
- Named, shareable profiles with per-character assignments.
- Profile-backed **Chat Notifications** routing for local chat-window display.
- Persistent beta builds and diagnostics for testing changes before stable release.
- No Ace3 or other addon libraries required.

## Default behavior

Fresh installs suppress bonus-roll prompts in:

- Delves
- Prey hunts
- World bosses and other outdoor content
- Normal dungeons
- Heroic dungeons
- Mythic dungeons

Mythic+, raids, and other scenarios remain visible unless you enable those options.

## Configuration

Open **Options → AddOns → Roll Curtain**. Roll Curtain uses Blizzard's modern Settings panel and separates general options, profiles, help, and beta diagnostics where appropriate.

### Profiles

Roll Curtain includes dependency-free named profiles for sharing settings between characters.

- Every character starts on **Default** unless assigned to another profile.
- New profiles begin as a copy of the currently active profile.
- Profiles can be created, copied, renamed, deleted, and selected from the dedicated **Profiles** page.
- **Profile Assignments** shows which characters are currently using each profile.
- Changes to a shared profile apply to every character assigned to it.
- **Default** cannot be renamed or deleted.
- `/rc reset` resets only the currently active profile.

The minimap button position remains character-specific rather than profile-specific.

### Chat Notifications

Roll Curtain can route its local suppression/restore notices to one or more chat-window destinations. **General** is enabled by default.

Optional destinations include Loot, System, Say, Yell, Party, Raid, Instance, Guild, Officer, Whisper, Battle.net Whisper, Emote, and Channel Messages.

These settings only control where Roll Curtain displays its own local messages. They do **not** send addon notifications to other players or transmit anything into those channels.

### Dungeons and raids

**Dungeons** exposes Normal, Heroic, Mythic, and Mythic+ controls. Normal, Heroic, and Mythic are enabled by default while Mythic+ remains opt-in.

**Raids** exposes Story, LFR, Normal, Heroic, and Mythic controls. Story is selected when raid suppression is first enabled; the remaining difficulties are opt-in.

If the final selected child difficulty is cleared, its parent category disables and collapses automatically.

### Bonus-roll confirmation

**Confirm before using a bonus roll** is enabled by default in the Safety section.

When you click Blizzard's bonus-roll die, Roll Curtain can show:

- Your active loot specialization.
- The number of bonus-roll tokens that will remain after the roll.

**Confirm** proceeds through Blizzard's normal bonus-roll action. **Cancel** leaves the original prompt available. **Preview Confirmation** lets you inspect the confirmation UI safely without requiring an active roll or spending currency.

### Minimap button

The draggable minimap button provides quick access to Roll Curtain and hidden-roll recovery.

- **Left-click:** open Roll Curtain settings.
- **Right-click:** restore the current recoverable hidden roll.
- A circular gold recovery glow appears while a hidden roll can still be restored.
- Position is saved per character.
- **Show minimap button** hides the button without forgetting its position.
- Generic minimap-button collectors are supported.

### Commands & Help

Roll Curtain registers a **Commands & Help** subpage in-game. All aliases use the same command handler:

`/rollcurtain` • `/rcurtain` • `/rollc` • `/rc`

| Command | Purpose |
| --- | --- |
| `/rc` | Open Roll Curtain settings. |
| `/rc status` | Show the active profile, detected content, Curtain state, and confirmation state. |
| `/rc show` | Restore the current hidden bonus-roll prompt if it is still active. |
| `/rc reset` | Reset only the active profile to Roll Curtain defaults. |

## Recovering a hidden bonus roll

When Roll Curtain suppresses a roll, its local notification includes a clickable **[Restore Bonus Roll]** link. The same roll can also be restored with `/rc show` or by right-clicking the minimap button.

Restoring a hidden prompt does **not** perform the roll or spend currency. The original Blizzard prompt returns with its remaining timer synchronized, and the hidden roll continues to expire normally while suppressed.

## Installation

### Recommended — CurseForge

For the easiest installation and automatic updates, install Roll Curtain through the **CurseForge App**.

1. Open the CurseForge App and select **World of Warcraft**.
2. Search for **Roll Curtain** or open the [Roll Curtain CurseForge page](https://www.curseforge.com/wow/addons/roll-curtain).
3. Click **Install**.
4. Keep Roll Curtain managed by CurseForge to receive future stable updates automatically.

### Manual — GitHub Releases

If you prefer to install manually from GitHub:

1. Download the latest stable build from [GitHub Releases](https://github.com/VoltageController156/WoWAddon-RollCurtain/releases/latest).
2. Extract the `RollCurtain` add-on folder into `_retail_/Interface/AddOns/`.
3. Restart World of Warcraft or type `/reload` if the game is already running.
4. Enable **Roll Curtain** in the AddOns list.

GitHub installs are manual; future releases must be downloaded and installed manually unless you switch to an addon manager such as CurseForge.

## Beta builds and testing

Roll Curtain uses a persistent pre-release channel so changes can be exercised before they reach stable users.

- `main` represents the stable production release.
- `beta` represents the current pre-production test line.
- GitHub publishes beta builds as prereleases such as `0.0.8-beta.1` and `0.0.8-beta.2`.
- Packaged beta builds display their exact beta version in-game.
- Beta/development builds expose a **Debug** settings page with optional event logging, diagnostic snapshots, and safe recovery-glow testing.
- Stable releases keep diagnostic support available through commands while leaving debug disabled and out of the normal Settings UI.

Useful beta diagnostics include `/rc debug on`, `/rc debug off`, `/rc debug status`, `/rc debug dump`, and `/rc debug glow`.

Beta builds are intended for testers who are comfortable helping validate behavior before promotion to the stable release channel.

## Activity detection

- **Delves:** Blizzard's active-Delve APIs.
- **Prey hunts:** Blizzard's active-Prey-quest API.
- **World bosses / outdoor content:** bonus-roll prompts received outside an instance.
- **Dungeons:** instance type and Blizzard difficulty ID, with explicit Normal, Heroic, Mythic, and Mythic+ controls.
- **Raids:** instance type and Blizzard difficulty ID, with Story, LFR, Normal, Heroic, and Mythic controls.
- **Other scenarios:** current instance type after Delves are excluded.
- **Unknown content:** fails open and leaves the prompt visible as a safety fallback.

Unrecognized dungeon difficulties also fail open. If a Prey hunt is active while you complete a different outdoor encounter, Blizzard's bonus-roll event may not provide enough information to distinguish the activity, so the prompt can be classified as Prey.

## Reporting bugs

Please use [GitHub Issues](https://github.com/VoltageController156/WoWAddon-RollCurtain/issues/new) for reproducible bugs or unexpected behavior.

Include as much of the following as possible:

- Roll Curtain version, including the full beta version when applicable.
- World of Warcraft Retail version.
- Activity and difficulty where the issue occurred.
- Whether the bonus-roll prompt was suppressed, restored, resurfaced, or expired.
- What you expected to happen and what happened instead.
- Reproduction steps.
- Any relevant `/rc debug dump` output when testing a beta build.

## Compatibility

- World of Warcraft Retail 12.1.x.
- Blizzard's modern Settings panel.
- Optional ElvUI checkbox skin integration with native Blizzard styling as the fallback.
- No Ace3 or other addon libraries required.

## License

Roll Curtain is available under the [MIT License](LICENSE).
