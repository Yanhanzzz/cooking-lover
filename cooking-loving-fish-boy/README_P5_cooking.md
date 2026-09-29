# P5·做饭小游戏 交付说明（STAGE_03 后厨 · 味噌汤）

这一刀把策划案里**只写了描述、没有玩法**的「后厨料理」从数据变成**可玩的小游戏**。
它是第一关第一个真正接通「阶段流程」的谜题（之前那些 `objective_type=4` 的关卡都还只是文字）。

---

## 一、这次新增 / 改动了什么

### 新增物品（食材 + 成品，`data/items/`）
| 文件 | id | 说明 |
|---|---|---|
| `bowl.tres` | `BOWL` | 碗（食材） |
| `tofu.tres` | `TOFU` | 豆腐（食材） |
| `scallion.tres` | `SCALLION` | 葱（食材） |
| `miso_soup.tres` | `MISO_SOUP` | 味噌汤（成品，做出来后获得） |

### 新增交互物（`data/interactables/`）
| 文件 | 类型 | 作用 |
|---|---|---|
| `counter_bowl.tres` | PICKUP | 碗柜：按 X 拿「碗」 |
| `counter_tofu.tres` | PICKUP | 豆腐盒：按 X 拿「豆腐」 |
| `counter_scallion.tres` | PICKUP | 葱筐：按 X 拿「葱」 |
| `cooking_station.tres` | TRIGGER + `minigame_id="COOKING"` | 烹饪台：打开做饭小游戏 |

### 新增系统
| 文件 | 作用 |
|---|---|
| `logic/cooking_game.gd` | 做饭小游戏自动加载（托盘顺序型谜题） |

### 改动（接入）
- `data/resources/interactable_resource.gd`：加 `@export var minigame_id`（触发型专属，指定要开的小游戏）。
- `scenes/interactable.gd`：TRIGGER 分支改为「有 `minigame_id` 就开小游戏，否则按 `dialogue_id` 走对话」。
- `logic/item_db.gd`：注册 `BOWL / TOFU / SCALLION / MISO_SOUP` 四个 id。
- `project.godot`：注册 `CookingGame` 自动加载（节点名必须逐字为 `CookingGame`）。
- `scenes/player.gd`：面板打开时锁住移动，新增 `or CookingGame.is_open`。
- `scenes/world.tscn`：在厨房区域摆了 4 个 prop 实例（碗柜 / 豆腐盒 / 葱筐 / 烹饪台）。

### 占位贴图（`assets/props/`，48×48）
`bowl_placeholder.png` / `tofu_placeholder.png` / `scallion_placeholder.png` / `cooking_station_placeholder.png`
（真美术到位后，在 world.tscn 里把对应实例的 `sprite_texture` 换掉即可。）

---

## 二、怎么测试（按 F5）

1. 主场景已是 `world.tscn`，直接 **F5**。
2. 当前演示大地图硬设成「餐桌区(STAGE_01)」。要进后厨，用屏幕**右上角「调试·阶段步进」**的 **「下一阶段」** 点两下，切到 **「后厨」**（或直接把 `world.gd` 里 `QuestManager.advance_to("STAGE_01")` 临时改成 `"STAGE_03"`，测完改回）。
3. 走到厨房左上角三块台子（碗柜 / 豆腐盒 / 葱筐），各按 **X** 两次（第一次看说明，第二次拿走）→ 三样食材进背包。
4. 走到「烹饪台」，**X** 第一次看说明，**X** 第二次打开料理面板。
5. 面板里依次点 **「摆上：碗」→「摆上：豆腐」→「摆上：葱」**，托盘显示 `碗 → 豆腐 → 葱`，点 **「完成」**。
   - 顺序错（比如先点豆腐）：提示「顺序不对，再试一次」，托盘清空。
   - 顺序对：消耗三样食材、获得「味噌汤」、阶段从 **后厨(STAGE_03) 自动推进到 餐桌B(STAGE_04)**，并弹出成功提示。
6. 按 **I** 打开背包，应能看到「味噌汤」。

---

## 三、它怎么接进阶段流程（你之前问的「流程 vs 填物品」）

之前那些 `objective_type=4` 的关卡都只是 `.tres` 里的描述文字，**没有任何逻辑**。
这次做的做饭小游戏是第一个把「描述」变成「玩法」并**真实推进阶段**的例子：

- 小游戏成功 → `CookingGame._succeed()` 读当前阶段 `STAGE_03.tres` 的 `next_stage`（= `STAGE_04`），调用 `QuestManager.advance_to()`。
- 这和「对话播完推进阶段」(`DialogueManager` → `QuestManager`) 是**同一套事件驱动机制**，只是触发源从「对话」换成了「小游戏」。

也就是说：**以后每个谜题（端菜 / 叠椅 / 椅影 / 错误源选择）都照这个模板**——做一个小游戏或交互，成功时 `advance_to(next_stage)` 即可，阶段链全在 `data/stages/STAGE_xx.tres` 里维护。

---

## 四、想改菜单 / 加菜怎么办（数据驱动）

打开 `logic/cooking_game.gd`，顶部就一行配方：

```gdscript
const RECIPE: Array = [
	{"id": "BOWL",     "name": "碗"},
	{"id": "TOFU",     "name": "豆腐"},
	{"id": "SCALLION", "name": "葱"},
]
```

- 改顺序 = 改这道菜的做法（比如先放葱再放豆腐）。
- 加一步 = 往数组里加 `{"id": "EGG", "name": "蛋"}`，并记得在 `ItemDB` 和 `data/items/` 里加对应物品。
- 换成品 = 把 `_succeed()` 里的 `"MISO_SOUP"` 换成你新做的菜 id。

UI、判定、消耗、奖励逻辑都不用动。

---

## 五、已知占位 / 下一步（还没做的谜题流程）

- **STAGE_02→03 的自然衔接还没自动接通**：现在围裙拾取（`cabinet_apron`）没配 `complete_stage`，所以正常玩到不了后厨——目前靠调试步进器切阶段。需要的话我把 `cabinet_apron.tres` 的 `complete_stage` 设成 `STAGE_03`（顺手修好这条链）。
- 仍待做的 `objective_type=4` 流程：**端菜给白川(STAGE_04)**、**搬椅子(STAGE_05)**、**复制椅子(STAGE_06)**、**叠椅取钥匙(STAGE_07)**、**里线椅影(STAGE_09)**、**错误源选择(STAGE_10)**。
- 做饭小游戏目前用鼠标点按钮；需要纯键盘操作（数字键选食材 / 回车完成）可再加。
