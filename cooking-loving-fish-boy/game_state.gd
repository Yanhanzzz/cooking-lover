extends Node

## GameState：全局游戏状态单例。
## 需要在 项目设置 → 自动加载(AutoLoad) 里注册为 "GameState"（见 README_P2）。
##
## 职责：只保存「会被存档的元状态」——
##   当前阶段、各种开关 flag、规则错误状态、背包、已触发事件、头像/地点（用于存档界面显示）。
##
## 关键设计：所有写操作都走下面的 set_/add_/mark_ 方法，
## 它们会在值变化时广播信号（signal）。这样 UI 和场景可以"监听"这些变化自动刷新，
## 而不用每帧去问"现在 stage 是多少"。这是 Godot 里解耦系统的标准做法。

signal stage_changed(old_stage: String, new_stage: String)
signal flag_changed(flag_name: String, value: bool)
signal error_state_changed(rule_id: String, new_state: String)
signal inventory_changed
signal event_triggered(event_id: String)

const SAVE_SLOTS := 3

# ---- 可被存档的状态（SaveManager 会读取这些） ----
var current_stage: String = "STAGE_00"
var flags: Dictionary = {}                       # 各种开关，如 {"met_xiaokui": true}
var error_states: Dictionary = {}                 # 规则错误状态，如 {"CHAIR_BUG": "ACTIVE"}
var inventory: Array[String] = []                # 背包物品 id 列表（P4 背包系统会接管操作）
var triggered_events: Array[String] = []         # 已触发过的事件 id（防重复触发）
var portrait_path: String = ""                   # 当前存档头像路径（存档界面显示用）
var location_name: String = ""                   # 当前存档地点名（如 "厨房"）

# ---- 写入方法（一律走这里，自动广播信号） ----
func set_stage(new_stage: String) -> void:
	if new_stage == current_stage:
		return
	var old := current_stage
	current_stage = new_stage
	stage_changed.emit(old, new_stage)

func set_flag(name: String, value: bool) -> void:
	if flags.get(name) == value:
		return
	flags[name] = value
	flag_changed.emit(name, value)

func set_error_state(rule_id: String, new_state: String) -> void:
	if error_states.get(rule_id) == new_state:
		return
	error_states[rule_id] = new_state
	error_state_changed.emit(rule_id, new_state)

func add_item(item_id: String) -> void:
	if item_id not in inventory:
		inventory.append(item_id)
		inventory_changed.emit()

func has_item(item_id: String) -> bool:
	return item_id in inventory

func remove_item(item_id: String) -> void:
	if inventory.has(item_id):
		inventory.erase(item_id)
		inventory_changed.emit()

func mark_event_triggered(event_id: String) -> void:
	if event_id not in triggered_events:
		triggered_events.append(event_id)
		event_triggered.emit(event_id)

func has_event_triggered(event_id: String) -> bool:
	return event_id in triggered_events
