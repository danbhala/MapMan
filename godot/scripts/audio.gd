extends Node
## Sound effects and music. Mirrors fx.py and music.py from the original.

const SFX := {
	"step": "res://assets/sfx/step.wav",
	"reverse": "res://assets/sfx/reverse.wav",
	"vanish": "res://assets/sfx/vanish.wav",
	"hide": "res://assets/sfx/vanish.wav",
	"points": "res://assets/sfx/points.wav",
	"life": "res://assets/sfx/life.wav",
	"sticky": "res://assets/sfx/sticky.wav",
	"crumble": "res://assets/sfx/crumble.wav",
	"slide": "res://assets/sfx/slide.wav",
	"spikes": "res://assets/sfx/spikes.wav",
	"end_level": "res://assets/sfx/end_level.wav",
	"star": "res://assets/sfx/star.wav",
	"lose_life": "res://assets/sfx/pop.ogg",
	"checkpoint": "res://assets/sfx/checkpoint.ogg",
	"love": "res://assets/sfx/love.ogg",
	"stamp": "res://assets/sfx/pop.ogg",
}

const GAME_TRACKS := [
	"res://assets/music/game_1.ogg",
	"res://assets/music/game_2.ogg",
	"res://assets/music/game_3.ogg",
	"res://assets/music/game_4.ogg",
	"res://assets/music/game_5.ogg",
]
const MENU_TRACK := "res://assets/music/menu.ogg"
const GAME_OVER_TRACK := "res://assets/music/game_over.ogg"
const COMPLETION_TRACK := "res://assets/music/completion.ogg"

var _streams := {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx := 0
var _clock: AudioStreamPlayer
var _music: AudioStreamPlayer
var _music_kind := ""
var _music_path := ""
var _step_alt := false
var _pause_timer: SceneTreeTimer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	_clock = AudioStreamPlayer.new()
	var clock_stream: AudioStream = load("res://assets/sfx/clock.ogg")
	if clock_stream is AudioStreamOggVorbis:
		clock_stream.loop = true
	_clock.stream = clock_stream
	add_child(_clock)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -4.0
	_music.finished.connect(_on_music_finished)
	add_child(_music)


func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path)
	return _streams[path]


# --- effects -------------------------------------------------------------


func play(name: String, volume := 1.0, pitch := 1.0) -> void:
	# Every effect has a matching buzz, even with sound effects turned off.
	Haptics.feel(name)
	if not Save.fx_on or not SFX.has(name):
		return
	var p := _sfx_players[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx_players.size()
	p.stream = _stream(SFX[name])
	p.volume_db = linear_to_db(volume)
	p.pitch_scale = pitch
	p.play()


func play_step() -> void:
	_step_alt = not _step_alt
	play("step", 0.4, 1.5 if _step_alt else 1.0)


func play_clock() -> void:
	if Save.fx_on and not _clock.playing:
		_clock.play()


func stop_clock() -> void:
	if _clock.playing:
		_clock.stop()


# --- music ---------------------------------------------------------------


func play_menu() -> void:
	if _music_kind == "menu" and _music.playing:
		return
	_play_music("menu", MENU_TRACK)


func play_game() -> void:
	_play_music("game", GAME_TRACKS.pick_random())


func play_game_over() -> void:
	_play_music("game_over", GAME_OVER_TRACK)


func play_completion() -> void:
	_play_music("completion", COMPLETION_TRACK)


func _play_music(kind: String, path: String) -> void:
	_music_kind = kind
	_music_path = path
	_pause_timer = null
	_music.stream_paused = false
	if not Save.music_on:
		_music.stop()
		return
	_music.stream = _stream(path)
	_music.play()


func _on_music_finished() -> void:
	# Loop the current kind of music; game music picks a new random track.
	if _music_kind == "game":
		play_game()
	elif _music_kind != "":
		_play_music(_music_kind, _music_path)


## Silence the music for a few seconds (checkpoint jingle), then resume.
func pause_music(seconds: float) -> void:
	if not _music.playing:
		return
	_music.stream_paused = true
	var timer := get_tree().create_timer(seconds, true)
	_pause_timer = timer
	await timer.timeout
	if _pause_timer == timer:
		_music.stream_paused = false


func set_music_enabled(on: bool) -> void:
	Save.music_on = on
	Save.save_all()
	if on:
		if _music_path != "":
			_play_music(_music_kind, _music_path)
	else:
		_music.stop()


func set_fx_enabled(on: bool) -> void:
	Save.fx_on = on
	Save.save_all()
	if not on:
		stop_clock()
