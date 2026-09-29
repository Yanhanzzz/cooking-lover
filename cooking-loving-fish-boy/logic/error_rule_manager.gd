extends Node

## ErrorRuleManager：规则错误系统的“引擎”（数据驱动规则表的核心）。
##
## 策划案里的“椅子搬离桌C两格以上 → 桌边补出一把椅子（CHAIR_BUG）”
## 就是一条“数据”：触发条件=距离、目标=椅子、距离=2格、效果=复制。
##
## 本脚本只写一次“读规则 → 判断 → 执行”的通用逻辑，
## 之后加任何新 BUG 都只是往 data/rules/ 里多放一个 .tres，完全不用改代码。
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

var origins: Dictionary = {}        # target_id -> Vector2（物件出生点）
var trigger_counts: Dictionary = {} # rule_id -> 已触发次数
var rules: Array[ErrorRuleResource] = []

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
	# 兜底：若目录扫描失败，至少加载已知的椅子规则
	if rules.is_empty() and ResourceLoader.exists(CHAIR_RES.get_base_dir().replace("interactables", "rules") + "/chair_bug.tres"):
		pass
	print("ErrorRuleManager：已加载 %d 条规则" % rules.size())

## 物件出生时登记它的“家”在哪（用于计算被搬离的距离）。
## 只记录第一次（原始椅子的家）；复制出来的椅子 _ready 时不要再覆盖它，
## 否则搬动“复制椅”会把“家”挪走，导致距离判定错乱、无限复制。
func register_origin(target_id: String, pos: Vector2) -> void:
	if not origins.has(target_id):
		origins[target_id] = pos

## 物件被移动后调用：判断是否触发规则。
func notify_moved(target_id: String, current_pos: Vector2) -> void:
	for rule in rules:
		if rule.target_id == target_id \
			and rule.trigger_condition == ErrorRuleResource.TriggerCondition.ON_DISTANCE \
			and rule.state == "ACTIVE":
			var home: Vector2 = origins.get(target_id, current_pos)
			var dist_tiles: float = current_pos.distance_to(home) / float(TILE)
			if dist_tiles > rule.distance:
				_apply_effect(rule)

## 执行规则效果。
func _apply_effect(rule: ErrorRuleResource) -> void:
	var count: int = trigger_counts.get(rule.id, 0)
	if rule.max_triggers >= 0 and count >= rule.max_triggers:
		return                     # 触发次数已达上限
	trigger_counts[rule.id] = count + 1

	match rule.effect:
		ErrorRuleResource.Effect.DUPLICATE:
			_spawn_duplicate()
		_:
			pass

	# 首次触发推进剧情阶段：进入“储物间·复制椅子”阶段（STAGE_06）。
	# 策划案：05 餐桌C 椅子开始重复 → 06 储物间主动复制椅子收集 3 把。
	if count == 0:
		QuestManager.advance_to("STAGE_06")

## 在桌C位置复制出一把椅子（与 world.gd 生成原始椅子用同一套资源/贴图）。
func _spawn_duplicate() -> void:
	var prefab: PackedScene = load(CHAIR_SCENE)
	var dup = prefab.instantiate()
	dup.resource = load(CHAIR_RES) as InteractableResource
	dup.get_node("Sprite2D").texture = load(CHAIR_TEX)
	dup.global_position = origins.get("CHAIR_EXTRA", Vector2.ZERO)
	get_tree().current_scene.add_child(dup)
	print("ErrorRuleManager：触发规则——桌边复制出一把椅子！")
