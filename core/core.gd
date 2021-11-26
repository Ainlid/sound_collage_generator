extends Node2D

var tempo = 120.0
var interval = 1.0
var tick_index = 0
var bar_size = 8
var duration = 120.0
onready var timer_tick = $timer_tick
onready var timer_end = $timer_end

var streams = []
var samples_amount = 16
var samples = []

onready var file_dialog = $interface/load_menu/file_dialog
onready var file_list = $interface/load_menu/file_scroll/file_list

onready var play_button = $interface/play_button
onready var samples_error = $interface/samples_error
var playing = false

var mutation_enabled = true
var endless_enabled = false

var rng
var rng_seed

var grain = preload("res://grain/grain.tscn")

onready var tempo_label = $interface/settings/tempo_label
onready var tempo_slider = $interface/settings/tempo_slider

onready var duration_label = $interface/settings/duration_label
onready var duration_spinbox = $interface/settings/duration_spinbox

onready var seed_box = $interface/settings/seed_box

onready var audio_record = $audio_record
onready var record_button = $interface/record_button
onready var save_path_label = $interface/save_path_label

var effect
var recording

onready var master_volume_label = $interface/settings/master_volume_label
onready var master_volume_slider = $interface/settings/master_volume_slider

func _ready():
	randomize()
	rng = RandomNumberGenerator.new()

	_set_tempo(120.0)
	_set_duration(120.0)
	_set_master_volume(0.0)
	_randomize_seed()
	_clear_samples()

	effect = AudioServer.get_bus_effect(0, 0)
	save_path_label.text = OS.get_executable_path().get_base_dir() + "/recording.wav"

func _set_seed(value):
	rng_seed = value
	rng.seed = value
	seed_box.value = value

func _randomize_seed():
	var new_seed = randi()
	_set_seed(new_seed)

func _set_tempo(value):
	tempo = value
	interval = 60.0 / tempo
	timer_tick.wait_time = interval
	tempo_slider.value = value
	tempo_label.text = "Tempo: " + str(round(value)) + " BPM"

func _set_duration(value):
	duration = value
	duration_spinbox.value = value

func _set_master_volume(value):
	AudioServer.set_bus_volume_db(0, value)
	master_volume_label.text = "Master volume: " + str(value) + " dB"

func _load_pressed():
	_play_stop()
	file_dialog.popup_centered()

func _files_selected(paths):
	_clear_samples()
	file_list.text = "Loaded: \n"
	var file = File.new()
	for n in paths.size():
		if file.file_exists(paths[n]):
			file.open(paths[n], file.READ)
			var buffer = file.get_buffer(file.get_len())
			var new_stream = AudioStreamSample.new()
			new_stream.format = AudioStreamSample.FORMAT_16_BITS      
			new_stream.data = buffer
			new_stream.stereo = true
			new_stream.mix_rate = 44100
			streams.append(new_stream)
			file_list.text += str(paths[n].get_file()) + "\n"
			file.close()
	play_button.disabled = false

func _pick_stream():
	var id = rng.randi()%streams.size()
	return streams[id]

func _pick_offset(stream):
	var new_offset = rng.randf_range(0.0, stream.get_length())
	return new_offset

func _pick_pitch():
	var new_pitch = pow(2.0, rng.randi_range(-6, 6) / 12.0)
	return new_pitch

func _pick_size():
	var new_size = rng.randi_range(1, 4) * interval
	return new_size

func _pick_volume():
	var new_volume = rng.randf_range(-6.0, 0.0)
	return new_volume

func _clear_samples():
	streams = []
	samples = []
	file_list.text = "No samples selected"

func _generate_samples():
	for n in samples_amount:
		var stream = _pick_stream()
		var new_sample = {
			"stream" : stream,
			"offset" : _pick_offset(stream),
			"pitch" : _pick_pitch(),
			"size" : _pick_size(),
			"volume" : _pick_volume(),
		}
		samples.append(new_sample)

func _play_pressed():
	if !playing:
		if !streams.empty():
			_play_start()
		else:
			samples_error.popup_centered()
	else:
		_play_stop()

func _play_start():
	_set_seed(rng_seed)
	_generate_samples()
	timer_tick.start()
	if !endless_enabled:
		timer_end.wait_time = duration
		timer_end.start()
	playing = true
	play_button.text = "Stop"

func _play_stop():
	timer_tick.stop()
	playing = false
	play_button.text = "Play"

func _record_pressed():
	if effect.is_recording_active():
		recording = effect.get_recording()
		effect.set_recording_active(false)
		record_button.text = "Record"
	else:
		effect.set_recording_active(true)
		record_button.text = "Stop recording"

func _save_pressed():
	var save_path = save_path_label.text
	recording.save_to_wav(save_path)

func _tick():
	_spawn_grain()
	tick_index += 1
	if tick_index > bar_size - 1:
		if mutation_enabled:
			_mutate()
		tick_index = 0

func _mutate():
	var amount = rng.randi()%samples.size()
	for n in amount:
		var sample_id = rng.randi()%samples.size()
		var sample = samples[sample_id]
		var stream = _pick_stream()
		sample["stream"] = stream
		sample["offset"] = _pick_offset(stream)
		sample["pitch"] = _pick_pitch()
		sample["size"] = _pick_size()
		sample["volume"] = _pick_volume()

func _spawn_grain():
	var new_grain = grain.instance()
	add_child(new_grain)
	var sample_id = rng.randi()%samples.size()
	var sample = samples[sample_id]
	new_grain._grain_play(sample)

func _quit_pressed():
	get_tree().quit()

func _mutate_toggled(button_pressed):
	mutation_enabled = button_pressed

func _endless_toggled(button_pressed):
	endless_enabled = button_pressed
