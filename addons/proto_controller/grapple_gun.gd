extends Node3D

@export var camera: Camera3D
@export var player: CharacterBody3D
@export var muzzle: Node3D
@export var max_distance: float = 60.0
@export var pull_speed: float = 15.0
@export var rope_thickness: float = 0.03
@export var rope_material: Material

var is_grappling: bool = false
var grapple_point: Vector3
var rope: MeshInstance3D

func _ready():
	# Create rope mesh once
	rope = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = rope_thickness
	mesh.bottom_radius = rope_thickness
	mesh.height = 1.0
	rope.mesh = mesh
	if rope_material:
		rope.material_override = rope_material
	add_child(rope)
	rope.visible = false

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("grapple"):
		if is_grappling:
			release_grapple()
		else:
			fire_grapple()

	if is_grappling:
		update_rope_visual()
		pull_player_toward_point(delta)

func fire_grapple():
	if not camera or not player:
		push_error("Camera or Player reference missing.")
		return

	var from = camera.global_position
	var to = from + -camera.global_transform.basis.z * max_distance

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result = space_state.intersect_ray(query)

	if result:
		grapple_point = result.position
		is_grappling = true
		rope.visible = true
		update_rope_visual()
	else:
		print("No valid grapple surface found.")

func pull_player_toward_point(delta: float) -> void:
	var direction = (grapple_point - player.global_position)
	var distance = direction.length()
	if distance < 2.0:
		release_grapple()
		return
	
	player.velocity = direction.normalized() * pull_speed
	player.move_and_slide()

func release_grapple():
	is_grappling = false
	rope.visible = false
	player.velocity = Vector3.ZERO

func update_rope_visual():
	var start_pos = muzzle.global_position
	var end_pos = grapple_point
	var direction = end_pos - start_pos
	var length = direction.length()
	var mid_point = start_pos + direction * 0.5

	if length <= 0.001:
		return

	# 1) Make the rope 'look at' the grapple point (Z axis will point toward it)
	# We create a temporary transform that looks from mid_point to end_pos.
	var look_transform := Transform3D()
	look_transform.origin = mid_point
	# Basis.looking_at expects a target direction from the origin, so pass (end_pos - mid_point)
	look_transform.basis = Basis().looking_at((end_pos - mid_point).normalized(), Vector3.UP)

	# 2) Rotate the basis 90 degrees around local X so cylinder's +Y aligns with the direction
	#    (Cylinder's length axis is +Y by default).
	var adjusted_basis := look_transform.basis.rotated(Vector3.RIGHT, deg_to_rad(90))

	# 3) Apply final transform with adjusted basis (no cumulative rotation)
	rope.global_transform = Transform3D(adjusted_basis, mid_point)

	# 4) Scale the cylinder's height. Default CylinderMesh height = 1.0 (we used height=1),
	#    so scale.y should be length * 0.5 (half-height scaling).
	rope.scale = Vector3(1.0, length * 0.5, 1.0)
