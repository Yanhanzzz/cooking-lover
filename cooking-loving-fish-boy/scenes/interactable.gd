@tool
extends Area2D
class_name Interactable

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
## 当前正被搬着的物件引用（static，全实例共享）。玩家按 X 放下时直接找它，
## 不再依赖“物理重叠”判定——避免搬起后物件浮在头顶、检测不到、放不下来。
static var current_carried: Interactable = null

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

	# 存档点：直接开菜单（避免先弹提示、要按两次 X 才能存档）
	if resource.interaction_type == InteractableResource.InteractionType.SAVEPOINT:
		SaveMenu.open()
		return

	# 第一次按 X：优先展示调查文本（策划案里的“调查文本”列）
	if not _text_shown and resource.investigate_text != "":
		DialogueManager.show_text(resource.investigate_text)
		_text_shown = true
		_try_complete_stage()   # 若数据里配了 complete_stage，首次调查即推进阶段（如便签→STAGE_02、椅子→STAGE_03）
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
		InteractableResource.InteractionType.TRIGGER:
			# 触发型：优先打开“小游戏”（如烹饪台 minigame_id="COOKING"）；
			# 没配小游戏则按 dialogue_id 启动一段对话（NPC / 事件点用）。
			# 例如店长 NPC 设 dialogue_id="D01"，按 X 即播放 D01→D02 对话链。
			#
			# 端菜/交付型（如白川）：数据里配了 required_item（要消耗的物品 id）。
			#   - 不在对应阶段 / 背包里没有该物品 → 只提示，不消耗、不对话、不推进
			#   - 物品齐全 → 先消耗，再播对话；对话播完由 QuestManager 按 complete_stage 推进
			if resource.minigame_id != "":
				CookingGame.open()
			elif resource.dialogue_id != "":
				if resource.required_item != "":
					if GameState.current_stage != "STAGE_04":
						DialogueManager.show_text("现在还不到端菜的时候。")
						return
					if not InventoryManager.has(resource.required_item):
						DialogueManager.show_text("你手上还没有可端的料理（去后厨做一份味噌汤）。")
						return
					InventoryManager.remove(resource.required_item)   # 交付后消耗该物品
				DialogueManager.start(resource.dialogue_id)
		_:
			pass

## 首次调查时，若数据里配了 complete_stage，则推进到该阶段。
## 借助 _text_shown（首次调查才 true）保证“仅生效一次”，不会每次按 X 都推。
func _try_complete_stage() -> void:
	if resource == null or resource.complete_stage == "":
		return
	QuestManager.advance_to(resource.complete_stage)

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
		current_carried = self          # 登记：现在这把椅子正被搬着
	else:
		_carrier = null
		z_index = 2
		current_carried = null          # 清空：已经放下了
		if resource != null and resource.movable:
			ErrorRuleManager.notify_moved(resource.id, global_position)

func _physics_process(_delta: float) -> void:
	if _carried and _carrier != null:
		global_position = _carrier.global_position + CARRY_OFFSET
