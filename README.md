# Roll Curtain

<img src="assets/roll-curtain-icon.png" alt="Roll Curtain icon" width="180">

Roll Curtain is a lightweight World of Warcraft Retail add-on that hides bonus-roll prompts in the activities you choose, lets you recover a hidden prompt before it expires, and can require confirmation before a bonus-roll token is spent.

By default, fresh installs hide the prompt in:

- Delves
- Prey hunts
- World bosses and other outdoor content
- Normal dungeons
- Heroic dungeons
- Mythic dungeons

Mythic+, raids, and other scenarios remain visible unless you enable those options.

## Configuration

Open **Options → AddOns → Roll Curtain** and check the activities where you do not want to see a bonus-roll prompt.

### Dungeons

Dungeon suppression uses a top-level **Dungeons** switch with a horizontal row for:

- Normal
- Heroic
- Mythic
- Mythic+

On a fresh install, Normal, Heroic, and Mythic are selected while Mythic+ remains opt-in. Turning Dungeons off clears all four difficulties. If the final selected dungeon difficulty is cleared manually, the Dungeons switch turns off and the row collapses.

Existing users upgrading from the old generic Dungeons option keep their prior behavior: an enabled generic Dungeon setting migrates to all four known dungeon difficulties enabled, while disabled remains fully disabled.

### Raids

Raid suppression uses a top-level **Raids** switch. Enabling it reveals Story, LFR, Normal, Heroic, and Mythic options in a horizontal row. Story is selected automatically when Raids is first enabled; the other difficulties remain opt-in.

### Bonus-roll confirmation

**Confirm before using a bonus roll** is enabled by default in the Safety section.

When you click Blizzard's bonus-roll die, Roll Curtain shows a confirmation containing:

- Your active loot specialization
- The number of bonus-roll tokens that will remain after the roll

**Confirm** proceeds through Blizzard's normal bonus-roll action. **Cancel** leaves the original bonus-roll prompt available. Disabling the setting restores Blizzard's normal one-click behavior.

### Slash commands

All four aliases use the same command handler:

- `/rollcurtain`
- `/rcurtain`
- `/rollc`
- `/rc`

Available subcommands:

- `status` — show how the current activity is classified and whether Roll Curtain would hide its prompt.
- `show` — restore the most recently hidden bonus-roll prompt if it is still active.
- `reset` — restore Roll Curtain's default settings.

For example: `/rc show` or `/rollcurtain status`.

## Recovering a hidden bonus roll

When Roll Curtain suppresses a bonus-roll prompt, chat shows:

**Bonus roll hidden [Show Bonus Roll Prompt]**

Click **[Show Bonus Roll Prompt]** to restore Blizzard's original prompt while it is still active. Restoring it does **not** perform the roll and does not spend currency; you must still click Blizzard's Roll button yourself.

The hidden prompt continues to expire normally while suppressed, and Roll Curtain synchronizes the remaining timer when the prompt is restored.

## Minimap button

Roll Curtain includes a draggable minimap button with a die icon.

- **Left-click:** open Roll Curtain settings.
- **Right-click:** restore a recoverable hidden bonus-roll prompt.
- The button glows while a hidden bonus roll can still be restored.
- Its minimap position is saved between sessions.
- The button is designed to work with generic minimap-button collectors.

## Installation

1. Download the latest release.
2. Copy the `RollCurtain` add-on folder into `_retail_/Interface/AddOns/`.
3. Restart World of Warcraft or type `/reload` if the game is already running.
4. Enable **Roll Curtain** in the AddOns list.

## Activity detection

- **Delves:** detected through Blizzard's active-Delve APIs.
- **Prey hunts:** detected through Blizzard's active-Prey-quest API.
- **World bosses / outdoor content:** any bonus-roll prompt received outside an instance.
- **Dungeons:** detected from Blizzard's instance type and difficulty ID, with explicit Normal, Heroic, Mythic, and Mythic+ controls. Unrecognized dungeon difficulties fail open.
- **Raids:** detected from the current instance type and Blizzard difficulty ID, with separate Story, LFR, Normal, Heroic, and Mythic controls beneath the Raids master switch.
- **Other scenarios:** detected from the current instance type after Delves are excluded.
- **Unknown content:** the prompt remains visible as a safety fallback.

If a Prey hunt is active while you complete a different outdoor encounter, that prompt may be classified as Prey because Blizzard's bonus-roll event does not include a distinct activity type.

## Compatibility

- World of Warcraft Retail 12.1.x
- Uses Blizzard's modern Settings panel.
- Optional ElvUI checkbox skin integration; native Blizzard settings remain the fallback.

## License

Roll Curtain is available under the [MIT License](LICENSE).
