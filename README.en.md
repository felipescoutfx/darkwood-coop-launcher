🇧🇷 [Versão em português](README.md)

# Darkwood Co-op - Launcher

Installer/updater for the Darkwood online co-op mod (dev/testing between friends).

## First time

1. Download **[DarkwoodCoopLauncher.exe](https://github.com/felipescoutfx/darkwood-coop-launcher/releases/latest/download/DarkwoodCoopLauncher.exe)** (a single file - no zip, nothing to install) and double-click it.
   - Windows/SmartScreen may warn "unknown publisher" (the `.exe` isn't digitally signed) - click **More info → Run anyway**. That's expected for a mod tested between friends, not a virus.
2. Check the **Darkwood folder** at the top (the launcher tries to find it automatically).
3. On the **Main** tab, click **Install BepInEx + Mod**.
4. Click **Play**.

**Both host and client use the same launcher** - everyone installs the mod the same way.

The launcher **updates itself**: every time it opens, it checks for a new version published
here and, if there is one, downloads it and reopens automatically - you never need to
re-download the `.exe` or the repository because of a launcher update.

Prefer Portuguese, or want the launcher itself in English? There's a language button
(**PT/EN**) in the title bar - click it and the launcher restarts in the other language.

## Playing together (new flow, via Steam invite)

- **HOST:** opens the game, loads the save, presses **F7** (host). Then invites the friend
  via the **Steam friends list** ("Join Game" / "Invite to Play" button).
- **CLIENT:** clicks **"Join Game"** in Steam. **Nothing else to do** - the mod downloads
  the host's save, loads it automatically and connects on its own.

The host's save is written as a **new save** in your profile list (it doesn't overwrite your
own). Each host gets a fixed slot - reconnecting to the same host always reuses the same slot.

## Mod updates

When the launcher opens, it shows a warning (in orange, on the Main tab) if a **new mod
version** has been published. If it does, click **Update mod**.

## Advanced tab (only if you need it)

- **Host's SteamID64** + **Pull host's save NOW (P2P)**: downloads the host's save BEFORE
  opening the game (the host needs to have Darkwood open). Useful if you don't want to use
  the Steam invite.
- **Sync save (old method)**: downloads a save manually published to the repo,
  OVERWRITING your own. Only use this if the other methods don't work.
- **Send log to developer**: if something goes wrong, this button uploads the game log and
  generates a **link** (copied automatically). Send that link to the developer so they can
  see what happened.

## Current limitations (mod still in development)

- The host needs to press **F7** to host (design decision - the host controls when the
  session opens for co-op).
- Weather, time of day, night events and story flags can still diverge during a session
  (future work). What already syncs live: position, enemies, doors, furniture, containers,
  dropped items, traps, downed/revive state.
- Per-player character save (inventory/health by SteamID) is new and lightly tested.
