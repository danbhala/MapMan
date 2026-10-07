# Play stats

MapMan can send anonymous play stats to [PostHog](https://posthog.com)'s EU
cloud, so we can see which levels people quit on, where lives are lost and
how long the tutorial holds them. It only does so after the player says yes.
Claude reads the numbers through PostHog's MCP connector.

## How it works

- `godot/scripts/stats.gd` (autoload `Stats`) queues events and sends them in
  batches to `https://eu.i.posthog.com/batch/` every 30 seconds, when 20 are
  waiting, and when the app goes to the background. Up to 300 wait while
  offline (kept in `user://stats.cfg`).
- **Nothing happens without a yes.** Before an answer, and after a no, no
  event is queued or sent. Saying no (or turning PRIVACY > SHARE PLAY STATS
  off) deletes the random install ID and anything unsent; a later yes starts
  a new ID.
- `godot/scripts/stats_sheet.gd` asks the question (sheet 001-J) the first
  time the main menu would open, so a first launch's steering choice and
  tutorial (`FirstRun`) come first. YES and NO look the same. A yes is asked
  again after six months, as the Irish DPC asks; a no is never asked again.
  Options > PRIVACY (sheet 001-I) switches stats on and off, opens the privacy
  policy and shows the start of the stats ID for deletion requests.
- The privacy policy is `site/privacy.html`, published by the Pages workflow
  at https://danbhala.github.io/MapMan/privacy.html. Change it whenever the
  events change.
- `mapman/stats/posthog_key` in `project.godot` is the PostHog project API
  key (`phc_...`). It can only send events, so it is safe in the repo. Empty
  turns stats off entirely: no question, no PRIVACY row. Headless runs (tests,
  tools) never send.

## What each event carries

Every event: `distinct_id` (the random install ID), `session` (random per
launch), `build` (`dev` or `release`), `app_version`, `commit`, `platform`, and
`$process_person_profile: false` (no person profiles). Never a name, account,
advertising ID or device ID.

Level events (`Stats.of()` in `main.gd`) add `level`, `revision` (`A`, or `B` for Revision B), `mode` (`main`,
`practice`, `tutorial` or `custom`), `lives` and `lost_here` (lives lost on
this level this session, which says which assist was on).

| Event | When | Extra |
|---|---|---|
| `app_open` | launch | `controls`, `tilt_sensitivity`, `language`, `furthest_level`, `finished` |
| `stats_on` | the player says yes | as `app_open` |
| `level_start` | a try begins | |
| `level_clear` | the exit is reached | `time_left`, `stars` |
| `life_lost` | death tile or time out | `reason`, `time_left`, `x`, `y` (the tile) |
| `level_skip` | SKIP THIS SHEET after six losses | |
| `quit` | back to the menu from a game | `after_clear`, `time_left` |
| `game_over` | the last life is lost | `level`, `score` |
| `tutorial_done` | the last lesson is cleared | |
| `game_finished` | level 100 is cleared | `score`, `lives` |
| `replay_watched` | WATCH REPLAY | |
| `look_worn` | a look is put on | `look` |

## Setting up PostHog (once)

1. Sign up at https://eu.posthog.com (the EU region) and create a project.
2. In Project settings, turn on **Discard client IP data**.
3. Put the project API key in `project.godot` (`mapman/stats/posthog_key`).
4. Connect the PostHog connector in claude.ai so Claude can query it.
5. Google Play Console > App content > Data safety: declare "App
   interactions" and "Other actions" collected, optional, not shared, for
   analytics.
