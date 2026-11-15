# The web version

MapMan also plays in a browser, on a computer (arrow keys or WASD, Space
shakes, Esc or P pauses) or on a phone held sideways (tilt, or drag with
Options > CONTROLS). Same game, same save format; the save lives in the
browser.

## How it is built and hosted

- `godot/export_presets.cfg` has a **Web** preset: single-threaded, so it
  needs no special headers and runs in iPhone Safari. Its `html/head_include`
  loads `motion.js` and adds a "turn your phone sideways" cover for phones in
  portrait.
- `web/motion.js` reads the phone's tilt from the browser (Godot reads no
  sensors on the web) into `window.mapmanMotion`; `godot/scripts/motion.gd`
  reads it, and `Input` everywhere else. iPhones ask permission on the first
  tap. If tilt feels inverted on one kind of phone, the sign flip is in
  `motion.js`.
- The **Web build** workflow (`.github/workflows/web.yml`) exports the game on
  every push to master and every PR, and force-pushes the files (plus
  `web/vercel.json`) as a single commit to `web-master` or `web-pr-N`.
- Vercel project `mapman` (Dan's Vercel) is linked to this repo with
  **production branch `web-master`**. `vercel.json` at the repo root and in
  `web/` tells Vercel to skip every branch that doesn't start with `web-`, so
  master, PR and APK branches never deploy. Each `web-pr-N` gets a preview at
  `https://mapman-git-web-pr-N-dan-stuarts-projects-b8791952.vercel.app`
  (Vercel asks you to sign in to see previews; the live site is public).
- Level links work on the web too: `https://<site>/<code>` plays that level.

## Left out on the web

The camera QR scanner (no SCAN button; codes are typed or pasted), and, when
they land, ads, Play billing and the Android-only extras. Check
`OS.has_feature("web")` before adding anything that needs the phone's app.
