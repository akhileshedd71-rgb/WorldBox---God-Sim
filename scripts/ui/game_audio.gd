class_name GameAudio
extends Node
## Original local assets; audio never consumes simulation RNG or changes rules.
var ambience: AudioStreamPlayer
var cue: AudioStreamPlayer
var values: Dictionary = PlayerSettings.DEFAULTS.duplicate()
var suspended := false
var next_cue := 0
var played := 0
func _ready() -> void:
	ambience = AudioStreamPlayer.new(); add_child(ambience)
	# Explicit streaming lets the audio server release looped WAV playback at shutdown.
	ambience.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	var loop: AudioStreamWAV = preload("res://assets/audio/meadow.wav").duplicate()
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0; loop.loop_end = int(loop.get_length() * loop.mix_rate)
	ambience.stream = loop
	cue = AudioStreamPlayer.new(); add_child(cue)
	cue.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	ambience.play(); apply(values)
func apply(settings: Dictionary) -> void:
	values = settings.duplicate()
	if ambience == null: return
	ambience.volume_db = linear_to_db(maxf(0.0001, values.master * values.ambience))
	cue.volume_db = linear_to_db(maxf(0.0001, values.master * values.effects))
	ambience.stream_paused = suspended or values.master == 0 or values.ambience == 0
	if suspended or values.master == 0 or values.effects == 0: cue.stop()
func set_suspended(value: bool) -> void:
	suspended = value; apply(values)
func play_cue(kind: String = "touch") -> void:
	if suspended or values.master == 0 or values.effects == 0 or Time.get_ticks_msec() < next_cue: return
	next_cue = Time.get_ticks_msec() + 90
	cue.stream = load("res://assets/audio/%s.wav" % (kind if kind in ["touch", "paint", "save"] else "touch"))
	cue.play(); played += 1

func shutdown() -> void:
	suspended = true
	if ambience != null:
		ambience.stream_paused = true
		ambience.stop(); ambience.stream = null
	if cue != null:
		cue.stream_paused = true
		cue.stop(); cue.stream = null

func _exit_tree() -> void:
	shutdown()
