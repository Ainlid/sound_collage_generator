extends Node2D

var tempo = 120.0
var interval = 1.0
onready var timer_beat = $timer_beat

var samples = []
var offset_amount = 8
var pitch_amount = 4
var size_amount = 4
var volume_amount = 4
onready var file_dialog = $interface/load_menu/file_dialog
onready var file_list = $interface/load_menu/file_scroll/file_list

onready var play_button = $interface/play_button
onready var samples_error = $interface/samples_error
var playing = false

var rng
var rng_seed

var grain = preload("res://grain/grain.tscn")
var volume = 0.0
var size_min = 1
var size_max = 4
var pitch = 0
var size = 0

var use_rounding = false
var rounding = 16.0

var tempo_random = 0.0
var volume_random = 0.0
var pitch_random = 0.0
var size_random = 0.0

onready var tempo_label = $interface/settings/tempo_label
onready var tempo_slider = $interface/settings/tempo_slider

onready var volume_label = $interface/settings/volume_label
onready var volume_slider = $interface/settings/volume_slider

onready var pitch_label = $interface/settings/pitch_label
onready var pitch_slider = $interface/settings/pitch_slider

onready var size_label = $interface/settings/size_label
onready var size_slider = $interface/settings/size_slider

onready var rounding_label = $interface/settings/rounding_label
onready var rounding_slider = $interface/settings/rounding_slider

onready var tempo_random_label = $interface/settings/tempo_random_label
onready var tempo_random_slider = $interface/settings/tempo_random_slider

onready var volume_random_label = $interface/settings/volume_random_label
onready var volume_random_slider = $interface/settings/volume_random_slider

onready var pitch_random_label = $interface/settings/pitch_random_label
onready var pitch_random_slider = $interface/settings/pitch_random_slider

onready var size_random_label = $interface/settings/size_random_label
onready var size_random_slider = $interface/settings/size_random_slider

onready var seed_box = $interface/settings/seed_box

onready var audio_record = $audio_record
onready var record_button = $interface/record_button
onready var save_path_label = $interface/save_path_label

var effect
var recording

onready var master_volume_label = $interface/master_volume_label
onready var master_volume_slider = $interface/master_volume_slider

func _ready():
	randomize()
	rng = RandomNumberGenerator.new()

	_set_tempo(120.0)
	_set_volume(0.0)
	_set_pitch(0)
	_set_size(1)

	_set_tempo_random(0.0)
	_set_volume_random(0.0)
	_set_pitch_random(0.0)

	_set_master_volume(0.0)

	_randomize_seed()

	_clear_samples()

	effect = AudioServer.get_bus_effect(0, 0)
	save_path_label.text = OS.get_executable_path().get_base_dir() + "/recording.wav"

func _set_seed(value):
	rng_seed = value
	rng.seed = value

func _randomize_seed():
	var new_seed = randi()
	rng.seed = new_seed
	seed_box.value = new_seed

func _set_tempo(value):
	tempo = value
	interval = 60.0 / tempo
	timer_beat.wait_time = interval
	tempo_slider.value = value
	tempo_label.text = "Tempo: " + str(round(value)) + " BPM"

func _set_volume(value):
	volume = value
	volume_slider.value = value
	volume_label.text = "Volume: " + str(round(value)) + " dB"

func _set_pitch(value):
	pitch = value
	pitch_slider.value = value
	pitch_label.text = "Pitch: " + str(round(value)) + " st"

func _set_size(value):
	size = value
	size_slider.value = value
	size_label.text = "Size: " + str(round(value)) + "/4"

func _set_tempo_random(value):
	tempo_random = value
	tempo_random_label.text = "Randomization: " + str(value) + "%"

func _set_volume_random(value):
	volume_random = value
	volume_random_label.text = "Randomization: " + str(value) + "%"

func _set_pitch_random(value):
	pitch_random = value
	pitch_random_label.text = "Randomization: " + str(value) + "%"

func _set_size_random(value):
	size_random = value
	size_random_label.text = "Randomization: " + str(value) + "%"

func _toggle_rounding(toggled):
	if toggled:
		use_rounding = true
		rounding_slider.editable = true
	else:
		use_rounding = false
		rounding_slider.editable = false

func _set_rounding(value):
	rounding = value
	rounding_label.text = "Rounding factor: " + str(value)

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
			var offsets = []
			for n_offset in offset_amount:
				offsets.append(_pick_offset(new_stream))
			var pitches = []
			for n_pitch in pitch_amount:
				pitches.append(_pick_pitch())
			var sizes = []
			for n_size in size_amount:
				sizes.append(_pick_size())
			var volumes = []
			for n_volume in volume_amount:
				volumes.append(_pick_volume())
			var new_sample = {
				"stream" : new_stream,
				"offsets" : offsets,
				"pitches" : pitches,
				"sizes" : sizes,
				"volumes" : volumes,
			}
			samples.append(new_sample)
			file_list.text += str(paths[n].get_file()) + "\n"
			file.close()
	play_button.disabled = false

func _pick_offset(stream):
	var new_offset = rng.randf_range(0.0, stream.get_length())
	return new_offset

func _pick_pitch():
	var new_pitch = pow(2.0, rng.randi_range(-6, 6) / 12.0)
	return new_pitch

func _pick_size():
	var new_size = rng.randi_range(1, 4)
	return new_size

func _pick_volume():
	var new_volume = rng.randf_range(-6.0, 0.0)
	return new_volume

func _clear_samples():
	samples = []
	file_list.text = "No samples selected"

func _play_pressed():
	if !playing:
		if !samples.empty():
			_play_start()
		else:
			samples_error.popup_centered()
	else:
		_play_stop()

func _play_start():
	_set_seed(rng_seed)
	timer_beat.start()
	playing = true
	play_button.text = "Stop"

func _play_stop():
	timer_beat.stop()
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
	_randomize_params()
	_spawn_grain()

func _randomize_params():
	var tempo_rand_chance = rng.randf() * 100.0
	if tempo_rand_chance < tempo_random:
		var new_tempo = rng.randi_range(50, 200)
		_set_tempo(new_tempo)

	var volume_rand_chance = rng.randf() * 100.0
	if volume_rand_chance < volume_random:
		var new_volume = rng.randf_range(-6.0, 0.0)
		_set_volume(new_volume)

	var pitch_rand_chance = rng.randf() * 100.0
	if pitch_rand_chance < pitch_random:
		var new_pitch = rng.randi_range(-6, 6)
		_set_pitch(new_pitch)

	var size_rand_chance = rng.randf() * 100.0
	if size_rand_chance < size_random:
		var new_size = rng.randi_range(1, 4)
		_set_size(new_size)

func _spawn_grain():
	var new_grain = grain.instance()
	add_child(new_grain)
	var sample_id = rng.randi()%samples.size()
	var current_sample = samples[sample_id]
	var offset_array = current_sample["offsets"]
	var random_offset = offset_array[rng.randi()%offset_array.size()]
	var pitch_array = current_sample["pitches"]
	var random_pitch = pitch_array[rng.randi()%pitch_array.size()]
	var size_array = current_sample["sizes"]
	var random_size = size_array[rng.randi()%size_array.size()] * interval
	var volume_array = current_sample["volumes"]
	var random_volume = volume_array[rng.randi()%volume_array.size()]
	new_grain._grain_play(current_sample["stream"], random_offset, random_pitch, random_size, random_volume)

func _quit_pressed():
	get_tree().quit()
