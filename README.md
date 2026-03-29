# Maple DKP

Maple DKP is a lightweight World of Warcraft addon for Burning Crusade Classic style realms that tracks guild DKP, syncs values through addon messages, awards raid DKP for configured boss kills, and runs simple in-raid item auctions with a small popup UI.

## Current feature set

- Tracks DKP per guild member in a saved variable.
- Tracks current raid/party members in the DKP table so standings can include non-guild raiders in the run.
- Syncs DKP snapshots and live transaction updates through the guild addon channel.
- Lets guild leaders and officers manually add or set DKP values.
- Awards DKP to current guild raid members when a configured boss dies.
- Detects loot when an officer opens a boss corpse and shows it in a small control window.
- Notifies raiders about dropped items and opens a bidding popup when an item goes up for auction.
- Lets officers start timed auctions from the loot control window and watch bids update live.
- Automatically deducts DKP from the winning bidder when the auction closes.

## Installation

1. Put the `MapleDKP` folder inside your WoW addons directory.
2. The folder should contain `MapleDKP_TBC.toc`, `MapleDKP.lua`, and `README.md`.
3. Launch the Burning Crusade Anniversary client and enable the addon on the character screen.
4. If the client build uses a different interface number than `20505`, update the number in `MapleDKP_TBC.toc`.

## Slash commands

- `/mdkp`
  Shows help.
- `/mdkp show`
  Shows your current DKP.
- `/mdkp show PlayerName`
  Shows another guild member's DKP.
- `/mdkp standings`
  Shows the top ten DKP totals.
- `/mdkp history`
  Shows the ten most recent DKP changes.
- `/mdkp add PlayerName Amount Reason`
  Officer-only manual delta adjustment.
- `/mdkp set PlayerName Amount Reason`
  Officer-only hard set.
- `/mdkp award Amount Reason`
  Officer-only raid-wide award for current guild raid members.
- `/mdkp boss add NpcID Amount Boss Name`
  Officer-only boss configuration.
- `/mdkp boss list`
  Lists all configured boss values.
- `/mdkp auction start MinBid ItemLinkOrName`
  Officer-only auction start.
- `/mdkp bid Amount`
  Places or raises your bid. If your client does not have the active auction locally, it sends a bid request to the current raid leader.
- `/mdkp auction status`
  Shows the current auction and leading bid.
- `/mdkp auction close`
  Closes the auction and awards to the highest bidder.
- `/mdkp auction close PlayerName`
  Forces the winner to a specific bidder who already bid.
- `/mdkp sync`
  Requests a fresh snapshot from an officer, or broadcasts one if you are an officer.
- `/mdkp quiet on|off|toggle|status`
  Toggles local addon status output in chat.
- `/mdkp ui`
  Toggles the Maple DKP options window.
- `/mdkp options`
  Toggles the Maple DKP options window.

## Auction flow

1. An officer or raid leader kills a configured boss and the addon awards DKP to current guild raid members.
2. When that officer opens the loot window, Maple DKP records the dropped items and broadcasts them to guild members running the addon.
3. The officer uses the Maple DKP options window or loot control window to select an item and start a timed auction.
4. Raiders receive a popup that shows the item, minimum bid, time remaining, and a box to submit or raise a bid.
5. Silent bidding stays enabled during the timer: only the auction starter sees live bid amounts in the control window.
6. When the timer expires, the auction closes automatically, the winning bid is deducted from the winner's DKP, and the officer is told who should receive the loot.

## Notes and limits

- Boss auto-awards only fire for NPC IDs already configured in the addon database.
- The default boss list is a starter set, not a complete TBC encounter catalog.
- Sync currently uses the guild addon channel only, which keeps usage simple but assumes guild raiders are online and running the addon.
- Loot assignment still happens through the normal WoW loot window. The addon tells the officer who won but does not assign the item automatically.

## Recent patch notes

- Replay-based sync improvements:
  - player DKP changes are now stored as structured transactions with per-officer actor sequence tracking
  - snapshots now exchange compact actor-sequence summaries instead of replaying broad transaction dumps
  - missing player transactions can now be requested directly from a specific officer with targeted catch-up messages
- Conflict handling for stale manual edits:
  - stale DKP `set` operations now open conflicts instead of silently overwriting newer values
  - officers can review conflicts in the options UI and resolve them by keeping current, applying incoming, or manually setting a value
  - conflict resolutions now sync to other officers so open conflict state converges across clients
- Replay coverage expanded:
  - player deletes now run through the same replay/sync path as other player transactions
  - boss, raider, and new-member-default config messages now include transaction IDs for deduplication during sync
- Sync loop fix:
  - roster-driven sync no longer re-requests the guild roster from inside `GUILD_ROSTER_UPDATE`, which prevented repeated snapshot sends to the same officer while both clients remained online
- Members page layout now keeps all controls inside the window bounds.
- Members list remains 3 columns and now fills top-to-bottom in each column before moving left-to-right.
- Auction announcements now post to raid chat during bidding milestones:
  - item link, minimum bid, and time limit when auction starts
  - explicit "bidding starts now" message
  - 10-second warning before bidding ends
  - bidding stopped message when auction closes
  - winner announcement when closed
- Winner announcement now includes a post-close recap of all bidders and bid amounts (no live bid spam during the timer).
- DKP history window now supports mousewheel scrolling and includes clearer scroll-position indicators:
  - top/bottom reached hints
  - summary position label (Top/Middle/Bottom)
- Sync reliability improvements:
  - incoming TX updates now refresh leader, auction, history, and options views immediately
  - sync requests are throttled to reduce spam while still allowing catch-up
  - roster updates trigger a delayed/throttled sync request to catch up when officers come online later
  - snapshot broadcast targeting was fixed so guild-wide sync snapshots are accepted correctly
- Sync chat confirmations were added through normal addon chat output (visible when quiet mode is off):
  - snapshot sent confirmation
  - snapshot received/merged (or no-new-data) confirmation
- Quiet mode default is now enabled on fresh/unset settings.
- CurseForge/GitHub packaging support update:
  - added `.pkgmeta` to exclude `MapleDKP_TBC.toc` from packaged artifacts.