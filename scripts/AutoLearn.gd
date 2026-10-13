# AutoLearn.gd — استخراج الحقائق تلقائياً
extends RefCounted
class_name AutoLearn

const AFFIRM := ["ايه","ايوه","نعم","صح","صحيح","تمام","منيح","بالضبط","اي","yes","ok"]
const DENY := ["لا","غلط","مش","مو","خطا","خطاء","خطأ","no","wrong"]
const QUESTION_WORDS := ["ما","ماذا","شنو","شني","هل","كيف","من","وين","فين","اين","أين","متى","ليش","لماذا","كم","ايش","ماهي","ماهو","وش"]
const CONNECTORS := ["بل","لكن","بس","انما","إنما"]

static func is_question(msg: String) -> bool:
	var raw := msg.strip_edges()
	# إذا فيه "=" أو " هو " أو " هي " → تعليم مو سؤال
	if raw.find("=") != -1: return false
	if raw.find(" هو ") != -1 or raw.find(" هي ") != -1: return false
	if raw.find("؟") != -1 or raw.find("?") != -1: return true
	var n := Tokenizer.normalize(raw)
	for w in QUESTION_WORDS:
		var nw := Tokenizer.normalize(w)
		if n == nw or n.begins_with(nw + " "):
			return true
	return false

static func is_affirmation(msg: String) -> bool:
	var n := Tokenizer.normalize(msg)
	for w in AFFIRM:
		var nw := Tokenizer.normalize(w)
		if n == nw or n.begins_with(nw + " "):
			return true
	return false

static func is_denial(msg: String) -> bool:
	var n := Tokenizer.normalize(msg)
	for w in DENY:
		var nw := Tokenizer.normalize(w)
		if n == nw or n.begins_with(nw + " "):
			return true
	return false

# ابدأ النص بكلمة استفهام؟
static func _starts_with_question(text: String) -> bool:
	var n := Tokenizer.normalize(text)
	for w in QUESTION_WORDS:
		var nw := Tokenizer.normalize(w)
		if n == nw or n.begins_with(nw + " "):
			return true
	return false

# احذف كل "لا/بل/لكن/بس" من البداية
static func _strip_denial(msg: String) -> String:
	var parts := Array(msg.strip_edges().split(" ", false))
	while parts.size() > 0:
		var first := Tokenizer.normalize(parts[0])
		var is_deny := false
		for d in DENY:
			if Tokenizer.normalize(d) == first:
				is_deny = true
				break
		if not is_deny:
			for c in CONNECTORS:
				if Tokenizer.normalize(c) == first:
					is_deny = true
					break
		if is_deny:
			parts.pop_front()
		else:
			break
	return " ".join(parts)

static func extract_facts(msg: String) -> Array:
	var facts: Array = []
	# ما نستخرجش من سؤال (إلا إذا فيه "=")
	if is_question(msg) and msg.find("=") == -1:
		return facts

	var raw := _strip_denial(msg).strip_edges()

	# اسم المستخدم: "اسمي X"
	for m in ["اسمي ", "انا اسمي ", "أنا اسمي "]:
		var i := raw.find(m)
		if i != -1:
			var v := _cut(raw.substr(i + m.length()))
			if _ok(v, 30):
				facts.append({"key": "اسم المستخدم", "value": v, "conf": 0.95})

	# اسم المساعد: "اسمك X"
	for m in ["اسمك ", "انت اسمك ", "أنت اسمك "]:
		var i := raw.find(m)
		if i != -1:
			var v := _cut(raw.substr(i + m.length()))
			if _ok(v, 30):
				facts.append({"key": "اسم المساعد", "value": v, "conf": 0.95})

	# منطقة المستخدم
	for m in ["انا من ", "أنا من "]:
		var i := raw.find(m)
		if i != -1:
			var v := _cut(raw.substr(i + m.length()))
			if _ok(v, 30):
				facts.append({"key": "منطقة المستخدم", "value": v, "conf": 0.85})

	# تفضيلات
	for pr in [["احب ","يحب"],["أحب ","يحب"],["اكره ","يكره"],["أكره ","يكره"]]:
		var i := raw.find(pr[0])
		if i != -1:
			var v := _cut(raw.substr(i + pr[0].length()))
			if _ok(v, 40):
				facts.append({"key": pr[1], "value": v, "conf": 0.8})
			break

	# "X هو Y" / "X هي Y" / "X يعني Y"
	for m in [" هو ", " هي ", " يعني "]:
		var i := raw.find(m)
		if i > 0:
			var k := _cut(raw.substr(0, i))
			var v := _cut(raw.substr(i + m.length()))
			if _ok(k, 40) and _ok(v, 100) and not _starts_with_question(k):
				facts.append({"key": k, "value": v, "conf": 0.75})
			break

	# "X = Y"
	if raw.find("=") != -1:
		var p := raw.split("=", true, 1)
		if _ok(p[0].strip_edges(), 60) and _ok(p[1].strip_edges(), 100):
			facts.append({"key": p[0].strip_edges(), "value": p[1].strip_edges(), "conf": 0.9})

	return facts

static func is_correction(msg: String) -> bool:
	if not is_denial(msg): return false
	var n := Tokenizer.normalize(msg)
	return n.find(" هو ") != -1 or n.find(" هي ") != -1 or n.find(" يعني ") != -1 or msg.find("=") != -1

static func _cut(s: String) -> String:
	for p in [".", "،", ",", "!", "?", "؛", ";", ":", "\n"]:
		var i := s.find(p)
		if i != -1: s = s.substr(0, i)
	return s.strip_edges()

static func _ok(s: String, n: int) -> bool:
	return s.length() > 0 and s.length() <= n
