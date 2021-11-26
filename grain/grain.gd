extends Node

onready var audio = $audio
onready var timer_delete = $timer_delete

func _grain_play(sample):
	audio.stream = sample["stream"]
	audio.pitch_scale = sample["pitch"]
	audio.volume_db = sample["volume"]
	audio.play(sample["offset"])
	timer_delete.wait_time = sample["size"]
	timer_delete.start()

func _delete():
	audio.stop()
	queue_free()
