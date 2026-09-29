# P4 交付说明：交互 / 背包 / 任务 / 对话 / 规则错误系统

本文件对应开发阶段的 **P4**。P0–P3 已完成（环境、分辨率/输入、数据层、地图与区域）。
这一刀把你策划案里的“内容”真正接进游戏：能调查、能搬椅子、能触发“复制椅子”的规则错误、
能弹对话框、能在收银机存档/读档/覆盖。

---

## 一、P4 新增 / 改动的文件

### 新增（核心系统单例，`logic/` 目录）
| 文件 | 作用 |
|---|---|
| `logic/item_db.gd` | 物品注册表：id → 物品资源路径，读档时把 id 还原成物品对象 |
| `logic/inventory_manager.gd` | 背包系统：持有“富对象”数组，并同步 id 清单到 GameState 以便存档 |
| `logic/quest_manager.gd` | 任务/阶段推进：记录当前阶段、推进、广播变化 |
| `logic/error_rule_manager.gd` | **规则错误引擎**：数据驱动，读 `data/rules/*.tres` 判断并执行效果（如复制椅子） |
| `logic/dialogue_manager.gd` | 对话系统：打字机效果对话框，支持 `start("D01")` 与 `show_text("...")` |
| `logic/save_menu.gd` | 存档菜单 UI：列出 3 槽（时间/头像/地点），Z 读取/存、X 覆盖、Esc 关 |

### 新增（通用交互）
| 文件 | 作用 |
|---|---|
| `scenes/interactable.gd` | 通用交互脚本：按 `InteractableResource` 的 `interaction_type` 分发（调查/拾取/存档点/可搬动） |
| `scenes/prop.tscn` | 交互物预制体（Area2D + Sprite2D + CollisionShape2D），所有物件共用 |
| `assets/props/*.png` | 椅子/收银机/便签 三张占位图（48×48） |

### 新增（数据 `.tres`）
- `data/interactables/note.tres`（便签，调查型）
- `data/interactables/cashier.tres`（收银机，存档点）

### 改动（接入）
- `scenes/player.gd`：按 X 时把 `self` 传给 `interact()`；对话/菜单打开时锁住移动与交互
- `scenes/world.gd`：已移除代码生成道具的 `_setup_props()`。交互物改为在编辑器里手动摆放 `prop.tscn`（填 `resource` 与 `sprite_texture` 两个导出项），更直观、易调试、与代码解耦。
- `save_manager.gd`：`_apply_snapshot` 读档后调用 `InventoryManager.load_from_ids()` 重建背包
- `logic/error_rule_manager.gd`：`register_origin` 加“只记录首次”守卫，防止复制椅覆盖原始出生点

---

## 二、必须在 Godot 里做的一步：注册自动加载（AutoLoad）

P4 新增了 3 个单例（`InventoryManager`、`DialogueManager`、`SaveMenu` 等），
**都必须注册**，否则代码里 `InventoryManager.xxx` 这种调用会报“标识符未定义”。

打开 **项目 → 项目设置 → 自动加载(AutoLoad)**，按下面顺序逐个“添加”并“指定节点名”：
（顺序：GameState / SaveManager 在最前，其余其后；节点名必须**逐字**如下，因为脚本里就是用这些名字调用的）

| 路径 | 节点名 |
|---|---|
| `res://game_state.gd` | `GameState` |
| `res://save_manager.gd` | `SaveManager` |
| `res://logic/item_db.gd` | `ItemDB` |
| `res://logic/inventory_manager.gd` | `InventoryManager` |
| `res://logic/quest_manager.gd` | `QuestManager` |
| `res://logic/error_rule_manager.gd` | `ErrorRuleManager` |
| `res://logic/dialogue_manager.gd` | `DialogueManager` |
| `res://logic/save_menu.gd` | `SaveMenu` |

> 提示：之前 P2 你已注册过 GameState / SaveManager。这次只需把后面 6 个补上。
> 注册后按 F5，若输出面板没报 “preload / 标识符” 类错误，说明 AutoLoad 全通了。

---

## 三、怎么验证（运行测试清单）

把主场景设为 `res://scenes/world.tscn`，按 **F5**：

1. **调查**：走到厨房里那张“便签”（小图块），按 **X** → 弹出打字机文本，按 **Z** 翻页/关闭。
2. **搬动**：走到“多余椅子”，按 **X**（首次显示调查语），再按 **X** 拿起（浮到头顶），
   走到离它原点 2 格以上放下 → 输出面板打印“桌边复制出一把椅子！”并真的多出一把。
3. **存档**：走到吧台“收银机”，按 **X** → 存档菜单弹出；用 **↑↓** 选槽，
   **Z** 存到空槽 / **X** 覆盖；**Esc** 关闭。输出面板会打印“已存档到槽位 N”。
4. **读档**：重新按 X 开菜单，**↑↓** 选一个已有档，按 **Z** 读取 → 阶段/背包恢复。
5. **门**：走到最右侧门，按 **X** 进里世界，中央按 **X** 返回（沿用 P3）。

---

## 四、各系统一句话讲解（复习你之前问过的概念）

- **单例 / AutoLoad**：一个全局可调用、跨场景不销毁的节点。注册后才能 `GameState.xxx` 直接调。
- **信号(signal)**：状态变化时“广播一声”，谁关心谁接。本作 `inventory_changed`、`stage_changed` 都靠它解耦 UI 与逻辑。
- **数据驱动**：物件长什么样、怎么交互，全在 `.tres` 里；脚本只认“数据”，加 100 个物件只加 100 份数据，代码不动。
- **Area2D 感应区**：不挡人，只在有东西进出时发信号；本作用它做“区域判定（更新存档地点）”和“门（切场景）”。
- **规则错误引擎**：把 `CHAIR_BUG`（搬离 2 格 → 复制）写成 `data/rules/chair_bug.tres`；引擎只写一次“读规则→判断→执行”，加新 BUG 只加 `.tres`。
- **打字机对话框**：用代码现搭的 `CanvasLayer + Panel + Label`，逐字显形；按 Z 推进。

---

## 五、已知占位 / 后续（P5 再做）

- 角色仍是 48×48 绿块；人物立绘到位后换 `player.tscn` 的 Sprite2D 贴图即可。
- 交互物是占位 PNG，真美术到位替换 `assets/props/*.png`。
- 对话目前只有“调查文本”走 `show_text`；完整 `D01` 线性对话链（`start("D01")` 串 next_id）已留好接口，P5 接事件编排。
- 规则错误目前只实现了 `CHAIR_BUG`；`chair_bug.tres` 的 `max_triggers = -1`（无限），要“连搬 3 次”改成 `3` 即可。
- `interactable.gd` 顶部的 `[调试]` 打印行（player.gd 里）确认无误后可删。
