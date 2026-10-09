@tool
class_name PieceMarker
extends RefCounted
## Draws a level piece in the Godot editor so designers can see and pick it:
## a see-through coloured box the size of its zone, a label, and (optionally)
## an arrow for the direction traffic drives through it.
##
## Editor only. Nothing is drawn in the game, and nothing is saved into the
## scene (the nodes are internal and have no owner).
##
## ART PLACEHOLDER (editor only): plain boxes, arrows and text made in code.
## Fine for an editor gizmo; replace only if artists want nicer editor icons.
## See docs/ART_PLACEHOLDERS.md.

const NODE_NAME := "_EditorMarker"


## Draws (or redraws) the marker on `piece`. The box matches the piece's first
## CollisionShape3D with a BoxShape3D, or `fallback_size` if it has none.
static func draw(piece: Node3D, color: Color, text: String, arrow := false, fallback_size := Vector3(2, 2, 2)) -> void:
	if not Engine.is_editor_hint() or not piece.is_inside_tree():
		return
	var old := piece.get_node_or_null(NODE_NAME)
	if old != null:
		old.free()

	var size := fallback_size
	var center := Vector3(0, fallback_size.y / 2.0, 0)
	for child in piece.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			size = child.shape.size
			center = child.position
			break

	var root := Node3D.new()
	root.name = NODE_NAME
	piece.add_child(root, false, Node.INTERNAL_MODE_BACK)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color, 0.25)
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	box.mesh.size = size
	box.material_override = material
	box.position = center
	root.add_child(box)

	if arrow:
		# A flat triangle on top of the box, pointing along -Z (the way traffic drives).
		var head := MeshInstance3D.new()
		head.mesh = PrismMesh.new()
		head.mesh.size = Vector3(minf(size.x, 4.0), minf(size.z, 4.0), 0.2)
		var solid := material.duplicate() as StandardMaterial3D
		solid.albedo_color = Color(color, 0.8)
		head.material_override = solid
		head.rotation = Vector3(-PI / 2.0, 0, 0)
		head.position = center + Vector3(0, size.y / 2.0 + 0.2, 0)
		root.add_child(head)

	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 96
	label.pixel_size = 0.02
	label.outline_size = 24
	label.modulate = color.lightened(0.4)
	label.position = center + Vector3(0, size.y / 2.0 + 1.5, 0)
	root.add_child(label)
