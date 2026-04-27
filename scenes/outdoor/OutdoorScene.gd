extends Node3D

## Exterior swamp world.
## Builds real terrain geometry at startup using FBM noise — actual vertices,
## actual collision (HeightMapShape3D). No flat plane.

const WATER_SHADER_PATH  := "res://shaders/swamp_water.gdshader"
const GROUND_SHADER_PATH := "res://shaders/swamp_ground.gdshader"

const TERRAIN_SIZE   := 400.0   # world units — large open swamp
const TERRAIN_RES    := 120     # quads per side
const TERRAIN_HEIGHT := 10.0     # max height variation in metres
const TERRAIN_UV_TILE := 14.0   # texture tile count

@onready var ground_mesh : MeshInstance3D   = $Ground/GroundMesh
@onready var ground_col  : CollisionShape3D = $Ground/GroundCollision

# ── noise ─────────────────────────────────────────────────────────────────────
func _hash(p: Vector2) -> float:
	var n: float = sin(p.x * 127.1 + p.y * 311.7) * 43758.5453
	return n - floor(n)

func _vnoise(p: Vector2) -> float:
	var i := Vector2(floor(p.x), floor(p.y))
	var f := Vector2(p.x - floor(p.x), p.y - floor(p.y))
	f = Vector2(f.x * f.x * (3.0 - 2.0 * f.x), f.y * f.y * (3.0 - 2.0 * f.y))
	return lerp(
		lerp(_hash(i), _hash(i + Vector2(1.0, 0.0)), f.x),
		lerp(_hash(i + Vector2(0.0, 1.0)), _hash(i + Vector2(1.0, 1.0)), f.x),
		f.y)

func _fbm(p: Vector2) -> float:
	var v := 0.0
	var amp := 0.5
	var freq := 1.0
	for _i in range(7):
		v    += amp * _vnoise(p * freq)
		freq *= 2.1
		amp  *= 0.48
	return v

func _height_at(x: float, z: float) -> float:
	# Flatten near the building entrance so Litta doesn't sink into a hole
	var dist: float = sqrt(x * x + z * z)
	var flat: float = clamp((dist - 8.0) / 20.0, 0.0, 1.0)
	flat = flat * flat * (3.0 - 2.0 * flat)  # smoothstep

	# Large rolling hills (~55m per feature)
	var hills := _fbm(Vector2(x, z) * 0.018)
	# Sharper medium bumps and embankments (~25m per feature)
	var bumps := _fbm(Vector2(x + 73.0, z + 31.0) * 0.04) * 0.45

	return (hills + bumps - 0.58) * TERRAIN_HEIGHT * flat

# ── terrain build ─────────────────────────────────────────────────────────────
func _build_terrain() -> void:
	var n := TERRAIN_RES
	var total := (n + 1) * (n + 1)
	var verts   := PackedVector3Array()
	var norms   := PackedVector3Array()
	var uvs     := PackedVector2Array()
	var indices := PackedInt32Array()
	var hmap    := PackedFloat32Array()

	verts.resize(total)
	norms.resize(total)
	uvs.resize(total)
	hmap.resize(total)

	var step := TERRAIN_SIZE / n

	for zi in range(n + 1):
		for xi in range(n + 1):
			var fx := float(xi) / n
			var fz := float(zi) / n
			var wx := (fx - 0.5) * TERRAIN_SIZE
			var wz := (fz - 0.5) * TERRAIN_SIZE
			var h  := _height_at(wx, wz)
			var idx := zi * (n + 1) + xi
			verts[idx] = Vector3(wx, h, wz)
			uvs[idx]   = Vector2(fx * TERRAIN_UV_TILE, fz * TERRAIN_UV_TILE)
			hmap[idx]  = h

	for zi in range(n + 1):
		for xi in range(n + 1):
			var wx := (float(xi) / n - 0.5) * TERRAIN_SIZE
			var wz := (float(zi) / n - 0.5) * TERRAIN_SIZE
			var hl := _height_at(wx - step, wz)
			var hr := _height_at(wx + step, wz)
			var hd := _height_at(wx, wz - step)
			var hu := _height_at(wx, wz + step)
			norms[zi * (n + 1) + xi] = Vector3(hl - hr, 2.0 * step, hd - hu).normalized()

	indices.resize(n * n * 6)
	var ii := 0
	for zi in range(n):
		for xi in range(n):
			var tl := zi * (n + 1) + xi
			var tr := tl + 1
			var bl := tl + (n + 1)
			var br := bl + 1
			indices[ii]     = tl;  indices[ii+1] = bl;  indices[ii+2] = tr
			indices[ii+3]   = tr;  indices[ii+4] = bl;  indices[ii+5] = br
			ii += 6

	var arr := Array()
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX]  = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

	var shader := load(GROUND_SHADER_PATH) as Shader
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("tex_mud",  load("res://assets/environment/outdoor/ground_mud.png"))
		mat.set_shader_parameter("tex_rock", load("res://assets/environment/outdoor/ground_rock.png"))
		mesh.surface_set_material(0, mat)

	ground_mesh.mesh = mesh

	var hshape := HeightMapShape3D.new()
	hshape.map_width = n + 1
	hshape.map_depth = n + 1
	hshape.map_data  = hmap
	ground_col.scale = Vector3(TERRAIN_SIZE / n, 1.0, TERRAIN_SIZE / n)
	ground_col.shape = hshape

