# Ads

MapMan shows ads through Google AdMob, using Poing Studios' Godot plugin
(`godot/addons/admob/`, vendored; see its `MAPMAN.md` for the two local
patches and how to update it). There are no banners anywhere.

## What the player sees

- **KEEP GOING**: when the last life goes, the lost-life sheet offers one
  more life on the same sheet for a rewarded ad, once per game.
- **DOUBLE IT**: the level clear offers to double the sheet's points for a
  rewarded ad, on the slip a released look would use (a release wins).
- **The full-screen ad**: NEXT on the level clear shows an interstitial at
  most once every 3 clears, and never within 3 minutes of any ad, rewarded
  ones included.
- **Never**: levels 1 to 10, the tutorial, practice, the drafting table,
  replays, at launch or straight after a death. The free skip the assists
  give after 6 losses stays free.
- **AD PRIVACY** on Options reopens Google's consent form, where Google says
  one is needed (the EU and UK).

With no connection, no consent, no ad loaded or ads switched off, nothing
is offered and NEXT goes straight on: the game never waits on an ad.

## Code

- `godot/scripts/ads.gd` (autoload `Ads`): the pacing rules, the unit IDs
  and what is ready. Dev builds always use Google's test units: AdMob
  suspends accounts whose developers tap their own ads.
- `godot/scripts/ads_admob.gd`: the only file that touches the plugin.
  Loaded only on a phone, so tests and the desktop never see it. Runs the
  consent form (UMP), starts the SDK (content rating PG), and loads and
  reloads each ad with a backoff.
- `godot/scripts/ad_offers.gd` (`main.ad_offers`): the game-flow side for
  `main.gd`.
- `godot/scripts/clear_sheet.gd` `ad_slip()`: the DOUBLE IT slip.
- Tests set `Ads.fake`: every rewarded ad is ready and rewards at once
  (`tests/unit/test_ads.gd`).
- The DEV menu has "No ads", "Full-screen ad every clear" and "Ask for ad
  consent again".

## IDs

The app ID is in `godot/project.godot` (`admob/general/android/app_id`), the
ad unit IDs in `godot/scripts/ads.gd` `UNITS`. iOS ads stay off
(`admob/general/ios/enabled`) until the iPhone build ships.
