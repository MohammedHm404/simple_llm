# Brain.gd — العقل
extends Node
class_name Brain

signal replied(text: String)

var store: DataStore
const THRESHOLD := 0.35


var _await_confirm := false
var _last_was_fallback := false

func _ready():
	store = DataStore.new()
	add_child(store)

func respond(input: String) -> String:
	var raw := input.strip_edges()
	if raw == "":
		return "اكتب حاجة."

	# 1) تأكيد / نفي
	if _await_confirm:
		if AutoLearn.is_affirmation(raw):
			_await_confirm = false
			return _finish(raw, "✅ راسخ.")
		elif AutoLearn.is_denial(raw) and not AutoLearn.is_correction(raw):
			_remove_last_knowledge()
			_await_confirm = false
			return _finish(raw, "🗑️ حذفت التعلم الأخير.")

	# 2) أوامر صريحة
	if raw.begins_with("/تعلم"):
		return _finish(raw, _teach(raw))
	if raw.begins_with("/اسمي"):
		var n := raw.replace("/اسمي", "").strip_edges()
		store.set_user_name(n)
		return _finish(raw, "تشرفنا يا " + n + "!")
	if raw.begins_with("/تصفير"):
		return _finish(raw, _reset())
	if raw.begins_with("/حذف"):
		return _finish(raw, _remove_last_knowledge_msg())
	if raw.begins_with("/تعلم_تلقائي"):
		var v := raw.replace("/تعلم_تلقائي", "").strip_edges().to_lower()
		var on := v == "on" or v == "1"
		store.set_auto_learn(on)
		return _finish(raw, "التعلم التلقائي: " + ("✅" if on else "⛔"))

	# 3) تصحيح
	if AutoLearn.is_correction(raw):
		var r := _correct(raw)
		if r != "":
			_await_confirm = true
			return _finish(raw, r + "\n(ايه / لا للتأكيد)")

	# 5) استخراج تلقائي (فقط للتعليم، مو الأسئلة)
	var notes := ""
	if store.is_auto_learn() and not AutoLearn.is_question(raw):
		notes = _extract(raw)

	# 6) الرد
	var reply := _generate(raw)
	var combined := reply if notes == "" else notes + "\n" + reply

	return _finish(raw, combined)

# ------- توليد الرد -------
func _generate(raw: String) -> String:
	_last_was_fallback = false

	# 1) النوايا
	var intents: Array = store.knowledge.get("intents", [])
	var bi := Matcher.best_intent(raw, intents)
	if bi["score"] >= 0.6:
		return _fill(_pick(bi["intent"]["responses"]))

	# 2) المعرفة العامة (knowledge)
	var kb: Array = store.knowledge.get("knowledge", [])
	var bk := Matcher.best_knowledge(raw, kb)
	if bk["score"] >= THRESHOLD:
		return str(bk["item"].get("a", ""))

	# 3) الحقائق المتعلمة
	var facts: Array = store.memory.get("learned_facts", [])
	var bf := Matcher.find_fact(raw, facts)
	if bf["score"] >= THRESHOLD:
		return str(bf["item"].get("value", ""))

	# 4) الدول (قبل المشاعر والـ fallback)
	var countries: Array = store.knowledge.get("world_countries", [])
	var q := Tokenizer.canonical(raw)
	for c in countries:
		var ar_name: String = c.get("ar", "")
		var en_name: String = str(c.get("en", "")).to_lower()
		var ar_c := Tokenizer.canonical(ar_name)

		# هل الرسالة تخص هذه الدولة؟
		var mentions: bool = q.find(ar_c) != -1 or q.find(en_name) != -1
		if not mentions:
			continue

		# 4.1) الموقع: "وين X" / "اين X"
		if q.find("اين") != -1:
			return ar_name + " تقع في " + str(c.get("location_ar", "")) + "."

		# 4.2) العاصمة: "عاصمة X" / "capital X"
		if q.find("عاصمه") != -1 or q.find("capital") != -1:
			return "عاصمة " + ar_name + " هي " + str(c.get("capital_ar", "")) + "."

		# 4.3) العملة
		if q.find("عمله") != -1 or q.find("currency") != -1:
			return "عملة " + ar_name + " هي " + str(c.get("currency_ar", "")) + "."

		# 4.4) السكان
		if q.find("سكان") != -1 or q.find("population") != -1:
			return "عدد سكان " + ar_name + " " + str(c.get("population", "")) + "."

		# 4.5) القارة
		if q.find("قاره") != -1 or q.find("continent") != -1:
			return ar_name + " في قارة " + str(c.get("continent_ar", "")) + "."

		# 4.6) سؤال عام عن الدولة → معلومات أساسية
		return "%s: العاصمة %s، القارة %s، العملة %s." % [
			ar_name,
			str(c.get("capital_ar", "")),
			str(c.get("continent_ar", "")),
			str(c.get("currency_ar", ""))
		]

	# 5) المشاعر
	var ems: Array = store.knowledge.get("emotions", [])
	var be := Matcher.best_emotion(raw, ems)
	if be["score"] > 0.0:
		return _pick(be["emotion"]["responses"])

	# 6) fallback
	_last_was_fallback = true
	return _pick([
		"مش فاهم بالضبط، وضّح لي أكثر.",
		"ما عندي جواب، اشرحلي أكثر.",
		"علّمني: /تعلم سؤال = جواب"
	])


