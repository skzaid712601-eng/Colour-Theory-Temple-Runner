
extends Node3D

# ==========================================
# TEMPLE RUNNER - COLOUR THEORY EDITION
# Godot 4.x
#
# Controls:
# A / Left Arrow  = Move left
# D / Right Arrow = Move right
# Space           = Jump
# R               = Restart
#
# Colour Theory:
# Obstacles use different colours simultaneously.
# Each obstacle keeps its assigned colour.
# ==========================================

var player: CharacterBody3D
var camera: Camera3D
var score_label: Label
var message_label: Label
var theory_label: Label

var obstacles: Array[Node3D] = []
var orbs: Array[Node3D] = []
var pillars: Array[Node3D] = []
var trees: Array[Node3D] = []
var gates: Array[Node3D] = []

# Blender models copied to res://assets/
const TREE_SCENE: PackedScene = preload("res://assets/JungleTree.glb")
const GATE_SCENE: PackedScene = preload("res://assets/ColourGate.glb")

var lane: int = 1
var lanes: Array[float] = [-2.0, 0.0, 2.0]

var speed: float = 12.0
var gravity: float = 24.0
var jump_power: float = 9.0

var score: int = 0
var distance: float = 0.0
var spawn_timer: float = 0.0
var game_over: bool = false

# Fixed player, orb and temple colours.
var player_color := Color("#168BFF")
var orb_color := Color("#00F5D4")
var temple_color := Color("#75634D")
var gold_color := Color("#FFC857")

# Colour theory palette for obstacles.
var obstacle_colors: Array[Color] = [
	Color("#FF4545"), # Red
	Color("#FF8C42"), # Orange
	Color("#FFD93D"), # Yellow
	Color("#8B5CF6"), # Purple
	Color("#32CD72"), # Green
	Color("#FF5DA2"), # Pink
	Color("#00B8D9"), # Cyan-blue
	Color("#E85D04")  # Deep orange
]


func _ready() -> void:
	randomize()
	make_world()
	make_trees()
	make_gates()
	make_player()
	make_camera()
	make_ui()
	spawn_timer = 1.0


# ==========================================
# MATERIALS
# ==========================================

func make_material(
	color: Color,
	glow: bool = false
) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7

	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.5

	return mat


func make_box(
	parent: Node3D,
	size: Vector3,
	pos: Vector3,
	color: Color
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size

	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = make_material(color)

	parent.add_child(mesh_instance)
	return mesh_instance


# ==========================================
# WORLD
# ==========================================

func make_world() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()

	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#9CC7C2")
	environment.ambient_light_energy = 0.8

	environment_node.environment = environment
	add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -25, 0)
	sun.light_energy = 1.3
	add_child(sun)

	# Main pathway.
	var floor_body := StaticBody3D.new()
	floor_body.name = "TemplePath"
	add_child(floor_body)

	make_box(
		floor_body,
		Vector3(7, 0.5, 120),
		Vector3(0, -0.25, -25),
		temple_color
	)

	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(7, 0.5, 120)

	floor_collision.shape = floor_shape
	floor_collision.position = Vector3(0, -0.25, -25)
	floor_body.add_child(floor_collision)

	# Golden path markings.
	for z in range(-80, 20, 5):
		make_box(
			self,
			Vector3(0.06, 0.02, 2),
			Vector3(0, 0.015, float(z)),
			Color("#D9B56D")
		)

	# Temple pillars.
	for z in range(-55, 5, 8):
		make_pillar(-4.3, float(z))
		make_pillar(4.3, float(z))


func make_pillar(x: float, z: float) -> void:
	var pillar := Node3D.new()
	pillar.position = Vector3(x, 0, z)
	add_child(pillar)

	make_box(
		pillar,
		Vector3(0.8, 4, 0.8),
		Vector3(0, 2, 0),
		temple_color
	)

	make_box(
		pillar,
		Vector3(1.2, 0.35, 1.2),
		Vector3(0, 4, 0),
		gold_color
	)

	pillars.append(pillar)


# ==========================================
# BLENDER JUNGLE TREES
# ==========================================

