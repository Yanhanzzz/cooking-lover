extends Node

## SaveManager：存档单例。
## 需要在 项目设置 → 自动加载(AutoLoad) 里注册为 "SaveManager"（见 README_P2）。
## 注意顺序：GameState 必须排在 SaveManager 之前，因为本脚本直接读取 GameState。
##
## 存档结构 = JSON 快照，每个槽位一个文件，存在 user://saves/slot_N.json
## （user:// 是 Godot 的持久化用户目录，打包后也安全，不会塞进资源包）。
##
## 一份存档包含你在策划案里要求的全部内容：
##   时间、人物头像、存档地点、当前阶段、背包、规则错误状态、各种 flag、已触发事件。
##
## 交互方式（策划案要求）：玩家走到收银机/打卡机按 X → 弹出菜单 →
##   自己选空位存 / 覆盖旧档 / 读新档。这个"菜单 UI"在 P5 做，本期先把读写底层写好。

const SAVE_DIR := "user://saves/"
const SLOT_COUNT := 3

# ---- 对外接口 ----

## 槽位是否存在存档
func save_exists(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))

## 存档到指定槽位（覆盖写）
func save_game(slot: int) -> void:
	_ensure_dir()
	var data := _collect_snapshot(slot)
	var json := JSON.stringify(data, "\t")   # 美化缩进，方便你用记事本查看
	var f := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("存档失败：无法写入 %s" % _slot_path(slot))
		return
	f.store_string(json)
	f.close()
	print("SaveManager：已存档到槽位 %d（%s）" % [slot, data["timestamp"]])

## 从指定槽位读档并恢复到 GameState
func load_game(slot: int) -> bool:
	if not save_exists(slot):
		push_error("读档失败：槽位 %d 不存在" % slot)
		return false
	var f := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed == null or not parsed is Dictionary:
		push_error("读档失败：槽位 %d 数据损坏" % slot)
		return false
	_apply_snapshot(parsed)
	print("SaveManager：已从槽位 %d 读档" % slot)
	return true

## 只读取存档界面的展示信息（时间/头像/地点），不恢复游戏
func read_meta(slot: int) -> Dictionary:
	if not save_exists(slot):
		return {}
	var f := FileAccess.open(_slot_path(slot), FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed == null or not parsed is Dictionary:
		return {}
	return {
		"timestamp": parsed.get("timestamp", ""),
		"portrait": parsed.get("portrait", ""),
		"location_name": parsed.get("location_name", ""),
	}

# ---- 内部实现 ----

func _slot_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.json" % slot

func _ensure_dir() -> void:
	# DirAccess 的方法不是静态的：必须先用 open() 拿到一个"目录实例"再调用。
	# 打开 user:// 根目录，之后所有操作都相对于它。
	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("无法打开 user:// 目录，错误码：%d" % DirAccess.get_open_error())
		return
	if not dir.dir_exists("saves"):
		var err := dir.make_dir_recursive("saves")
		if err != OK:
			push_error("创建 saves 目录失败，错误码：%d" % err)

func _collect_snapshot(slot: int) -> Dictionary:
	return {
		"slot_id": slot,
		"timestamp": Time.get_datetime_string_from_system(),  # 如 "2026-09-28 14:47:23"
		"portrait": GameState.portrait_path,
		"location_name": GameState.location_name,
		"stage": GameState.current_stage,
		"inventory": GameState.inventory,
		"error_states": GameState.error_states,
		"flags": GameState.flags,
		"triggered_events": GameState.triggered_events,
	}

func _apply_snapshot(d: Dictionary) -> void:
	GameState.current_stage = d.get("stage", "STAGE_00")
	GameState.inventory.assign(d.get("inventory", []))
	GameState.error_states = d.get("error_states", {})
	GameState.flags = d.get("flags", {})
	GameState.triggered_events.assign(d.get("triggered_events", []))
	GameState.portrait_path = d.get("portrait", "")
	GameState.location_name = d.get("location_name", "")
	# 读档后，根据 GameState 里的 id 清单把“富对象”背包重建回来（P4 新增）
	InventoryManager.load_from_ids(GameState.inventory)
	# 广播变化，让 UI / 场景重新同步（即使此刻没人监听也不会报错）
	GameState.stage_changed.emit("", GameState.current_stage)
	GameState.inventory_changed.emit()