# ── water ─────────────────────────────────────────────────────────────────────
func _apply_water_shader() -> void:
	var shader := load(WATER_SHADER_PATH) as Shader
	if not shader:
		return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	for pool_name in ["SwampPool", "SwampPool2", "SwampPool3"]:
		var pool := get_node_or_null(pool_name) as MeshInstance3D
		if pool:
			pool.set_surface_override_material(0, mat)

func _aabb_in_local(obj: Node3D) -> AABB:
	var combined := AABB()
	var first := true
	for mi in obj.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		if not mesh_inst or not mesh_inst.mesh:
			continue
		var local_aabb := mesh_inst.get_aabb()
		var rel: Transform3D = obj.global_transform.affine_inverse() * mesh_inst.global_transform
		for i in range(8):
			var corner := local_aabb.position + Vector3(
				local_aabb.size.x if (i & 1) else 0.0,
				local_aabb.size.y if (i & 2) else 0.0,
				local_aabb.size.z if (i & 4) else 0.0)
			var c := rel * corner
			if first:
				combined = AABB(c, Vector3.ZERO)
				first = false
			else:
				combined = combined.expand(c)
	return combined

func _spawn_foliage() -> void:
	var tree_scene  := load("res://assets/environment/outdoor/tree.glb")  as PackedScene
	var plant_scene := load("res://assets/environment/outdoor/plant.glb") as PackedScene
	var rock_scene  := load("res://assets/environment/outdoor/rock.glb")  as PackedScene
	var half := TERRAIN_SIZE * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 7391

	# Trees — one candidate per 22×22 cell, ~40 % placed
	var tree_step := 22
	var tree_count := int(TERRAIN_SIZE / tree_step)
	for xi in range(tree_count):
		for zi in range(tree_count):
			var wx := (xi + 0.5) * tree_step - half + rng.randf_range(-8.0, 8.0)
			var wz := (zi + 0.5) * tree_step - half + rng.randf_range(-8.0, 8.0)
			if wx * wx + wz * wz < 30.0 * 30.0:
				continue
			if rng.randf() > 0.4:
				continue
			var h := _height_at(wx, wz)
			if h < -1.5:
				continue
			var inst := tree_scene.instantiate() as Node3D
			var sc := rng.randf_range(5.0, 8.5)
			inst.transform = Transform3D(Basis().scaled(Vector3(sc, sc, sc)), Vector3(wx, h, wz))
			$Trees.add_child(inst)

	# Plants — denser grid, ~40 % placed
	var plant_step := 14
	var plant_count := int(TERRAIN_SIZE / plant_step)
	for xi in range(plant_count):
		for zi in range(plant_count):
			var wx := (xi + 0.5) * plant_step - half + rng.randf_range(-5.0, 5.0)
			var wz := (zi + 0.5) * plant_step - half + rng.randf_range(-5.0, 5.0)
			if wx * wx + wz * wz < 15.0 * 15.0:
				continue
			if rng.randf() > 0.4:
				continue
			var h := _height_at(wx, wz)
			if h < -1.5:
				continue
			var inst := plant_scene.instantiate() as Node3D
			var sc := rng.randf_range(1.0, 2.0)
			inst.transform = Transform3D(Basis().scaled(Vector3(sc, sc, sc)), Vector3(wx, h, wz))
			$Plants.add_child(inst)

	# Rocks — sparse, ~35 % placed
	var rock_step := 28
	var rock_count := int(TERRAIN_SIZE / rock_step)
	for xi in range(rock_count):
		for zi in range(rock_count):
			var wx := (xi + 0.5) * rock_step - half + rng.randf_range(-10.0, 10.0)
			var wz := (zi + 0.5) * rock_step - half + rng.randf_range(-10.0, 10.0)
			if wx * wx + wz * wz < 20.0 * 20.0:
				continue
			if rng.randf() > 0.35:
				continue
			var h := _height_at(wx, wz)
			var inst := rock_scene.instantiate() as Node3D
			var sc := rng.randf_range(1.4, 2.5)
			inst.transform = Transform3D(Basis().scaled(Vector3(sc, sc, sc)), Vector3(wx, h, wz))
			$Rocks.add_child(inst)

