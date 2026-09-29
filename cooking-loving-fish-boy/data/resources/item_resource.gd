class_name ItemResource
extends Resource

## 物品数据模板（数据驱动核心）
## 用法：在 Godot 编辑器里“右键 → 新建 Resource → 选 ItemResource”，
##       填好下面字段后存成 .tres（例如 chair_extra.tres）。
## 逻辑代码（P2/P4 的单例）只读取这些字段，绝不把物品内容写死在脚本里。
##
## 这就是为什么“加 100 个新物品”你只需要新建 100 个 .tres，
## 一行代码都不用改——所有物品共用这一个脚本。

# 物品分类。枚举在 .tres 里以整数存储：KEY=0, MATERIAL=1, NOTE=2, CONSUMABLE=3, QUEST=4
enum Category { KEY, MATERIAL, NOTE, CONSUMABLE, QUEST }

@export var id: String = ""                 # 唯一标识，如 "CHAIR_EXTRA"、"ATTIC_KEY"
@export var display_name: String = ""       # 显示名，如 "多余椅子"
@export var description: String = ""        # 物品说明（悬停/查看时显示）
@export var category: Category = Category.MATERIAL
@export var icon: Texture2D                 # 物品图标（放进 assets/icons/ 后拖进来）
@export var stackable: bool = false         # 能否堆叠
@export var max_stack: int = 1              # 最大堆叠数量
