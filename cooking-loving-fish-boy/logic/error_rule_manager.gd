extends Node

## ErrorRuleManager：规则错误系统的“引擎”（数据驱动规则表的核心）。
##
## 策划案里的“椅子搬离储物间两格以上 → 原地补出一把椅子（CHAIR_BUG）”
## 就是一条“数据”：触发条件=距离、目标=椅子、距离=2格、效果=复制、限 3 次。
##
## 本脚本只写一次“读规则 → 判断 → 执行”的通用逻辑，
## 之后加任何新 BUG 都只是往 data/rules/ 里多放一个 .tres，完全不用改代码。
##
## 阶段感知（P5/06 扩展）：
##   - 规则可设 active_stage：只有在该阶段才会判定（椅子复制只在 STAGE_06 生效）。
##   - 规则可设 advance_stage：触发到上限后推进到的阶段（椅子复制满 3 把 → STAGE_07）。
##   - STAGE_05 “把椅子搬进储物间”的推进也放在这里（world 注入储物间矩形）。
##
## 触发流程：
##   1) 椅子在 _ready 时把自己的“出生点(home)”注册进来 register_origin()
##   2) 玩家放下椅子时，Interactable 调用 notify_moved(椅子id, 当前位置)
##   3) 本管理器算出“离出生点多少格”，超阈值就执行效果（复制一把）

const TILE := 48   # 1 格 = 48 世界像素（方案B）

# 复制椅子时需要的预制体与资源（与 world.gd 里生成椅子保持一致）
const CHAIR_SCENE := "res://scenes/prop.tscn"
const CHAIR_RES   := "res://data/interactables/chair_extra.tres"
const CHAIR_TEX   := "res://assets/props/chair_placeholder.png"

# 储物间矩形（由 world.gd 在 _ready 注入）。椅子被搬进这个矩形 → STAGE_05 推进到 STAGE_06。
var storage_rect: Rect2 = Rect2()

var origins: Dictionary = {}        # target_id -> Vector2（物件出生点）
var trigger_counts: Dictionary = {} # rule_id -> 已触发次数
var rules: Array[ErrorRuleResource] = []

# 复制椅子进度广播（供 HUD 显示“已复制 X/3”）
signal rule_triggered(rule_id: String, count: int)

func _ready() -> void:
	_load_rules()

## 扫描 data/rules/ 下所有 .tres，加载为规则。
func _load_rules() -> void:
	rules.clear()
	var dir := DirAccess.open("res://data/rules")
	if dir != null:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if fname.ends_with(".tres"):
				var r := load("res://data/rules/" + fname) as ErrorRuleResource
				if r != null:
					rules.append(r)
			fname = dir.get_next()
		dir.list_dir_end()
	print("ErrorRuleManager：已加载 %d 条规则" % rules.size())

## 物件出生时登记它的“家”在哪（用于计算被搬离的距离）。
## 只记录第一次（原始椅子的家）；复制出来的椅子 _ready 时不要再覆盖它，
## 否则搬动“复制椅”会把“家”挪走，导致距离判定错乱、无限复制。
func register_origin(target_id: String, pos: Vector2) -> void:
	if not origins.has(target_id):
		origins[target_id] = pos

## 物件被移动后调用：判断是否触发规则 / 阶段推进。
func notify_moved(target_id: String, current_pos: Vector2) -> void:
	# —— STAGE_05：把多余椅子搬进储物间 → 进入“复制椅子”阶段（STAGE_06） ——
	# 同时把物件的“家”重新登记为储物间落点，这样 STAGE_06 里
	# “从储物间搬离两格以上”才会正确触发复制。
	if GameState.current_stage == "STAGE_05" and storage_rect.has_point(current_pos):
		origins[target_id] = current_pos
		QuestManager.advance_to("STAGE_06")
		return

	# —— 其余阶段：照常跑规则表（STAGE_06 的复制规则等） ——
	for rule in rules:
		if rule.target_id == target_id \
			and rule.trigger_condition == ErrorRuleResource.TriggerCondition.ON_DISTANCE \
			and rule.state == "ACTIVE" \
			and (rule.active_stage == "" or GameState.current_stage == rule.active_stage):
			var home: Vector2 = origins.get(target_id, current_pos)
			var dist_tiles: float = current_pos.distance_to(home) / float(TILE)
			if dist_tiles > rule.distance:
				_apply_effect(rule)

## 执行规则效果。
func _apply_effect(rule: ErrorRuleResource) -> void:
	var count: int = trigger_counts.get(rule.id, 0)
	if rule.max_triggers >= 0 and count >= rule.max_triggers:
		return                     # 触发次数已达上限
	count += 1
	trigger_counts[rule.id] = count
	rule_triggered.emit(rule.id, count)   # 供 HUD 显示“已复制 X/3”

	match rule.effect:
		ErrorRuleResource.Effect.DUPLICATE:
			# 在“家”的位置补出一把椅子（玩家把椅子搬走 → 规则认为这里还该有椅子）
			spawn_chair_at(origins.get(rule.target_id, Vector2.ZERO))
		_:
			pass

	# 达到触发上限：按数据推进到下一阶段（如 STAGE_06 → STAGE_07）。
	if rule.max_triggers >= 0 and count >= rule.max_triggers and rule.advance_stage != "":
		QuestManager.advance_to(rule.advance_stage)

## 在指定位置生成一把椅子（初始异常椅 + 复制椅 共用同一套资源/贴图）。
## 椅子实例的 _ready 会自动把“家”登记到出生点，方便后续距离判定。
func spawn_chair_at(pos: Vector2) -> void:
	var prefab: PackedScene = load(CHAIR_SCENE)
	var chair = prefab.instantiate()
	chair.resource = load(CHAIR_RES) as InteractableResource
	chair.sprite_texture = load(CHAIR_TEX)
	chair.global_position = pos
	get_tree().current_scene.add_child(chair)
	print("ErrorRuleManager：生成椅子于 ", pos)

## 取某规则的最大触发次数（供 HUD 显示进度分母）。
func get_max_triggers(rule_id: String) -> int:
	for r in rules:
		if r.id == rule_id:
			return r.max_triggers
	return -1
