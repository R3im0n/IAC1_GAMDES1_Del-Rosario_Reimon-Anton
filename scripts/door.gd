extends StaticBody2D
## A door that stays shut until the player touches it while holding the matching key.
## Opening it: the screen fades to black, the door disappears, the screen fades back in.

const ScreenFade = preload("res://scripts/screen_fade.gd")

## Must match the key_id of the key that opens this door
@export var key_id : String = "red"
## Turn off to let the player open it without a key (handy for testing the transition)
@export var require_key : bool = true
@export var fade_time : float = 0.4      # seconds to fade out, and to fade back in
@export var black_time : float = 0.2     # seconds the screen stays black

@onready var open_zone : Area2D = $OpenZone
@onready var collision_shape : CollisionShape2D = $CollisionShape2D

var opening := false


func _ready() -> void:
	# opened earlier? then it stays open
	if Main.is_removed(self):
		queue_free()


func _physics_process(_delta: float) -> void:
	if opening:
		return
	for body in open_zone.get_overlapping_bodies():
		if body.is_in_group("player") and can_open():
			open()
			return


func can_open() -> bool:
	return not require_key or Main.has_key(key_id)


func open() -> void:
	opening = true
	if require_key:
		Main.use_key(key_id)
	Main.mark_removed(self)

	get_tree().paused = true                      # freeze the game during the transition
	var fade = ScreenFade.new()
	get_tree().current_scene.add_child(fade)

	await fade.fade_out(fade_time)

	# the screen is black: the door disappears now
	hide()
	collision_shape.set_deferred("disabled", true)
	await get_tree().create_timer(black_time).timeout

	await fade.fade_in(fade_time)
	fade.queue_free()
	get_tree().paused = false
	queue_free()


func _exit_tree() -> void:
	# safety: never leave the game paused if the level changes mid-transition
	if opening and is_inside_tree():
		get_tree().paused = false
