# The Toolbox

Stars collected on the sheets go into a bank, and the bank buys a tree of
nine tools that make the sheets kinder: a hand that reaches into the drawing,
new moves for MapMan, and tools that bend the clock. Every tool is finite and
every star is earned in play: there is nothing to buy with money here (the
star shop, if it comes, is a separate design).

## For players

- **Opens** once the drafting table does: level 11 reached, or the game
  finished. Sheet 001 gains a TOOLBOX row over MapMan with the stars in the
  bank; the pause sheet a third row (tools apply to the sheet being played);
  the level clear a TOOLBOX button under WATCH REPLAY, with a line saying what
  the sheet just paid in.
- **The star bank.** A cleared sheet pays, once each: every star tile on it
  (a sheet that was cleared with two of three stars pays the third on a
  later clear), one star for the clear, and one quick star for clearing with
  ten seconds or more left. Revision A and B sheets bank separately, so the
  100 sheets twice come to 503 stars; the whole tree costs 1,455, so the
  toolbox is a set of choices, not a checklist. Practice, the tutorial and
  drafting-table levels pay nothing.
- **Three branches, three tools each, three tiers each.** Tier I of a tool
  opens the tool under it; each tier costs more and strengthens the tool.
  Tapping a tool shows its card: what it does, how often it works, its tiers,
  BUY, and PUT ON BELT.

  | Branch | Tool | Works | I | II | III |
  |---|---|---|---|---|---|
  | YOUR HAND | ERASER: tap a skull to rub it out, hidden or not, until the next try | recharges | ★15, 6 s | ★30, 5 s | ★60, 4 s |
  | | LIGHT TABLE: the hidden tiles show through for a moment | once a try | ★30, ½ s | ★60, 1 s | ★100, 1½ s |
  | | PUSH PIN: tap spikes or a crumble tile to hold it as it is | recharges 10 s | ★25, 3 s | ★50, 5 s | ★90, 8 s |
  | HIS FEET | HOP: over the next tile the way he faces | recharges | ★15, 1 tile, 8 s | ★30, 1 tile, 5 s | ★60, 2 tiles, 5 s |
  | | HARD HAT: the first skull on a sheet doesn't get him | once a sheet | ★30 | ★50, spikes too | ★100, twice |
  | | SECOND DRAFT: out of lives, back up on the same sheet | once a game | ★40, 8 s | ★70, 15 s | ★120, 15 s, twice |
  | THE CLOCK | SLOW-MO: half speed, music too | once a try | ★15, 2 s | ★35, 4 s | ★70, 6 s |
  | | FIRST LOOK: the clock waits at the start of every try | every try | ★20, 2 s | ★40, 3 s | ★80, 4 s |
  | | STOP CLOCK: the countdown stops while he walks | once a sheet | ★40, 2 s | ★70, 3 s | ★110, 5 s |

- **The belt** carries two tools into the sheets (three from sheet 50, or
  once the game is finished). A tool just bought goes on when there is room.
  On a sheet the belt sits at the left end of the bottom bar: a round button
  per tool, drawn like the tilt gauge, that never pauses the game. A white
  ring sweeps while it recharges, a coloured ring drains while its effect
  runs, and it fades when the sheet has had its uses. The Eraser and Push
  Pin arm on a tap (a gold ring) and take the next tap on a tile; a tap off
  the sheet puts them away. The Hard Hat, Second Draft and First Look work
  by themselves.
- **FRESH SHEET** (★40, bought once) takes every star spent on tools back
  into the bank and clears the tree and the belt, as often as wanted, but
  only between sheets, never from a pause.
- **Where tools work:** the main game (Revision A and B) and practice. Not
  the tutorial, the ending, or a drafting-table level (a friend's sheet is
  played as drawn). First Look holds the clock before it starts and ends on
  a lean or a tap; Slow-mo holds through a pause (the sheets run at full
  speed) and runs on afterwards; Stop Clock freezes the countdown and the
  bar turns gold, Slow-mo turns it lilac and two faint MapMen trail him.
  Second Draft replaces the game over sheet: one life, the same sheet, its
  seconds on the clock. The Hard Hat's skull stays showing and the tile stays
  safe while he stands on it. A hop records as quick steps, so replays and
  the best-run ghost walk the tiles he hopped over.
- **Dev builds:** the DEV menu's "+100 stars" fills the bank (and opens the
  toolbox), "Own every tool" buys the whole tree at tier III with Fresh Sheet,
  and "Empty the toolbox" puts it back as a new player finds it.

## For developers

- `godot/scripts/toolbox.gd` (`Toolbox`, `main.toolbox`) is the rules:
  `TOOLS` (id, name and blurb msgids, branch, kind, limit, tiers with price
  and strength), `TIER_TEXT`, the bank and shop as statics on a `Save`
  (`bank_sheet`, `buy`, `buy_fresh_sheet`, `refund`, `set_on_belt`,
  `belt_slots`, `unlocked`, `spent_stars`), and the tools in play: `tier()`
  is a tool's tier when it is on the belt and tools apply to the sheet
  (`enabled()`), `use()` from the belt, `field_tap()` for an armed tile tool,
  `update()` each frame for recharges, pins and running effects (Slow-mo on
  the wall clock), `hat_saves()`, `revive()`, `look_update()` while the sheet
  waits, `bank_stars()` on a clear, `update_belt()`, and `action()` for the
  sheet's menu actions ("toolbox", "toolbox pause", "toolbox back", "fresh
  sheet", "tool <id>", "buy <id>", "belt <id>"). `begin_game()`,
  `begin_sheet()`, `begin_try()` and `stop()` reset what each limit allows.
- `Save` keeps `bank`, `tools` (id → tier), `belt`, `fresh_sheet` and `banked`
  (sheet key "A35"/"B35" → what it has paid) in the `[toolbox]` section;
  `Save.toolbox_open()` is `drafting_open()`.
- `godot/scripts/toolbox_sheet.gd` draws sheet 001-T (three columns of
  nodes, the card, the belt strip, Fresh Sheet, the way back) and the main
  menu's row; `godot/scripts/tool_belt.gd` the belt on the HUD (`Hud.belt_room`
  moves the effect icons along); `godot/scripts/tool_icons.gd` the icons,
  SVG drawn at the scale shown so they stay crisp; `clear_sheet.gd` the
  bank line and button on the level clear.
- `main.gd` hooks: `toolbox.field_tap()` before a tap pauses, `hat_saves()`
  before `lose_life()` on a skull or spikes, `toolbox.revive()` in
  `finish_lose_life()`, `look_update()` in the loaded-but-not-started branch,
  `clock_stopped()` in `_update_timer()`, `hop_lift()` lifts him mid-hop,
  `toolbox.suspend()`/`resume()` around the pause sheet.
- `level_map.gd`: `pinned` keys keep spikes down and crumble tiles whole;
  `erase_tile()`, `hop()`, `hopping()`, `move_share()`.
- Tests: `tests/unit/test_toolbox.gd` (the bank, buying, Fresh Sheet, the
  belt, each tool, the sheet's actions); `test_menus.gd` the rows and
  buttons; `test_i18n.gd` opens sheet 001-T in four states in every language.
