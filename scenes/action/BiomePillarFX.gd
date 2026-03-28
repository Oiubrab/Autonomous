extends Node3D

## Applies the animated bio-mechanical shader to all mesh surfaces in a pillar GLB instance.
## Detects organic/bioluminescent pixels by colour and shifts their hue over time.
## Dark mechanical surfaces are left static.

const _SHADER = preload("res://assets/environment/biome_pillar.gdshader")

## UV tiling to match the surface's texture repeat. Leave at (1,1) for GLB assets;
## set to match uv1_scale for tiled flat surfaces (walls, floor).
@export var uv_scale: Vector2 = Vector2(1.0, 1.0)

func _ready() -> void:
	# Unique phase and speed per instance so surfaces shift independently.
	var phase := randf() * TAU
	# Mean 0.8, ±0.3 variance — keeps everything visibly active but not uniform.
	var speed := clampf(randf_range(0.5, 1.1), 0.1, 2.0)
	_apply_to_node(self, phase, speed)

func _apply_to_node(node: Node, phase: float, speed: float) -> void:
	if node is MeshInstance3D:
		_swap_materials(node, phase, speed)
	for child in node.get_children():
		_apply_to_node(child, phase, speed)

func _swap_materials(mesh_instance: MeshInstance3D, phase: float, speed: float) -> void:
	var mesh := mesh_instance.mesh
	if not mesh:
		return
	for i in mesh.get_surface_count():
		var original := mesh_instance.get_active_material(i)
		if not original:
			continue
		var shader_mat := ShaderMaterial.new()
		shader_mat.shader = _SHADER
		# Carry over the albedo texture from the imported material if present.
		if original is BaseMaterial3D:
			var tex: Texture2D = original.albedo_texture
			if tex:
				shader_mat.set_shader_parameter("albedo_texture", tex)
		shader_mat.set_shader_parameter("phase_offset", phase)
		shader_mat.set_shader_parameter("shift_speed", speed)
		shader_mat.set_shader_parameter("uv_scale", uv_scale)
		mesh_instance.set_surface_override_material(i, shader_mat)
