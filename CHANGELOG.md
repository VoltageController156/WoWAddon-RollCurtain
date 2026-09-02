# Changelog

## 0.0.4

### Fixed

- Fixed a native World of Warcraft client crash associated with the minimap icon texture shipped in 0.0.3.
- Re-encoded the minimap die icon as a compatibility-safe RGB PNG while preserving the approved die artwork and minimap button behavior.

## 0.0.3

### Added

- Added recoverable bonus-roll suppression. When Roll Curtain hides a prompt, chat now shows **[Show Bonus Roll Prompt]** so the original Blizzard prompt can be restored while it is still active.
- Added the `show` subcommand as a fallback: `/rollcurtain show`, `/rcurtain show`, `/rollc show`, or `/rc show`.
- Added shorter `/rollc` and `/rc` aliases for all Roll Curtain slash commands.
- Added a draggable minimap button with a dedicated die icon:
  - Left-click opens Roll Curtain settings.
  - Right-click restores a recoverable hidden bonus-roll prompt.
  - The button glows while a hidden roll can still be restored.
  - Minimap position persists between sessions and works with generic minimap-button collectors.

### Changed

- Redesigned raid settings around a top-level **Raids** switch with Story, LFR, Normal, Heroic, and Mythic options displayed horizontally beneath it.
- Enabling **Raids** selects Story by default while leaving the other raid difficulties opt-in.
- Deselecting the final enabled raid difficulty automatically disables the top-level **Raids** switch and collapses the difficulty row.
- Updated the settings panel layout, spacing, Defaults button, and version/author footer.
- Added optional ElvUI checkbox skin integration while retaining the native Blizzard settings appearance as the fallback.

### Fixed

- Hidden bonus-roll timers now continue to expire normally while the prompt is suppressed; restoring a prompt synchronizes Blizzard's remaining-time display before showing it again.
- Restoring a hidden prompt only reopens the original Blizzard prompt. It does **not** automatically roll or spend bonus-roll currency.
- Improved migration from 0.0.1 and 0.0.2 raid settings into the new raid master/difficulty model.

## 0.0.2

- Added separate raid suppression options for Story Mode, Raid Finder (LFR), Normal, Heroic, and Mythic.
- Added raid difficulty detection using Blizzard's instance difficulty IDs.
- Migrates the 0.0.1 generic raid preference to the new per-difficulty settings on upgrade.
- Added MIT license and project metadata to the add-on TOC for distribution.

## 0.0.1

- Initial release.
- Configurable suppression for Delves, Prey hunts, outdoor content, dungeons, raids, and other scenarios.
- Added `/rollcurtain` and `/rcurtain` commands.