func _add_tree_colliders() -> void:
	for tree in $Trees.get_children():
		var aabb := _aabb_in_local(tree as Node3D)
		if aabb.size == Vector3.ZERO:
			continue
		var body := StaticBody3D.new()
		var col  := CollisionShape3D.new()
		var box  := BoxShape3D.new()
		box.size     = aabb.size
		col.shape    = box
		col.position = aabb.get_center()
		body.add_child(col)
		tree.add_child(body)

# ── weather ───────────────────────────────────────────────────────────────────
func _setup_weather() -> void:
	_spawn_rain()
	_spawn_lightning()

func _spawn_rain() -> void:
	var rain := GPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 1200
	rain.lifetime = 2.2
	rain.local_coords = false
	rain.position = Vector3(0, 45, 0)
	rain.visibility_aabb = AABB(Vector3(-120, -50, -120), Vector3(240, 55, 240))

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(100, 1, 100)
	pmat.direction = Vector3(-0.08, -1.0, 0.0)
	pmat.spread = 1.5
	pmat.gravity = Vector3(0, -22.0, 0)
	pmat.initial_velocity_min = 20.0
	pmat.initial_velocity_max = 26.0
	pmat.scale_min = 1.0
	pmat.scale_max = 1.0
	rain.process_material = pmat

	var quad := QuadMesh.new()
	quad.size = Vector2(0.016, 0.28)
	var rmat := StandardMaterial3D.new()
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color = Color(0.75, 0.85, 1.0, 0.22)
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	rmat.no_depth_test = false
	quad.surface_set_material(0, rmat)
	rain.draw_pass_1 = quad
	add_child(rain)

	# Mist handled by FogVolume nodes in the scene tree (requires Forward+ renderer)

func _spawn_lightning() -> void:
	var ctrl := Node.new()
	ctrl.name = "LightningController"
	var light := OmniLight3D.new()
	light.name = "LightningFlash"
	light.light_color = Color(0.85, 0.88, 1.0)
	light.light_energy = 0.0
	light.omni_range = 400.0
	light.position = Vector3(0, 60, -50)
	ctrl.add_child(light)
	add_child(ctrl)

	# Timer drives the flash sequence
	var timer := Timer.new()
	timer.wait_time = randf_range(4.0, 12.0)
	timer.one_shot = false
	ctrl.add_child(timer)
	timer.timeout.connect(_do_lightning.bind(light, timer))
	timer.start()

func _do_lightning(light: OmniLight3D, timer: Timer) -> void:
	# Double flash then fade
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 18.0, 0.04)
	tween.tween_property(light, "light_energy", 0.0,  0.06)
	tween.tween_property(light, "light_energy", 12.0, 0.03)
	tween.tween_property(light, "light_energy", 0.0,  0.35)
	timer.wait_time = randf_range(5.0, 18.0)

func _ready() -> void:
	_build_terrain()
	_apply_water_shader()
	_spawn_foliage()
	_add_tree_colliders()
	_setup_weather()
