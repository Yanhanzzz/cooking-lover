extends Node

## ItemDB：物品注册表（ID → 物品资源 .tres 的路径）。
## 作用：读档时 GameState 里只存了物品 id 字符串（为了存档轻量），
##       需要把 id 还原成完整的 ItemResource（名字/图标/说明）时，来这里查。
##
## 为什么用“注册表”而不是直接按 id 拼路径？
##   因为有的物品放在子目录（如 consumable/），统一登记在这里最清晰、最不容易拼错。
##   加新物品时，在 ITEM_PATHS 里加一行即可（等以后物品多了，可改成扫描整个目录）。

const ITEM_PATHS := {
	"CHAIR_EXTRA": "res://data/items/chair_extra.tres",
	"NOTE_CLUE":   "res://data/items/note_clue.tres",
}

func get_item(id: String) -> ItemResource:
	if ITEM_PATHS.has(id):
		return load(ITEM_PATHS[id]) as ItemResource
	# 兜底：按约定路径尝试加载 res://data/items/<id>.tres
	var fallback := "res://data/items/%s.tres" % id
	if ResourceLoader.exists(fallback):
		return load(fallback) as ItemResource
	push_warning("ItemDB：找不到物品 id = %s" % id)
	return null
