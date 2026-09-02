# Roll Curtain

![Roll Curtain icon](assets/roll-curtain-icon.png)

Roll Curtain is a lightweight World of Warcraft Retail add-on that hides the bonus-roll prompt in the activities you choose.

By default, it hides the prompt in:

- Delves
- Prey hunts
- World bosses and other outdoor content

It leaves the prompt visible in dungeons, each raid difficulty, and other scenarios unless you explicitly enable those options.

## Configuration

Open **Options → AddOns → Roll Curtain** and check the activities where you do not want to see a bonus-roll prompt.

You can also use:

- `/rollcurtain` or `/rcurtain` — open the settings panel
- `/rollcurtain status` — show how the current activity is classified
- `/rollcurtain reset` — restore the default selections

Changes apply immediately to the next bonus-roll prompt. Roll Curtain only hides the client-side prompt; it does not spend currency or make a roll for you.

## Installation

1. Download or clone this repository.
2. Copy the `RollCurtain` add-on folder into `_retail_/Interface/AddOns/`.
3. Restart World of Warcraft or type `/reload` if the game is already running.
4. Enable **Roll Curtain** in the AddOns list.

## Activity detection

- **Delves:** detected through Blizzard's active-Delve APIs.
- **Prey hunts:** detected through Blizzard's active-Prey-quest API.
- **World bosses / outdoor content:** any bonus-roll prompt received outside an instance.
- **Dungeons and scenarios:** detected from the current instance type.
- **Raids:** detected from the current instance type and Blizzard difficulty ID, with separate settings for Story Mode, LFR, Normal, Heroic, and Mythic.
- **Unknown content:** the prompt remains visible as a safety fallback.

If a Prey hunt is active while you complete a different outdoor encounter, that prompt may be classified as Prey because Blizzard's bonus-roll event does not include a distinct activity type.

## Compatibility

- World of Warcraft Retail 12.1.x
- Uses the modern Settings panel introduced in Dragonflight and updated for current Retail.

## License

Roll Curtain is available under the [MIT License](LICENSE).
