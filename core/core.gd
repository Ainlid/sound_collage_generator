extends Node2D

var tempo = 120.0
var interval = 1.0
var tick_index = 0
var bar_size = 8
var duration = 120.0
onready var timer_tick = $timer_tick
onready var timer_end = $timer_end

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

func _randomize_seed():
	var new_seed = randi()
	rng.seed = new_seed
	seed_box.value = new_seed

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
	for n_sample in samples:
		var offset_id = rng.randi()%n_sample["offsets"].size()
		n_sample["offsets"][offset_id] = _pick_offset(n_sample["stream"])
		var pitch_id = rng.randi()%n_sample["pitches"].size()
		n_sample["pitches"][pitch_id] = _pick_pitch()
		var size_id = rng.randi()%n_sample["sizes"].size()
		n_sample["sizes"][size_id] = _pick_size()
		var volume_id = rng.randi()%n_sample["volumes"].size()
		n_sample["volumes"][volume_id] = _pick_volume()

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

func _mutate_toggled(button_pressed):
	mutation_enabled = button_pressed

func _endless_toggled(button_pressed):
	endless_enabled = button_pressed
