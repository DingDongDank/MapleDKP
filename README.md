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
2. The folder should contain `MapleDKP.toc`, `MapleDKP.lua`, and `README.md`.
3. Launch the Burning Crusade Anniversary client and enable the addon on the character screen.
4. If the client build uses a different interface number than `20504`, update the number in `MapleDKP.toc`.

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