func make_trees() -> void:
	# Place rows of trees outside both sides of the path.
	for i in range(12):
		for side in [-1.0, 1.0]:
			var tree := TREE_SCENE.instantiate() as Node3D
			if tree == null:
				continue

			add_child(tree)
			tree.position = Vector3(
				side * randf_range(6.0, 8.0),
				0.0,
				-10.0 - float(i) * 10.0
			)
			tree.scale = Vector3.ONE * randf_range(0.8, 1.2)
			trees.append(tree)


# ==========================================
# BLENDER COLOURFUL GATES
# ==========================================

func make_gates() -> void:
	# Place colourful gates down the centre of the temple path.
	for i in range(3):
		var gate := GATE_SCENE.instantiate() as Node3D
		if gate == null:
			continue

		add_child(gate)
		gate.position = Vector3(0.0, 0.0, -35.0 - float(i) * 45.0)
		gate.scale = Vector3.ONE
		gates.append(gate)


# ==========================================
# PLAYER
# ==========================================

func make_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 0, 0)
	add_child(player)

	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.8

	var body_mesh := MeshInstance3D.new()
	body_mesh.mesh = capsule
	body_mesh.position.y = 0.9
	body_mesh.material_override = make_material(player_color)
	player.add_child(body_mesh)

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8

	collision.shape = shape
	collision.position.y = 0.9
	player.add_child(collision)


# ==========================================
# CAMERA
# ==========================================

func make_camera() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(0, 5, 8)
	add_child(camera)

	camera.current = true
	camera.fov = 75
	camera.look_at(Vector3(0, 1, -8), Vector3.UP)


# ==========================================
# USER INTERFACE
# ==========================================

func make_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	score_label = Label.new()
	score_label.position = Vector2(20, 20)
	score_label.add_theme_font_size_override("font_size", 25)
	score_label.add_theme_color_override("font_color", gold_color)
	canvas.add_child(score_label)

	theory_label = Label.new()
	theory_label.position = Vector2(20, 58)
	theory_label.add_theme_font_size_override("font_size", 17)
	theory_label.add_theme_color_override("font_color", orb_color)
	canvas.add_child(theory_label)

	message_label = Label.new()
	message_label.anchor_left = 0.10
	message_label.anchor_top = 0.25
	message_label.anchor_right = 0.90
	message_label.anchor_bottom = 0.75

	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 27)
	message_label.add_theme_color_override("font_color", Color.WHITE)

	canvas.add_child(message_label)

	message_label.text = (
        "TEMPLE RUNNER\n"
		+ "COLOUR THEORY EDITION\n\n"
		+ "A / D or Arrow Keys: Move\n"
		+ "SPACE: Jump\n\n"
		+ "Avoid the colourful obstacles!\n"
		+ "Collect glowing cyan orbs!"
	)


# ==========================================
# COLOURFUL OBSTACLES
# ==========================================

func spawn_obstacle() -> void:
	var obstacle := Area3D.new()
	obstacle.name = "ColourfulObstacle"

	# Select a random colour for THIS obstacle.
	# Each obstacle receives its own material.
	var chosen_color: Color = obstacle_colors[
		randi_range(0, obstacle_colors.size() - 1)
	]

	var obstacle_mesh := BoxMesh.new()
	obstacle_mesh.size = Vector3(1.2, 1.2, 1.2)

	var visual := MeshInstance3D.new()
	visual.mesh = obstacle_mesh
	visual.position.y = 0.6
	visual.material_override = make_material(chosen_color)

	obstacle.add_child(visual)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.2, 1.2, 1.2)

	collision.shape = shape
	collision.position.y = 0.6
	obstacle.add_child(collision)

	# Assign a random lane.
	var chosen_lane: int = randi_range(0, 2)
	obstacle.position = Vector3(
		lanes[chosen_lane], 0, -40
	)

	add_child(obstacle)
	obstacles.append(obstacle)


# ==========================================
# COLLECTIBLE ORBS
# ==========================================

