class_name QuestResource
extends Resource

## 任务 / 阶段数据模板。
## 第一关 13 个阶段 = 13 个 QuestResource（id 为 STAGE_00 .. STAGE_12）。
## 用 objective_type 描述“怎样算完成”，逻辑代码读它来推进进度条与阶段跳转。

# 目标类型。.tres 里存整数：REACH=0, COLLECT=1, TALK=2, INVESTIGATE=3, CUSTOM=4
enum ObjectiveType { REACH, COLLECT, TALK, INVESTIGATE, CUSTOM }

@export var id: String = ""                              # 阶段 id，如 "STAGE_05"
@export var title: String = ""                          # 任务标题，如 "椅子开始重复"
@export var description: String = ""                    # 任务描述（右上角目标提示 UI 用）
@export var objective_type: ObjectiveType = ObjectiveType.CUSTOM
@export var objective_target: String = ""               # 目标对象 id，如 "CHAIR_EXTRA"、"ATTIC_KEY"
@export var objective_count: int = 1                    # 需要的数量（收集类用）
@export var next_stage: String = ""                     # 完成后进入的下一阶段 id
