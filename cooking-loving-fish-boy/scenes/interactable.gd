@tool
extends Area2D

## Interactable：通用"可交互物件"脚本（数据驱动核心之一）。
## 场景里每个椅子 / 收银机 / 便签都是同一个 prop.tscn，差别只来自它在编辑器里
## 绑定的 InteractableResource 数据（resource）和贴图（sprite_texture）。
## 这两个都是 @export，直接在检视面板里填，无需任何代码。
##
## 玩家按 X 时，Player 会调用本脚本的 interact(player)。
## 我们按 resource.interaction_type 做不同反应：
##   INVESTIGATE 调查 / PICKUP 拾取 / SAVEPOINT 存档点 / MOVABLE 可搬动
##
## 关键设计（呼应之前讲的“一个通用脚本 + 每个物件一份数据”）：
##   脚本不认识“椅子”，它只认识“数据”。加 100 个物件 = 加 100 份数据，代码一行不动。

@export var resource: InteractableResource
## 每个物件在编辑器里选的贴图。用 setter 实时应用到 Sprite2D，
## 这样在编辑器 2D 视口里就能直接看到物件长什么样（@tool 生效）。
var _sprite_texture: Texture2D = null
@export var sprite_texture: Texture2D:
	set(value):
		_sprite_texture = value
		if is_inside_tree() and has_node("Sprite2D"):
			$Sprite2D.texture = value
	get:
		return _sprite_texture

var _text_shown := false      # 调查文本是否已经展示过（避免每次按 X 都弹）
var _carried := false         # 是否正被玩家搬着
var _carrier: Node = null     # 搬它的玩家引用

const CARRY_OFFSET := Vector2(0, -44)   # 搬起时浮在玩家头顶上方

func _ready() -> void:
	add_to_group("interactable")
	z_index = 2
	# 初始把贴图应用到 Sprite2D（场景加载时也会走 setter，这里兜底一次）
	if _sprite_texture != null and has_node("Sprite2D"):
		$Sprite2D.texture = _sprite_texture
	# 可搬动的物件，出生时把自己的"家"登记给规则引擎（用于算被搬离距离）
	# 注意：编辑器预览时不要登记，否则会污染运行时状态
	if not Engine.is_editor_hint() and resource != null and resource.movable:
		ErrorRuleManager.register_origin(resource.id, global_position)

## 玩家按 X 时由 Player 调用。player 传进来是为了“搬动”时能跟随。
func interact(player: Node) -> void:
	if resource == null:
		return

	# 第一次按 X：优先展示调查文本（策划案里的“调查文本”列）
	if not _text_shown and resource.investigate_text != "":
		DialogueManager.show_text(resource.investigate_text)
		_text_shown = true
		return

	match resource.interaction_type:
		InteractableResource.InteractionType.INVESTIGATE:
			DialogueManager.show_text(resource.investigate_text)
		InteractableResource.InteractionType.PICKUP:
			_do_pickup()
		InteractableResource.InteractionType.SAVEPOINT:
			SaveMenu.open()
		InteractableResource.InteractionType.MOVABLE:
			_toggle_carry(player)
		_:
			pass

## 拾取：把关联物品（linked_item）收进背包，然后物件从场景消失。
func _do_pickup() -> void:
	if resource.linked_item != null:
		InventoryManager.pick_up(resource.linked_item)
	queue_free()

## 拿起 / 放下切换。放下时通知规则引擎“此处距离是否触发 BUG”。
func _toggle_carry(player: Node) -> void:
	_carried = not _carried
	if _carried:
		_carrier = player
		z_index = 5
	else:
		_carrier = null
		z_index = 2
		if resource != null and resource.movable:
			ErrorRuleManager.notify_moved(resource.id, global_position)

func _physics_process(_delta: float) -> void:
	if _carried and _carrier != null:
		global_position = _carrier.global_position + CARRY_OFFSET