# ------- تعلم تلقائي -------
func _extract(msg: String) -> String:
	var facts := AutoLearn.extract_facts(msg)
	if facts.is_empty(): return ""
	var saved: Array = []
	for f in facts:
		if float(f.get("conf", 0)) < 0.75: continue
		var k: String = f.get("key", "")
		var v: String = f.get("value", "")
		if store.add_fact(k, v, float(f.get("conf", 0.8))):
			saved.append("• " + k + " = " + v)
			if k == "اسم المستخدم":
				store.set_user_name(v)
			elif k == "اسم المساعد":
				store.set_assistant_name(v)
	return "" if saved.is_empty() else "📝 سجلت:\n" + "\n".join(saved)

# ------- تصحيح -------
func _correct(msg: String) -> String:
	var facts := AutoLearn.extract_facts(msg)
	if facts.is_empty(): return ""
	var saved: Array = []
	for f in facts:
		var k: String = f.get("key", "")
		var v: String = f.get("value", "")
		if k == "" or v == "": continue
		store.add_knowledge(k, v)
		saved.append("• " + k + " → " + v)
	return "" if saved.is_empty() else "✅ صححت:\n" + "\n".join(saved)

# ------- أوامر -------
func _teach(raw: String) -> String:
	var body := raw.replace("/تعلم", "").strip_edges()
	if body.find("=") == -1:
		return "الصيغة: /تعلم سؤال = جواب"
	var p := body.split("=", true, 1)
	var q := p[0].strip_edges()
	var a := p[1].strip_edges()
	if q == "" or a == "":
		return "الصيغة: /تعلم سؤال = جواب"
	store.add_knowledge(q, a)
	return "✅ تعلمت: " + q + " → " + a

func _reset() -> String:
	store.reset_all()
	return "🗑️ صفّرت كل شي (المعرفة + المحادثات + الحقائق)."

func _remove_last_knowledge() -> void:
	var kb: Array = store.knowledge.get("knowledge", [])
	if kb.size() > 0:
		kb.pop_back()
		store.save_knowledge()

func _remove_last_knowledge_msg() -> String:
	var kb: Array = store.knowledge.get("knowledge", [])
	if kb.size() == 0:
		return "ما فيه شي نحذفه."
	var last: Dictionary = kb[-1]
	_remove_last_knowledge()
	return "🗑️ حذفت: " + str(last.get("q", "")) + " → " + str(last.get("a", ""))

# ------- أدوات -------
func _finish(u: String, r: String) -> String:
	store.log_conv(u, r)
	replied.emit(r)
	return r

func _pick(arr: Array) -> String:
	return arr[randi() % arr.size()] if not arr.is_empty() else "..."

func _fill(t: String) -> String:
	var n: String = store.user.get("name", "")
	var an: String = store.user.get("assistant_name", "عاقل")
	t = t.replace("{name}", ("اسمك " + n + "." if n != "" else "ما قلتليش اسمك. اكتب: اسمي (اسمك)"))
	t = t.replace("{assistant_name}", an)
	t = t.replace("{time}", Time.get_time_string_from_system())
	t = t.replace("{date}", Time.get_date_string_from_system())
	return t
