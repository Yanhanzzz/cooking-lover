# P5 进度：STAGE_02→03 衔接 + STAGE_04 端菜给白川（含「盘子变两个」异常）

> 承接 README_P5_cooking.md。本文件只记录本次两件事的改动与测试。

## 一、STAGE_02→03 自然衔接（任务1）

**改动**：`data/interactables/cabinet_apron.tres` 的 `complete_stage` 由 `""` 改为 `"STAGE_03"`。

**机制**：和「便签→STAGE_02 / 椅子调查→STAGE_05」同套逻辑——首次按 X 调查柜子（显示「诺尔的临时柜…」文本）时，由 `interactable.gd` 的 `_try_complete_stage()` 把阶段从「员工室(STAGE_02)」推进到「后厨(STAGE_03)」；再按一次 X 才真正拾取围裙。

**完整前段链**（已通）：
- 和店长 NPC 对话(D01) → 推进 STAGE_01→02（员工室）
- 调查并拾取围裙 → 推进 STAGE_02→03（后厨）
- 厨房三柜台拿碗/豆腐/葱，烹饪台做味噌汤 → 推进 STAGE_03→04（餐桌B）
- 端给白川 → 推进 STAGE_04→05（餐桌C）

## 二、STAGE_04 端菜给白川（任务2）

### 新增数据
- `data/interactables/shirakawa.tres`：白川 NPC。`interaction_type=4(TRIGGER)`，`dialogue_id="D03"`，`required_item="MISO_SOUP"`（端菜交付型）。
- `data/dialogues/d03.tres`：白川反应对话。`complete_stage="STAGE_05"`、`complete_event="D03_done"`、`complete_flag="served_shirakawa"`。
- `data/interactables/plate_b.tres`：餐桌B的盘子。`interaction_type=0(INVESTIGATE)`，调查文本即「盘子变两个」异常描述。
- `scenes/world.tscn`：新增「白川」「餐桌B_盘子」两个 prop 实例，以及一个隐藏的「餐桌B_复制盘」Sprite2D（`visible=false`）。

### 新增字段 / 逻辑
- `data/resources/interactable_resource.gd`：新增 `@export var required_item: String`（端菜/交付型要消耗的物品 id）。
- `scenes/interactable.gd` 的 `TRIGGER` 分支新增端菜判定：
  - 若 `required_item` 非空：不在 STAGE_04 → 提示「现在还不到端菜的时候」；背包没有该物品 → 提示「你手上还没有可端的料理」；两者皆非 → **先消耗物品**再播对话。
  - 对话播完由 `QuestManager._on_dialogue_ended` 按 `complete_stage` 推进 STAGE_05（与 D01 推进阶段完全同套事件驱动）。
- `scenes/world.gd`：监听 `QuestManager.stage_advanced`，进入 `STAGE_05` 时把隐藏的「餐桌B_复制盘」设为可见，并弹出诡异提示「（桌角不知何时多了一套空餐具……你明明只端了一份味噌汤。）」——对应策划案 STAGE_04「镜头切换后多出一套餐」。

## 三、怎么测
F5 运行后任选一条：
1. **调试步进器**（右上角）：点「下一阶段」到 STAGE_03→给背包塞味噌汤（用之前做的）→ 步进到 STAGE_04 → 走到白川按 X 端菜 → 自动到 STAGE_05，复制盘出现。
2. **完整走一遍**：和店长对话(D01) → 调查/拿围裙（进后厨）→ 三柜台拿食材 → 烹饪台做汤（进餐桌B）→ 走到白川按 X 端汤 → 进餐桌C，桌子凭空多出一套餐具。

> 注意：端菜前必须先有「味噌汤」（后厨做出）。白川在 (300,200)，盘子在 (300,224)，复制盘在 (332,224) 初始隐藏。占位贴图复用 `placeholder_player.png`（白川）与 `bowl_placeholder.png`（盘子）。

## 四、本次未做（你后续可选）
- 错误源「修复/保留」分支 UI（RULE_SHARD 暂无入口）。
- STAGE_05 餐桌C、06 储物间复制、07 取钥匙、08 阁楼、09 里线等真实谜题逻辑。
- 真实美术立绘替换占位绿块。