func spawn_orb() -> void:
	var orb := Area3D.new()
	orb.name = "CyanCollectible"

	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.38
	orb_mesh.height = 0.76

	var visual := MeshInstance3D.new()
	visual.mesh = orb_mesh
	visual.material_override = make_material(orb_color, true)

	orb.add_child(visual)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.65

	collision.shape = shape
	orb.add_child(collision)

	var chosen_lane: int = randi_range(0, 2)
	orb.position = Vector3(
		lanes[chosen_lane], 1.1, -40
	)

	add_child(orb)
	orbs.append(orb)


# ==========================================
# INPUT
# ==========================================

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.echo:
			return

		if game_over:
			if event.keycode == KEY_R:
				get_tree().reload_current_scene()
			return

		if event.keycode == KEY_A or event.keycode == KEY_LEFT:
			lane = maxi(0, lane - 1)

		elif event.keycode == KEY_D or event.keycode == KEY_RIGHT:
			lane = mini(2, lane + 1)

		elif event.keycode == KEY_SPACE:
			if player.is_on_floor():
				player.velocity.y = jump_power

	if game_over and event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()

	if game_over and event.is_action_pressed("ui_cancel"):
		get_tree().reload_current_scene()


# ==========================================
# GAME LOOP
# ==========================================

func _physics_process(delta: float) -> void:
	if game_over:
		return

	# Smooth lane movement.
	player.position.x = move_toward(
		player.position.x,
		lanes[lane],
		10.0 * delta
	)

	# Gravity and jumping.
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta
	elif player.velocity.y < 0:
		player.velocity.y = 0

	player.move_and_slide()

	# Speed and distance.
	speed = min(speed + 0.12 * delta, 24.0)
	distance += speed * delta
	spawn_timer -= delta

	# Spawn obstacles and orbs.
	if spawn_timer <= 0:
		spawn_obstacle()

		if randf() < 0.8:
			spawn_orb()

		spawn_timer = randf_range(1.0, 1.6)

	# Move obstacles without changing their colours.
	for obstacle in obstacles.duplicate():
		obstacle.position.z += speed * delta

		if obstacle.position.z > 3:
			obstacles.erase(obstacle)
			obstacle.queue_free()
			continue

		var close_x: bool = abs(
			obstacle.position.x - player.position.x
		) < 0.85

		var close_z: bool = abs(
			obstacle.position.z - player.position.z
		) < 0.8

		if close_x and close_z and player.position.y < 0.85:
			end_game()
			return

	# Move and collect orbs.
	for orb in orbs.duplicate():
		orb.position.z += speed * delta
		orb.rotate_y(3.0 * delta)

		if orb.position.z > 3:
			orbs.erase(orb)
			orb.queue_free()
			continue

		var player_target: Vector3 = (
			player.global_position + Vector3(0, 1, 0)
		)

		if orb.global_position.distance_to(player_target) < 1.0:
			score += 10
			orbs.erase(orb)
			orb.queue_free()

	# Recycle temple pillars.
	for pillar in pillars:
		pillar.position.z += speed * delta

		if pillar.position.z > 10:
			pillar.position.z -= 64

	# Move trees toward the player and recycle them.
	for tree in trees:
		tree.position.z += speed * delta
		if tree.position.z > 12.0:
			tree.position.z -= 120.0

	# Move colourful gates towards the player and recycle them.
	for gate in gates:
		gate.position.z += speed * delta
		if gate.position.z > 12.0:
			gate.position.z -= 135.0

	# Update HUD.
	score_label.text = (
		"ORBS: " + str(score)
		+ "     DISTANCE: " + str(int(distance))
	)

	theory_label.text = (
        "COLOUR THEORY: RED | ORANGE | YELLOW"
		+ " | PURPLE | GREEN | PINK"
	)


# ==========================================
# GAME OVER
# ==========================================

func end_game() -> void:
	game_over = true

	message_label.text = (
        "GAME OVER!\n"
		+ "Orbs: " + str(score)
		+ "\nDistance: " + str(int(distance))
		+ "\n\nCOLOUR THEORY"
		+ "\nWarm: Red, Orange, Yellow"
		+ "\nCool: Green, Cyan, Purple"
		+ "\n\nPress R to Restart"
	)

	message_label.add_theme_color_override(
		"font_color", Color("#FF4545")
	)
