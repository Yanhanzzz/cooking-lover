extends CharacterBody2D

## Player：玩家角色（P3 占位版）。
## 机制教学点：
##   - CharacterBody2D：Godot 推荐的 2D 角色体，自带 move_and_slide() 物理移动
##   - Camera2D：挂为子节点即自动跟随玩家
##   - Input.get_vector：把四个方向键合成一个方向向量（斜向也能走）
##   - Input.is_action_just_pressed("调查")：按 X 的“那一帧”才触发一次（防长按连发）
##
## 占位用一张 48x48 绿块；等你的人物立绘到位，把 Sprite2D 的 texture 换掉即可，
## 后续要做四向行走动画时，把 Sprite2D 换成 AnimatedSprite2D。

@export var speed: float = 120.0

@onready var sprite: Sprite2D = $Sprite2D

func _physics_process(_delta: float) -> void:
	# 对话 / 存档菜单打开时，锁住玩家移动与交互（P4 新增）
	if DialogueManager.is_active or SaveMenu.is_open:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = dir * speed
	move_and_slide()

	# 按朝向翻转（占位图左右对称，先留接口；真立绘换上后这行就生效了）
	if dir.x != 0:
		sprite.flip_h = dir.x < 0

	# 调查 / 交互 / 进门：按 X 触发
	if Input.is_action_just_pressed("调查"):
		_try_interact()

## 找最近的可交互物或门。交互系统（P4）会在这里继续扩展。
func _try_interact() -> void:
	print("[调试] 按下了 X（调查）键")   # 验证 X 是否被识别；确认进门正常后可删掉此行

	# 1) 先找“可交互物件”（P4 背包/物件系统会往这个 group 里塞节点）
	for area in get_tree().get_nodes_in_group("interactable"):
		if area is Area2D and area.overlaps_body(self) and area.has_method("interact"):
			area.interact(self)
			return
	# 2) 再找“门”：走到门前按 X 切换场景。
	#    改用“玩家到门中心的距离”判定，比 overlaps_body 即时物理查询更稳（不依赖物理帧刷新）。
	for door in get_tree().get_nodes_in_group("door"):
		if not (door is Area2D):
			continue
		var center: Vector2 = door.global_position
		var half: Vector2 = door.get_meta("half_size", Vector2(48, 48))
		# 矩形判定：玩家是否落在门范围内（再放宽 8px，手感更宽容）
		if abs(global_position.x - center.x) <= half.x + 8 and abs(global_position.y - center.y) <= half.y + 8:
			var target: String = door.get_meta("target", "")
			if target != "":
				print("进入场景：", target)
				get_tree().change_scene_to_file(target)
				return
