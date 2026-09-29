extends Node

## InventoryManager：背包系统单例。
## 职责：管理“玩家当前持有的物品”（ItemResource 对象数组），
##       并把物品 id 同步进 GameState.inventory（字符串数组），以便存档。
##
## 为什么分成两层？
##   - 逻辑/显示需要 ItemResource（有名字、图标、说明）；
##   - 存档只需要轻量的 id 字符串，方便序列化成 JSON。
##   所以这里持有“富对象”，GameState 持有“id 清单”，两者保持同步。

signal inventory_changed

var items: Array[ItemResource] = []

## 拾取一个物品。返回 true 表示真的进了背包（去重，避免重复拾取同一件）。
func pick_up(res: ItemResource) -> bool:
	if res == null:
		return false
	for it in items:
		if it.id == res.id:
			return false   # 已存在（非堆叠物品按唯一处理）
	items.append(res)
	GameState.add_item(res.id)        # 同步到 GameState（会广播 inventory_changed）
	inventory_changed.emit()
	print("InventoryManager：拾取 -> ", res.display_name)
	return true

func has(id: String) -> bool:
	for it in items:
		if it.id == id:
			return true
	return GameState.has_item(id)

func remove(id: String) -> void:
	for i in range(items.size()):
		if items[i].id == id:
			items.remove_at(i)
			GameState.remove_item(id)
			inventory_changed.emit()
			return

func get_all() -> Array[ItemResource]:
	return items

## 读档后根据 GameState 里的 id 清单，把物品对象重建回来。
## 由 SaveManager 在 _apply_snapshot 之后调用。
func load_from_ids(ids: Array) -> void:
	clear()
	for id in ids:
		var res := ItemDB.get_item(id)
		if res != null:
			items.append(res)

func clear() -> void:
	items.clear()
