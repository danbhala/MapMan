# QR Code (vendored)

The QR Code generator from Kenyoni's Godot addons, version 2.0.0
(https://github.com/kenyoni-software/godot-addons, MIT, see LICENSE.md):
`qr_code.gd`, `bit_stream.gd` and `reed_solomon.gd` only.

Changed for MapMan: the Shift JIS tables (`shift_jis.gd`, 800 KB) are left
out, so Kanji mode is unavailable. The game only makes alphanumeric codes
(scripts/drafting_sheet.gd).

Vendored from commit 3d92d1bab93c0a8cb58951c039ddb17acd70a449.
