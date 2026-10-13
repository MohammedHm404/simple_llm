# DataStore.gd — حفظ وقراءة كل البيانات
extends Node
class_name DataStore

const SEED := "res://data/seed_knowledge.json"
const DIR := "user://ai_brain"
const KP := DIR + "/knowledge.json"
const MP := DIR + "/memory.json"
const UP := DIR + "/user.json"

var knowledge: Dictionary = {}
var memory: Dictionary = {}
var user: Dictionary = {}

func _ready():
	if not DirAccess.dir_exists_absolute(DIR):
		DirAccess.make_dir_recursive_absolute(DIR)
	knowledge = _load_or_create(KP, SEED)
	memory = _load_or_create(MP, {"conversations": [], "learned_facts": []})
	user = _load_or_create(UP, {"name": "", "auto_learn": true})

# يحمّل ملف JSON أو ينشئه من مصدر افتراضي
func _load_or_create(path: String, default_or_seed) -> Dictionary:
	if FileAccess.file_exists(path):
		return _read(path)
	var data: Dictionary = _read(default_or_seed) if default_or_seed is String else default_or_seed
	_write(path, data)
	return data

func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return {}
	var txt := f.get_as_text()
	f.close()
	var j = JSON.parse_string(txt)
	return j if j is Dictionary else {}

func _write(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return
	f.store_string(JSON.stringify(data, "  "))
	f.close()

# حفظ
func save_knowledge() -> void: _write(KP, knowledge)
func save_memory() -> void: _write(MP, memory)
func save_user() -> void: _write(UP, user)

# إضافة سؤال → جواب
func add_knowledge(q: String, a: String) -> void:
	if not knowledge.has("knowledge"): knowledge["knowledge"] = []
	knowledge["knowledge"].append({"q": q, "a": a})
	save_knowledge()

# إضافة حقيقة متعلمة
func add_fact(key: String, value: String, conf: float) -> bool:
	if not memory.has("learned_facts"): memory["learned_facts"] = []
	for f in memory["learned_facts"]:
		if f.get("key", "") == key and f.get("value", "") == value:
			return false
	memory["learned_facts"].append({"key": key, "value": value, "conf": conf})
	save_memory()
	return true

# سجل محادثة
func log_conv(u: String, a: String) -> void:
	if not memory.has("conversations"): memory["conversations"] = []
	memory["conversations"].append({"u": u, "a": a})
	if memory["conversations"].size() > 200:
		memory["conversations"] = memory["conversations"].slice(-200)
	save_memory()

# معلومات المستخدم
func set_user_name(n: String) -> void:
	user["name"] = n
	save_user()

func is_auto_learn() -> bool:
	return bool(user.get("auto_learn", true))

func set_auto_learn(v: bool) -> void:
	user["auto_learn"] = v
	save_user()

# اسم المساعد
func set_assistant_name(n: String) -> void:
	user["assistant_name"] = n
	save_user()

# تصفير كل شي (حذف كل شي وإعادة seed)
func reset_all() -> void:
	knowledge = _read(SEED)
	_write(KP, knowledge)
	memory = {"conversations": [], "learned_facts": []}
	_write(MP, memory)
	user["name"] = ""
	user["assistant_name"] = "عاقل"
	save_user()
