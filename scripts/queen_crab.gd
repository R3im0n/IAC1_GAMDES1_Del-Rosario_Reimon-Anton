extends CharacterBody2D
## Queen Crab boss.
##
## Loop:  IDLE (waiting for the player) -> CHASE -> ATTACK -> CHASE -> ...
## One ATTACK = wind-up (the *_raise animation, the telegraph) -> smash -> RECOVERY.
## The recovery is the opening: the boss stands still and the player can punish it.

signal health_changed(current: int, maximum: int)
signal defeated

enum State { IDLE, CHASE, ATTACK, DEAD }

# The frame of the *_smash animations where the claw hits the ground
const IMPACT_FRAME := 4

@export_group("Stats")
@export var max_health : int = 30
@export_range(0.0, 1.0) var enrage_at : float = 0.5   # below this share of health the boss speeds up

@export_group("Fight start")
## If on, the boss stands still (and can't be hurt) until activate() is called,
## e.g. by the BossArena when the player walks into it.
@export var start_dormant : bool = true

@export_group("Chasing")
@export var GRAVITY : float = 1000.0
@export var chase_speed : float = 70.0        # slow on purpose, the player can always outrun it
@export var aggro_range : float = 1200.0      # starts chasing when the player is this close
@export var attack_range : float = 260.0      # only attacks when the player is this close (horizontally)
@export var stop_distance : float = 120.0     # stops walking this close, so it doesn't sit on top of the player
@export var chase_time_min : float = 2.0      # how long it keeps chasing before it is allowed to attack
@export var chase_time_max : float = 3.5

@export_group("Attacks")
@export var recover_time : float = 1.6        # THE OPENING: seconds standing still after every attack
@export_range(0.0, 1.0) var combo_chance : float = 0.25
@export var splash_scale : float = 1.5
@export var splash_scene : PackedScene = preload("res://scenes/crab_ground_smash.tscn")

@export_group("Death")
@export var coin_drops : int = 5

var enemy_death_effect = preload("res://scenes/enemy_death_effect.tscn")
const coin_pickup = preload("res://scenes/coin.tscn")

var state : State = State.IDLE
var health : int
var enraged := false
var rage_speed := 1.0         # 1.0 normally, higher once enraged (affects walking and animation speed)
var chase_timer := 0.0
var smash_side := 1           # +1 = the claw on the RIGHT side of the screen, -1 = the LEFT side
var player : Node2D
var active := false         # false = dormant, waiting for the fight to be triggered

@onready var sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox : Area2D = $Hitbox
@onready var smash_point_left : Marker2D = $SmashPointLeft
@onready var smash_point_right : Marker2D = $SmashPointRight


func _ready() -> void:
	health = max_health
	active = not start_dormant

	# animation_finished only fires for animations that do NOT loop
	for anim in ["left_raise", "left_smash", "right_raise", "right_smash"]:
		sprite.sprite_frames.set_animation_loop(anim, false)

	sprite.frame_changed.connect(_on_sprite_frame_changed)
	hitbox.area_entered.connect(_on_hitbox_area_entered)

	sprite.play("idle")
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if state != State.DEAD and not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	match state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			play_idle()
			if active and player_is_targetable() and distance_to_player() <= aggro_range:
				start_chase()
		State.CHASE:
			chase(delta)
		State.ATTACK, State.DEAD:
			# attacking: planted on the ground, can't move
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)

	move_and_slide()


# ---------- chasing ----------

# Starts the fight. Called by the BossArena (or anything else you like).
func activate() -> void:
	if active:
		return
	active = true
	if state == State.IDLE:
		start_chase()


func start_chase() -> void:
	state = State.CHASE
	chase_timer = randf_range(chase_time_min, chase_time_max)


func chase(delta: float) -> void:
	if not player_is_targetable() or distance_to_player() > aggro_range * 1.5:
		state = State.IDLE
		return

	play_idle()
	var dist := distance_to_player()

	if dist > stop_distance:
		velocity.x = side_toward_player() * chase_speed * rage_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)

	# Only attacks after chasing for a while AND when the player is close enough.
	# If the player stays far away the boss just keeps walking towards them.
	chase_timer -= delta
	if chase_timer <= 0.0 and dist <= attack_range:
		start_attack()


# ---------- attack patterns ----------

