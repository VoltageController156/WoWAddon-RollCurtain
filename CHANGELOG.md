# Changelog

## 0.0.8

### Added

- Added a live hidden-roll expiration countdown to suppression chat notifications and the minimap tooltip, including the server-time deadline for the active roll.
- Added a one-time per-character first-run setup with **Recommended**, **Outdoor Only**, and **Configure Manually** choices. The Recommended view explains which activities are suppressed and which remain visible before opening the full settings panel.
- Added profile import/export using a validated, shareable Roll Curtain profile string for moving settings between characters or installations.
- Added an optional **Play a sound when a bonus roll is suppressed** setting.
- Added a suppression-sound picker with built-in Blizzard sounds, optional LibSharedMedia-3.0 sounds registered by other installed addons, and a **Test Sound** preview button.
- Added a per-character **What's New** panel for meaningful release lines; beta suffix updates within the same feature line do not repeatedly show it.

### Changed

- Reworked the suppression-sound picker into a compact DBM-style 200px scrollable menu. Each sound now has a speaker preview button on the right, and selecting a sound no longer automatically plays it.

### Fixed

- Fixed suppressed bonus-roll prompts resurfacing after teleporting or zoning into another dungeon while the original roll was still active.
- Treats Blizzard's reconstructed copy of the same active bonus roll as the existing suppressed roll even when its rebuilt expiration timestamp drifts by a few seconds.
- Keeps protection against a genuinely new bonus roll inheriting stale suppression state when Blizzard reuses `BonusRollFrame`.
- Prevented the suppression chat notification from being sent again when Blizzard reconstructs the same already-hidden roll during zone transitions; the original content label and restore state are preserved.
- Fixed the Profiles page Import / Export controls overlapping the ElvUI-style delete and profile-assignment sections.

## 0.0.7

### Added

- Added a dedicated **Profiles** settings page with current-profile selection, create, copy, rename, delete, and a per-profile list of assigned characters.
- Added profile-backed, multi-select **Chat Notifications** destinations. General is enabled by default, with optional local routing for Loot, System, Say, Yell, Party, Raid, Instance, Guild, Officer, Whisper, Battle.net Whisper, Emote, and Channel Messages.
- Added a **Debug** settings page for beta/development builds with optional event logging and a diagnostic snapshot covering build channel, profile, content detection, difficulty, suppression state, hidden-roll state, chat destinations, and minimap recovery state.
- Added `/rc debug on`, `/rc debug off`, `/rc debug status`, and `/rc debug dump` diagnostics. Stable builds retain these support commands but keep debug disabled, session-only, and hidden from the Settings UI.
- Added a safe **Test Recovery Glow (15 sec)** debug preview and `/rc debug glow` so the minimap recovery indicator can be tested without creating or spending a real bonus roll.

### Changed

- New profiles now begin as a copy of the currently active profile instead of resetting to Roll Curtain defaults.
- Refined the Profiles page with an ElvUI-inspired information hierarchy and optional ElvUI skin integration while retaining Blizzard-native styling when ElvUI is not loaded.
- Renamed the character/profile summary to **Profile Assignments** and simplified the list so each profile is followed directly by its assigned characters.
- Updated the suppressed-roll notification to `Roll Curtain: Bonus roll suppressed - <Content> - [Restore Bonus Roll]` with the existing clickable restore behavior.
- Chat destination settings only control local chat-window display and never transmit Roll Curtain notifications to other players.
- Reworked the minimap recovery indicator from the square action-button border into a circular warm-gold ring with a subtle pulsing outer shine, better matching the round Roll Curtain icon and minimap-button collectors.
- The minimap recovery glow now refreshes immediately when a roll is suppressed or restored and continues to follow the hidden roll until it expires or becomes unavailable.
- Established a persistent beta release channel for pre-production testing before stable releases are promoted to `main`.
- Packaged builds now stamp an explicit release channel so beta diagnostics are exposed only in beta/development builds while stable packages identify themselves as `release`.

### Fixed

- Cleaned duplicate `Character - Unknown` profile/minimap records once a realm-qualified character identity is available, while preserving orphaned assignments until that character can be reconciled safely.
- Unresolved `- Unknown` character identities are no longer shown in the Profiles assignment list.

## 0.0.6

### Fixed

- Fixed previously suppressed bonus-roll prompts resurfacing when leaving a dungeon and entering the same or another instance while the original roll was still active.
- Suppressed rolls now remain hidden across instance transitions until they expire or the player explicitly restores them with Roll Curtain.
- Hardened transition handling for Blizzard's reused `BonusRollFrame` so a brand-new roll cannot accidentally inherit suppression state from an older hidden roll.

## 0.0.5

### Added

- Added an optional bonus-roll confirmation prompt, enabled by default, that shows the active loot specialization and the number of bonus-roll tokens that will remain after confirming.
- Added a safe **Preview Confirmation** button so the confirmation UI can be inspected without an active roll or spending currency.
- Added per-difficulty dungeon suppression controls for Normal, Heroic, Mythic, and Mythic+ beneath a top-level **Dungeons** switch.
- Added named profiles with per-character profile assignment, including create, copy, rename, delete, and profile selection controls.
- Added a **Show minimap button** setting that hides the minimap button without losing its saved per-character position.
- Added a **Commands & Help** settings subpage documenting slash commands, aliases, minimap controls, and profile behavior.

### Changed

- Dungeons now use the same expandable parent/child settings behavior as Raids. Clearing the final selected dungeon difficulty automatically disables and collapses Dungeons.
- Fresh installs and legacy enabled Dungeon settings suppress Normal, Heroic, and Mythic by default while leaving Mythic+ opt-in.
- Reworked the Roll Curtain and Commands & Help settings pages with Blizzard-style scrolling so expanded controls and documentation remain readable without being compressed or clipped.
- `/rc reset` now resets only the currently active profile.
- `/rc status` now reports the active profile and bonus-roll confirmation state in addition to current content classification.
- Existing flat Roll Curtain settings migrate into the Default profile, while the legacy minimap position migrates to per-character storage.

### Fixed

- Replaced the corrupted minimap icon asset with a verified PNG with transparent corners so the Roll Curtain die renders correctly without a green invalid-texture square or square background.
- Corrected legacy false-value migration handling for old generic Dungeon and Raid settings.

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
  - Left-click opens settings.
  - Right-click restores a hidden bonus-roll prompt.
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