extends Area2D

@onready var collected_sound: AudioStreamPlayer2D = $collectedSound
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var collected := false

func _ready() -> void:
	# collected earlier? then it stays gone (coins dropped by enemies aren't placed in a level, so they're ignored)
	if Main.is_removed(self):
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if collected:
		return
	if body.is_in_group("player"):
		collected = true
		Main.mark_removed(self)
		print("Item collected!")

		# The sound player is a child of the coin, so the coin must stay alive until the
		# sound has finished. Hide it and stop it being touched again in the meantime.
		sprite.hide()
		set_deferred("monitoring", false)

		collected_sound.play()
		await collected_sound.finished
		queue_free()
