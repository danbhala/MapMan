extends GutTest
## The QR reader reads the share sheet's QR codes back from pictures like a
## phone camera takes: small, turned, at an angle, in uneven light, with
## noise, and with damaged modules its error correction puts right.

const QrCode := preload("res://addons/kenyoni/qr_code/qr_code.gd")
const CODE := "MAPMAN 7K2D-W9QX-H4TB-0RCE-M5PZ-8YVA-3NFJ-6G1S"


## The share sheet's own QR of `text`, blue on white like the sheet.
func _qr(text: String) -> Image:
	var img := DraftingSheet.qr_image(text)
	img.convert(Image.FORMAT_RGB8)
	return img


## `src` seen through a camera: its corners land on `corners` (top left, top
## right, bottom right, bottom left) in a w × h picture with a dim, uneven
## background, light falling off to one side, and noise.
func _photo(src: Image, w: int, h: int, corners: Array, noise := 0.0) -> Image:
	var sw := float(src.get_width())
	var sh := float(src.get_height())
	var back := QrReader.homography(
		corners, [Vector2(0, 0), Vector2(sw, 0), Vector2(sw, sh), Vector2(0, sh)]
	)
	var out := Image.create(w, h, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in h:
		for x in w:
			var p := QrReader.project(back, Vector2(x + 0.5, y + 0.5))
			var c := Color(0.35, 0.3, 0.25)
			if p.x >= 0 and p.y >= 0 and p.x < sw and p.y < sh:
				c = src.get_pixel(int(p.x), int(p.y))
			var light := 0.55 + 0.45 * x / w
			var n := rng.randf_range(-noise, noise)
			out.set_pixel(x, y, Color(c.r * light + n, c.g * light + n, c.b * light + n))
	return out


func test_reads_a_code_straight_on() -> void:
	var src := _qr(CODE)
	var s := src.get_width() * 2
	src.resize(s, s, Image.INTERPOLATE_NEAREST)
	assert_eq(QrReader.read(src), CODE)


func test_reads_a_small_turned_code_at_an_angle() -> void:
	var corners := [Vector2(250, 70), Vector2(420, 120), Vector2(380, 300), Vector2(200, 250)]
	assert_eq(QrReader.read(_photo(_qr(CODE), 640, 360, corners, 0.08)), CODE)


func test_reads_a_code_upside_down_in_perspective() -> void:
	var corners := [Vector2(500, 330), Vector2(250, 300), Vector2(280, 60), Vector2(520, 30)]
	assert_eq(QrReader.read(_photo(_qr(CODE), 640, 360, corners, 0.05)), CODE)


func test_reads_a_shared_level_link() -> void:
	var link := LevelCode.link(CODE)
	assert_eq(QrReader.read(_qr(link)), link)


func test_reads_a_phone_cameras_brightness_plane() -> void:
	# Android hands the camera picture over as brightness alone, in red.
	var img := _qr(CODE)
	img.convert(Image.FORMAT_L8)
	var y := Image.create_from_data(
		img.get_width(), img.get_height(), false, Image.FORMAT_R8, img.get_data()
	)
	assert_eq(QrReader.read(y), CODE)


func test_reads_a_mirrored_code() -> void:
	var img := _qr(CODE)
	img.flip_y()
	assert_eq(QrReader.read(img), CODE)


func test_reads_a_short_code() -> void:
	var text := "MAPMAN BKKC-W000"
	var corners := [Vector2(60, 40), Vector2(260, 50), Vector2(250, 250), Vector2(50, 240)]
	assert_eq(QrReader.read(_photo(_qr(text), 320, 300, corners)), text)


func test_a_picture_without_a_code_reads_nothing() -> void:
	var img := Image.create(320, 240, false, Image.FORMAT_RGB8)
	img.fill(Color(0.5, 0.5, 0.5))
	img.fill_rect(Rect2i(40, 40, 60, 60), Color.BLACK)
	assert_eq(QrReader.read(img), "")
	assert_eq(QrReader.read(null), "")


func test_reads_numbers_and_bytes_too() -> void:
	var qr := QrCode.new(QrCode.ErrorCorrection.LOW)
	qr.put_byte("level é".to_utf8_buffer())
	var img := QrCode.generate_image(qr.encode(), 4)
	assert_eq(QrReader.read(img), "level é")
	qr = QrCode.new(QrCode.ErrorCorrection.HIGH)
	qr.put_numeric("0123456789")
	assert_eq(QrReader.read(QrCode.generate_image(qr.encode(), 4)), "0123456789")


func test_error_correction_repairs_damaged_modules() -> void:
	var qr := QrCode.new(QrCode.ErrorCorrection.MEDIUM)
	qr.put_alphanumeric(CODE)
	var modules := qr.encode()
	var dim := roundi(sqrt(modules.size()))
	# A smudge across a run of data modules near the bottom right.
	for y in range(dim - 4, dim - 1):
		for x in range(dim - 10, dim - 6):
			modules[x + y * dim] ^= 1
	assert_eq(QrReader.decode_modules(modules, dim), CODE)


func test_repair_fixes_up_to_half_the_check_words() -> void:
	var data := PackedByteArray([32, 91, 11, 120, 209, 114, 220, 77, 67, 64, 236, 17])
	var block := data.duplicate()
	block.append_array(QrCode.ReedSolomon.encode(data, 10))
	var hurt := block.duplicate()
	for i in [0, 3, 7, 12, 20]:
		hurt[i] ^= 0x5A + i
	assert_eq(QrReader.repair(hurt, 10), block)
	hurt[15] ^= 1
	assert_eq(QrReader.repair(hurt, 10), PackedByteArray(), "six is too many")