# Picks a pattern, plays it, then stands still for recover_time (the opening).
# To add a new pattern: write an `attack_xxx()` function below and add it to the pick here.
func start_attack() -> void:
	state = State.ATTACK

	var combo := combo_chance + (0.25 if enraged else 0.0)
	if randf() < combo:
		await attack_combo()
	else:
		await attack_single()

	if state == State.DEAD:
		return

	# --- recovery: the player's window to shoot the boss ---
	sprite.speed_scale = 1.0
	sprite.play("idle")
	await get_tree().create_timer(recover_time / rage_speed).timeout

	if state == State.DEAD:
		return
	start_chase()


# One smash with the claw on the side the player is standing on
func attack_single() -> void:
	await smash(side_toward_player())


# Two smashes: first towards the player, then the other claw (quicker wind-up, still telegraphed)
func attack_combo() -> void:
	var first := side_toward_player()
	await smash(first)
	if state == State.DEAD:
		return
	await smash(-first, 1.7)


# wind-up (telegraph) -> smash. The splash itself is spawned on IMPACT_FRAME.
func smash(side: int, windup_speed: float = 1.0) -> void:
	# The animation names use the crab's OWN left and right, so the crab's "left"
	# claw is the one on the right side of the screen.
	var prefix := "left" if side > 0 else "right"
	smash_side = side

	sprite.speed_scale = windup_speed * rage_speed
	await play_and_wait(prefix + "_raise")
	if state == State.DEAD:
		return

	sprite.speed_scale = rage_speed
	await play_and_wait(prefix + "_smash")


func _on_sprite_frame_changed() -> void:
	if state == State.DEAD or sprite.frame != IMPACT_FRAME:
		return
	if sprite.animation == &"left_smash" or sprite.animation == &"right_smash":
		spawn_splashes(smash_side)


# One splash travelling to each side of the point where the claw hit the ground
func spawn_splashes(side: int) -> void:
	var point : Marker2D = smash_point_right if side > 0 else smash_point_left
	for dir in [-1, 1]:
		var fx = splash_scene.instantiate()
		fx.direction = dir                       # set before add_child: the splash reads it in _ready()
		fx.scale = Vector2.ONE * splash_scale
		get_parent().add_child(fx)
		fx.global_position = point.global_position


# ---------- helpers ----------

func play_idle() -> void:
	if sprite.animation != &"idle":
		sprite.speed_scale = 1.0
		sprite.play("idle")


func play_and_wait(anim: StringName) -> void:
	sprite.play(anim)
	await sprite.animation_finished


func player_is_targetable() -> bool:
	return is_instance_valid(player) and player.get("alive") != false


func distance_to_player() -> float:
	return absf(player.global_position.x - global_position.x)


func side_toward_player() -> int:
	return 1 if player.global_position.x >= global_position.x else -1


# ---------- taking damage / dying ----------

func _on_hitbox_area_entered(area: Area2D) -> void:
	var bullet = area.get_parent()
	if bullet.has_method("get_damage"):
		take_damage(bullet.get_damage())


func take_damage(amount: int) -> void:
	if state == State.DEAD or not active:
		return

	health -= amount
	health_changed.emit(health, max_health)

	# hit flash
	sprite.modulate = Color(1.0, 0.45, 0.45)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)

	if not enraged and health <= max_health * enrage_at:
		enrage()

	if state == State.IDLE:      # shot from outside its aggro range: wake up
		start_chase()

	if health <= 0:
		state = State.DEAD       # set now so nothing else happens before die() runs
		die.call_deferred()


func enrage() -> void:
	enraged = true
	rage_speed = 1.3


func die() -> void:
	state = State.DEAD
	hitbox.monitoring = false
	sprite.stop()
	sprite.modulate = Color.WHITE

	for i in 6:
		var fx = enemy_death_effect.instantiate() as Node2D
		get_parent().add_child(fx)
		fx.global_position = global_position + Vector2(randf_range(-170, 170), randf_range(-150, 40))
		await get_tree().create_timer(0.2).timeout

	for i in coin_drops:
		var pickup = coin_pickup.instantiate()
		get_parent().add_child(pickup)
		pickup.global_position = global_position + Vector2(randf_range(-100, 100), -40)

	defeated.emit()
	queue_free()
