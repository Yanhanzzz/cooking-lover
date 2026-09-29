extends Node2D

## Underworld：里世界场景骨架（P3）。
## 性质完全不同的场景单独成场景，美术/规则后续整体替换。
## 这里只放一个“返回饭店”的门，证明场景切换是双向的（进得去也回得来）。

func _ready() -> void:
	# 里世界背景：暗紫调，和表线区分开（之后换成你的扭曲美术）
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.0, 0.1)
	bg.size = get_viewport_rect().size
	bg.z_index = -1
	add_child(bg)

	# 返回饭店的门
	var door := Area2D.new()
	door.name = "Door_ToWorld"
	door.add_to_group("door")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(96, 96)
	var col := CollisionShape2D.new()
	col.shape = shape
	door.add_child(col)
	door.position = get_viewport_rect().size * 0.5
	door.set_meta("target", "res://scenes/world.tscn")
	add_child(door)

	print("身处里世界。走到中央按 X 返回饭店。")
