class_name ErrorRuleResource
extends Resource

## 规则错误（BUG）数据模板 —— 这是“数据驱动规则表”的核心。
## 每条规则是一个 .tres；P4 的逻辑代码只写一次
##   “读规则 → 判断条件 → 执行效果”，
## 之后加任何新 BUG 都只是新增一个 .tres，完全不用碰代码。
##
## 策划案里的 CHAIR_BUG = REPAIRED、椅子搬离两格触发复制，
## 正是这种“数据”的典型例子。

# 触发条件。ON_DISTANCE=0, ON_PICKUP=1, ON_INTERACT=2, ON_TIMER=3, ON_FLAG=4
enum TriggerCondition { ON_DISTANCE, ON_PICKUP, ON_INTERACT, ON_TIMER, ON_FLAG }
# 触发效果。DUPLICATE=0, APPEAR=1, DISAPPEAR=2, MUTATE=3, TELEPORT=4
enum Effect { DUPLICATE, APPEAR, DISAPPEAR, MUTATE, TELEPORT }

@export var id: String = ""                            # 规则 id，如 "CHAIR_BUG"
@export var display_name: String = ""                  # 显示名，如 "复制椅子"
@export var description: String = ""                   # 玩家看到的异常描述
@export var trigger_condition: TriggerCondition = TriggerCondition.ON_DISTANCE
@export var target_id: String = ""                     # 触发对象 id，如 "CHAIR_EXTRA"
@export var distance: int = 2                          # 触发距离（格）：策划案“离开桌C两格以上”
@export var effect: Effect = Effect.DUPLICATE          # 触发后效果
@export var spawn_id: String = ""                      # 复制/出现时生成的物件 id
@export var max_triggers: int = -1                     # 最大触发次数；-1 = 无限（策划案需连搬 3 次）
@export var state: String = "ACTIVE"                   # 当前状态：ACTIVE / REPAIRED / RETAINED
@export var repair_flag: String = ""                   # 修复需要的 flag（选“修复它”后置位）
