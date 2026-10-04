# The wardrobe: looks to collect for MapMan

> **Status: proposal, October 2026. Nothing here is in the game yet.** Every
> picture comes from a design prototype that runs the game's own `Player`
> animation code ([the prototype](#the-prototype)). Read this before building
> any part of it.

A WARDROBE on the main menu starts as rows of question marks. Each time you
clear a 5th level for the first time, one look is released. The rarer looks
only come late in the game, and finishing the game releases MapWoman. You wear
one look at a time, like a character skin: never a hat plus somebody else's
coat.

![The collection](sheets/01_collection.png)

- [What you unlock, and when](#what-you-unlock-and-when)
- [How players meet it](#how-players-meet-it)
- [How to build it](#how-to-build-it)
- [Rules for future sessions](#rules-for-future-sessions)
- [Testing](#testing)
- [Roadmap](#roadmap)
- [Open questions](#open-questions)
- [The prototype](#the-prototype)

Contact sheets, all in [`sheets/`](sheets/):

| Sheet | What it shows |
| --- | --- |
| [01 collection](sheets/01_collection.png) | the 21 looks and Classic, by tier |
| [02 poses 1](sheets/02_poses_1.png), [2](sheets/02_poses_2.png), [3](sheets/02_poses_3.png) | every look in the 11 poses the game puts him in |
| [03 bench](sheets/03_bench.png) | 8 alternates, same pose check |
| [04 at playing size](sheets/04_at_playing_size.png) | real levels and tiles, at the baselines' 2× |
| [05 caught by the pose check](sheets/05_caught_by_the_pose_check.png) | 9 bugs in the first draft, and the 3 rules that fixed them |
| [06 in the menus](sheets/06_in_the_menus.png) | main menu, sheet 001-D, the release slip, the end ([singly](sheets/)) |

There is also an animated contact sheet: every look walking, turning away,
landing, hopping, spinning, stuck, shaking free, dying and coming back. It isn't
committed (a 5 MB video); `prototype/render.sh --video` makes it again.

## What you unlock, and when

**One look every 5 levels, plus MapWoman for finishing: 21 to collect, 22 with
Classic.** Every 10 would give only ten looks across a hundred levels, and a
new player would wait ten levels for the first. Every 5 brings the first
within a few minutes (a level is a 20-second sheet). From level 70 the
checkpoints are every 5 levels too, so the releases from 70 to 95 all arrive
on checkpoint sheets.

Rarity is how late a look comes and how much there is to it:

| Tier | Levels | What a look in it is | On the sheets |
| --- | --- | --- | --- |
| Common | 5–25 | a colour or a small hat: one part, nothing moving | white |
| Uncommon | 30–50 | a bigger hat with a matching piece, or a special finish | mint |
| Rare | 55–75 | a whole outfit: head, body and legs | lilac |
| Epic | 80–95 | outfits that move or change shape: a cape, sparkles, a glass helmet, a box head | pink |
| Legendary | 100 | Solid Gold | gold |
| Special | the end | MapWoman | gold |

| Level | Look | Tier | What he wears | Why there |
| --- | --- | --- | --- | --- |
| start | Classic | | MapMan as he is | worn until you pick something |
| 5 | Party hat | Common | striped cone, pom-pom | first release, minutes in: a party for finding the wardrobe |
| 10 | Signal red | Common | red body and legs | first checkpoint |
| 15 | Bobble hat | Common | knitted hat, cuff, pom-pom | |
| 20 | Racing green | Common | green with two white stripes | checkpoint |
| 25 | Shades | Common | sunglasses | just after the first wall of death tiles (24–26) |
| 30 | Blueprint | Uncommon | white linework with centre lines: he becomes the drawing | checkpoint |
| 35 | Cowboy | Uncommon | hat and red bandana | level 35 has one of the tightest clocks |
| 40 | Hard hat | Uncommon | hard hat and hi-vis vest, the site engineer | checkpoint |
| 45 | Top hat | Uncommon | top hat, red bow tie, monocle | |
| 50 | Neon | Uncommon | dark body in a glowing cyan and pink outline | halfway, checkpoint |
| 55 | Doctor | Rare | white coat, stethoscope, head mirror | |
| 60 | Pirate | Rare | tricorn, eye patch, striped shirt | checkpoint |
| 65 | Pumpkin head | Rare | jack-o'-lantern head with a glowing carved face | Halloween; after level 62's tight clock |
| 70 | Skeleton | Rare | skull, ribs and leg bones | Halloween; checkpoint |
| 75 | Explorer | Rare | pith helmet, compass, a rolled map on his back | his day job; after level 72's tight clock; checkpoint |
| 80 | Astronaut | Epic | glass helmet, white suit, chest panel | checkpoint |
| 85 | Robot | Epic | box head, LED eyes, antenna | checkpoint |
| 90 | Superhero | Epic | mask, a gold cape that flies out behind | checkpoint |
| 95 | Wizard | Epic | bent hat, long beard, starry robe, sparkles as he walks | checkpoint |
| 100 | Solid gold | Legendary | gold all over, with a twinkle | the last sheet |
| the end | MapWoman | Special | play as her: MapMan waits for you at the end | finishing the game |

"Tight clock" is from `python3 godot/tools/level_report.py`: levels 35, 62 and
72 have negative slack on the safe route, so they need time tiles.

**MapWoman** is the figure the game already draws at the end (`art =
"woman"`, MapMan with a bow). What makes her special is the ending: wearing
her, the roles turn round. MapMan waits on the bonus map and she walks to
him, which is a reason to play the game through again.

**The bench** ([sheet 03](sheets/03_bench.png)) has eight more, drawn and
pose-checked: Chef, Viking, Ninja, Vampire, King, Propeller cap, Bumblebee and
Graduate. Swap any of them into the list, or keep them for a second wave
released by feats rather than levels: Graduate for finishing the tutorial,
Bumblebee for 100 stars in all, Ninja for ten levels in a row without losing a
life, King for finishing with all three lives. Feats need counters the save
doesn't keep yet (stars in all, streaks).

**Fixed or random?** Fixed is recommended. Each question mark can then say
exactly when it is released ("LV 35"), which gives the player a goal. We choose
the first look (a hat, not a colour). Everyone has the same game to talk about,
and tests stay simple. The surprise survives: nobody knows what is behind LV 35
until they clear it. If you want chance in it, keep the tiers fixed and shuffle
the order *within* a tier per save. Store the shuffled ids in the save, so
adding looks later never changes what a player already has. The cost is a seed
in the save, one more test, and question marks that show only the tier.

**Players who already have progress** get everything they have earned on the
first launch with a wardrobe, marked NEW (see [Save](#save)).

## How players meet it

![In the menus](sheets/06_in_the_menus.png)

1. **Main menu (sheet 001).** A WARDROBE row under MapMan shows the count, plus
   a NEW tag while a released look is unseen. Tapping MapMan himself could open
   it too. MapMan wears the chosen look on every sheet. Why not a sixth row in
   the parts list: the five rows of 44 already run from y 80 to 300 on a sheet
   375 high, and a sixth would push the note into the frame.
2. **Sheet 001-D, WARDROBE.** All 22 looks in release order, six to a row, each
   cell framed in its tier colour. Locked looks are drawn in dashed *hidden
   lines* (the drafting convention for parts you can't see), with a question
   mark and the level that releases them. Tap a released look and MapMan on
   the right puts it on at once (and it is saved). A WORN stamp lands, and the
   dimension line measures him with his hat on (107 in the cowboy hat instead
   of 92). Tapping a locked cell says "RELEASED AT LEVEL 55" and keeps the name
   secret.
3. **The release.** The first time a 5th level is cleared in the main game,
   its inspection or checkpoint sheet gets a gold *release slip* along the
   bottom. The slip shows the new look in miniature, its name and tier, and
   "wear it from the wardrobe". The look is saved the moment the slip shows.
   The mockup doesn't put it on for you ([open question](#open-questions)).
4. **The end.** The congratulations sheet says MAPWOMAN JOINS THE WARDROBE.

**Words and languages.** About 40 new strings: 22 names, 6 tiers, the sheet,
the slip and the screen-reader names. Each needs 14 translations, so about 560
in all, and the layout check has to pass for the new sheet and slips in all 15
languages. Keep names to 14 Latin characters, plain, with no puns.

## How to build it

### Outfits are drawn in code, in `Player._draw()`

MapMan has no sprite: `player.gd` draws a bell body, a round head, two stick
legs and two eyes. Outfits belong in the same `_draw()`:

- every dial the game turns (walk, look, lean, squash, hop, spin, mirror,
  cobweb, death) moves them for free, because they are drawn in the same
  transform from the same anchors;
- they stay sharp at every size (1.2× on the menus, about 3.8× on the
  phone), with no import pipeline;
- MapWoman's bow is already exactly this, the first outfit part.

Sprites or child nodes on the player would each need their own copy of the
lean, squash, flip and death maths, their own z-order and visibility, and
tweens to kill on reset. Each of those is a bug waiting to happen.

### Layers

Back to front: **back** (cape, map roll, wings), **legs**, **body**, **neck**,
**head**, **eyes**, **face**, **hat**, **front** (sparkles), then the cobweb
as now.

- **Seen from behind** (`look.y <= -0.6`, the rule the eyes already follow),
  back parts draw over the body (the cape covers his back) and front-only
  details are left out.
- **Dying**, the body and neck draw over the head, eyes and face (he is
  swallowed whole, as now) and the hat flies off: up, backwards, spinning and
  fading. Both are worked out from `dead`, so there is no new state and
  nothing new to reset. With reduce motion, `dead` jumps to 1 and the hat is
  simply gone.

**Classic doesn't change.** The prototype's layered `_draw()` with no outfit
draws Classic pixel for pixel: 0 of 486,200 pixels differ across all 11 poses.
So the first step can be a pure refactor, proven by the existing screenshot
baselines not changing.

### Files

| File | Change |
| --- | --- |
| `scripts/player.gd` | `var outfit := ""` beside `art`. `_draw()` split into the layers. The anchor helpers and the three rules live here, in one place each. |
| `scripts/outfits/*.gd` (new) | The parts, as static functions that draw on the player, split by kind (hats, faces, bodies, backs). The prototype's one file is 1,600 lines, over gdlint's 1,300. |
| `scripts/wardrobe.gd` (new, `class_name Wardrobe`) | The catalogue as data (id, name msgid, release level, tier, palette, parts) and pure functions: what progress has earned, which look a level releases, whether a worn id is valid. Needs no scene, so it is easy to test. Use id `drawing` for the Blueprint look, not `blueprint`, which reads like the style class. |
| `scripts/save.gd` | A `[wardrobe]` section (below). |
| `scripts/menus.gd` | `show_wardrobe()` (sheet 001-D); the WARDROBE row on 001; the release slips; `_figure()`, `_hero_on()` and `_pair_on()` wearing the worn look; TEXT entries for the new strings. |
| `scripts/main.gd` | The release in `advance_level()`; the ending's partner from the worn look; `wardrobe` and `wear <id>` in `_on_menu_action()`; Android back from the wardrobe to the main menu in `go_back()`. |
| `scripts/dev_panel.gd` | Dev-only cheats: release everything, empty the wardrobe. |
| `i18n/catalog.json`, `i18n/*.json` | The new strings, with width budgets. |

### Save

```ini
[wardrobe]
worn="cowboy"
released=["party_hat", "signal_red", "bobble_hat"]
seen=["party_hat", "signal_red"]
```

The change is additive (old saves load as they are), so it ships as `feat:`,
not `feat!:`. On load, sync: add every look the progress has earned (a level's
look once `furthest_level` is past it; MapWoman once `has_completed`). That
gives existing players theirs. A worn id that is unknown or not released falls
back to Classic. Store the released ids rather than deriving them each time:
the slip saves its look the moment it shows, even if the player quits on that
sheet, and feats will need storage anyway.

### The release moment

In `main.gd` `advance_level()`, after `Save.record_best()`, for the main game
only: practice and the tutorial never release anything, and practice only
opens levels you have reached anyway. If `Wardrobe` has a look for the level
and it isn't released yet, `Save` releases it and `show_end_level()` draws the
slip. Playing again from the start or from a checkpoint releases nothing new.
The dev skip goes round `advance_level()`; its looks arrive with the sync on
load, which is fine in a dev build.

### MapWoman as a look

`main.gd` makes `_woman` with `art = "woman"` for the ending. Make it a
partner instead: wearing MapWoman, the partner is Classic MapMan; otherwise it
is MapWoman. The same applies to `menus._pair_on()`.
`tests/unit/test_ending.gd` gets a case for the swap.

## Rules for future sessions

These keep extra parts on the character from turning into bugs. Rules 7–9
came from the first pose check, which found 9 bugs in the first draft
([sheet 05](sheets/05_caught_by_the_pose_check.png)). None of them shows on a
still of him standing.

![Caught by the pose check](sheets/05_caught_by_the_pose_check.png)

1. **Keep the figure.** The bell body, round head, two stick legs and eyes are
   MapMan in every look. Looks add to him or recolour him. Only an Epic look
   may change a shape (Robot's head), and then rule 9 applies.
2. **One look, one string.** `Player.outfit` holds one id, so a cowboy hat and
   a doctor's coat cannot combine, by construction.
3. **Everything in `_draw()`, nothing new to remember.** No child nodes,
   sprites or tweens for parts. A part's state comes from dials Player already
   has (`walking`, `_phase`, `look`, `squash`, `spin`, `web`, `dead`, `happy`,
   `_idle_clock`). Then `reset_pose()` resets the parts as well, and
   screenshots stay deterministic: no `randf()` and no clock reads in a part.
4. **Anchor to the pose, never to the screen.** Body parts use rest
   coordinates mapped by one helper (bob, squash, the drop when dying). Head
   parts follow the head as it sinks and shrinks. Hats ride the head and fly
   off it. Face parts use the eye positions. Leg parts use the hip and foot
   points.
5. **Four views.** Front. Side, which is the figure mirrored with the face
   shifted by `look.x` (front details shift with it). From behind: no face,
   no front-only details, back parts over the body. Dying. Mirroring flips
   everything, so an eye patch changes eye with the facing, which is fine
   for drawn parts but not for writing (rule 6).
6. **No writing or logos on him.** Mirroring would reverse it, translators
   can't reach it, and logos invite trouble. The same goes for the red cross
   emblem, which is protected by the Geneva Conventions (the doctor has a head
   mirror and a stethoscope instead), real uniforms, and national or
   religious dress.
7. **Seen from behind, front details hide like the eyes do, and a cape covers
   his back.**
8. **The death rules.** Hats fly off. Anything that sticks out of the head
   (a beard, a stem, antennae, MapWoman's bow) fades in the first half of the
   death. Neck pieces fade as the body takes the head. Nothing may poke out of
   the dead body. MapWoman's bow breaks this today, unseen because she never
   dies; the same rule fixes it.
9. **A changed shape must still fit.** A head that isn't a circle (Robot) must
   shrink inside the dead body. Check the DEAD column.
10. **Eyes carry the expression.** Looks that replace the eyes (pumpkin,
    skull, robot) must still blink, look about and widen when he is happy.
    Shades are the one look that hides them, on purpose.
11. **Size budget.** Up to 110 units above the tile centre and 42 to either
    side. Classic reaches 83 up and 26 to a side, so this is about one tile row
    higher and one column wider. Measured in the prototype across five poses:

    | Tallest | Units up | Widest | Units to a side |
    | --- | --- | --- | --- |
    | Party hat | 109 | Cowboy (brim) | 41 |
    | Wizard | 105 | Viking (horns) | 40 |
    | Top hat | 104 | Pirate | 37 |
    | Chef | 103 | Ninja (ribbon) | 36 |
    | Viking | 102 | Explorer, Graduate | 35 |
    | *Classic* | *83* | *Classic* | *26* |

12. **Readable on blue paper and on white tiles.** Classic gets this from a
    dark body (2.05:1 on the paper, 14.7:1 on a tile) and a light head. A look
    needs its body at 1.8:1 or more against the paper and its legs at 2.5:1 or
    more against a tile; an outline can carry either. The first wizard robe was
    1.16:1, nearly invisible on the paper, and the first superhero red 1.65:1;
    they and the King now use lighter colours. Paper `#16407a`; a tile is white at 80% over it,
    `#d0d9e4`.

    | Look | Body on paper | Legs on a tile | Outline |
    | --- | --- | --- | --- |
    | Classic | 2.05 | 14.73 | |
    | Signal red | 2.48 | 2.90 | |
    | Racing green | 1.93 | 3.72 | |
    | Blueprint | 1.00 | 7.19 | white, 10.25 on paper |
    | Hard hat | 3.93 | 10.62 | |
    | Neon | 1.85 | 13.28 | cyan, 5.33 on paper |
    | Doctor | 9.37 | 2.79 | 7.70 on a tile |
    | Explorer | 2.25 | 4.89 | |
    | Astronaut | 9.12 | 1.27 | 6.51 on a tile (legs too) |
    | Robot | 2.33 | 6.71 | |
    | Superhero | 2.05 | 3.51 | |
    | Wizard (first draft) | **1.16** | 8.32 | |
    | Wizard | 2.23 | 3.22 | |
    | Solid gold | 4.57 | 1.57 | 3.73 on a tile (legs too) |

13. **Decorative motion respects reduce motion.** Cape flutter, sparkles,
    the propeller, wing flaps and twinkles go through `Blueprint.motion()`.
    Walking and dying don't, because they are the game.
14. **Cheap to draw.** Plain polygons and lines; no shaders or textures. If a
    look gets busy, measure it on the phone with the dev build.
15. **Change looks only on sheet 001-D**, never during a level.
16. **Look at the pose check before calling a look done.** The bugs above
    don't show on a still of him standing.

## Testing

- **Step 1 is proven by what doesn't change.** The layered `_draw()` must
  leave every existing screenshot baseline as it is.
- **New unit tests (GUT).** `_draw()` runs in headless runs (checked), so
  these need no screen:
  - the catalogue: unique ids; one look per 5th level from 5 to 100; tiers in
    level order; every name in `i18n/catalog.json`;
  - releases: the main game releases once; practice and the tutorial don't;
    playing again doesn't; an old save syncs; MapWoman comes on completion; a
    bad worn id falls back to Classic;
  - every look in every pose draws without a script error;
  - the size budget, using a measure mode: parts draw through a handful of
    helpers, and in measure mode the helpers grow a box instead of drawing;
  - the contrast rule, for every palette;
  - `test_ending.gd`: wearing MapWoman, MapMan waits;
  - `test_menus.gd`: the wardrobe's buttons report `wear <id>`, and locked
    cells are disabled;
  - `test_i18n.gd`: sheet 001-D and the slips lay out in every language.
- **Screenshot baselines to add:** the wardrobe sheet, a level clear with a
  slip, and a level played in a look.
- **Visual review:** the pose-check sheets and the parade video, from a tool
  made from this prototype (say `tools/wardrobe_sheets.sh`, like
  `i18n_shots.sh`), reviewed with the `playtester` agent.
- **On the phone:** readability while moving, the release moment, and the
  tilt-look on sheet 001-D.

## Roadmap

One PR each, titled as the release notes should read:

1. `refactor: draw mapman in layers`: `player.gd` only, with zero pixel
   change. Labels: area: art.
2. `feat: a wardrobe of looks to collect`: `Wardrobe`, the save, sheet 001-D,
   the way in from 001, the release slips, and the first batch (Classic and
   the five Commons). Labels: area: ui, area: art, needs phone test. This is a
   minor release.
3. `feat: more looks for the wardrobe`: the Uncommon and Rare looks, about
   five per PR, each batch pose-checked.
4. `feat: play as mapwoman`: the ending's swap, plus the Epic, Legendary and
   Special looks.
5. Later, if wanted: feats and the bench, the shuffle, seasonal looks.

## Open questions

1. A fixed schedule, or shuffled within each tier?
2. When a look is released, put it on him straight away, or leave that to the
   wardrobe? The mockups leave it.
3. The way in: a WARDROBE row under MapMan (the mockup), a sixth row in the
   parts list, or tapping MapMan?
4. The list itself: anything to swap with the bench? Are the names right?
5. MapWoman as a look: exactly the ending's MapWoman, or something extra for
   her?
6. Should practice clears count? Proposed: no.

## The prototype

[`prototype/`](prototype/) is a design prototype, **not game code**. It lives
outside `godot/`, so the game never loads it and lint doesn't check it. Its
parts' geometry is meant to be lifted into `scripts/outfits/` when building.

| File | What it does |
| --- | --- |
| `outfit_figure.gd` | `Player` with the layered `_draw()`, the three rules, and all 30 looks (21, Classic and the bench) |
| `catalogue.gd` | the proposed list (ids, names, levels, tiers) and the 11 poses |
| `sheets.gd` | the identity check, then sheets 01–05 |
| `ui.gd`, `menus_sheet.gd` | the menu mockups on the game's own sheets, and sheet 06 |
| `parade.gd` | the animated contact sheet, through Player's own API (`face_*`, `land`, `cheer`, `spin_around`, `set_stuck`, `face_death`, `reset_pose`) |
| `extents.gd` | measures how far each look reaches |
| `render.sh` | runs them all; `--video` adds the parade |

```sh
godot --headless --path godot --import    # once: the class names must be known
docs/wardrobe/prototype/render.sh          # sheets into docs/wardrobe/sheets
docs/wardrobe/prototype/render.sh --video  # and parade.mp4
```

What it established:

- the layered `_draw()` draws Classic exactly as today (0 of 486,200 pixels
  differ);
- `_draw()` runs in headless test runs, so every look and pose can be tested
  without a screen;
- the size table and the contrast table above;
- the 9 bugs on sheet 05, all fixed by rules 7 and 8.
