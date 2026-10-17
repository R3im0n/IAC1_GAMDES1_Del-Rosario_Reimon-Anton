extends Area2D

@onready var collected_sound: AudioStreamPlayer2D = $collectedSound

var collected := false

func _on_body_entered(body: Node2D) -> void:
	if collected: 
		return
	if body.is_in_group("player"):
		collected = true
		collected_sound.play()
		print("Item collected!")
		queue_free()
	
