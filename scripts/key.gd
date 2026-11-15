extends Area2D
## A key. Touch it to pick it up; it opens any door with the same key_id.

@export var key_id : String = "red"

@onready var sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var collected_sound : AudioStreamPlayer2D = $collectedSound

var collected := false


func _ready() -> void:
	# picked up earlier? then it stays gone
	if Main.is_removed(self):
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if collected or not body.is_in_group("player"):
		return
	collected = true
	Main.add_key(key_id)        # the key is kept in Main, so it works in any level
	Main.mark_removed(self)

	# hide it now, but stay alive until the pickup sound has finished playing
	sprite.hide()
	set_deferred("monitoring", false)
	collected_sound.play()
	await collected_sound.finished
	queue_free()
