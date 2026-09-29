class_name InteractableResource
extends Resource

## 交互物件数据模板
## 场景里每个“可调查 / 可拾取 / 可存档 / 可搬运”的物体，都引用一个它。
## 关键：脚本只负责“读数据 → 表现”，所有内容来自 .tres。
## 这就是之前讲的“数据驱动”而非“硬编码”——脚本不认识椅子，它只认识数据。

# 交互类型。.tres 里存整数：INVESTIGATE=0, PICKUP=1, SAVEPOINT=2, DOOR=3, TRIGGER=4, MOVABLE=5
enum InteractionType { INVESTIGATE, PICKUP, SAVEPOINT, DOOR, TRIGGER, MOVABLE }

@export var id: String = ""                            # 唯一标识，如 "CHAIR_EXTRA"
@export var display_name: String = ""                  # 显示名
@export var investigate_text: String = ""              # 按 X 调查时显示的文本（来自策划案“调查文本”列）
@export var interaction_type: InteractionType = InteractionType.INVESTIGATE
@export var linked_item: ItemResource                  # 调查/拾取后给玩家的物品（无则留空）
@export var dialogue_id: String = ""                   # 关联对话 id（如 "D01"），空则不触发对话
@export var minigame_id: String = ""                   # 触发型专属：要打开的小游戏 id（如 "COOKING"）。空则按 dialogue_id 走对话
@export var state: String = "NORMAL"                   # 物件状态枚举，如 NORMAL / MOVED / USED
@export var movable: bool = false                      # 是否可被玩家搬动（椅子谜题用）
@export var save_slot_count: int = 3                   # 仅 SAVEPOINT 用：存档槽位数
@export var complete_stage: String = ""                # 首次调查后推进到的阶段（空=不推进）。如 "STAGE_02"
