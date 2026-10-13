# Matcher.gd — اختيار أفضل تطابق
extends Node
class_name Matcher


# حساب فرق الحروف بين كلمتين
static func _levenshtein(a: String, b: String) -> int:
	var la := a.length()
	var lb := b.length()
	if la == 0: return lb
	if lb == 0: return la
	var prev: Array[int] = []
	prev.resize(lb + 1)
	for j in range(lb + 1): prev[j] = j
	for i in range(1, la + 1):
		var cur: Array[int] = []
		cur.resize(lb + 1)
		cur[0] = i
		for j in range(1, lb + 1):
			var cost := 0 if a[i-1] == b[j-1] else 1
			cur[j] = mini(mini(cur[j-1] + 1, prev[j] + 1), prev[j-1] + cost)
		prev = cur
	return prev[lb]


# مطابقة صارمة: لازم كلمتان على الأقل (إلا إذا النمط كلمة واحدة)
static func _match(input: String, pattern: String) -> Dictionary:
	var p := Tokenizer.tokens_canonical(pattern)
	var i := Tokenizer.tokens_canonical(input)
	if p.size() == 0:
		return {"ok": false, "score": 0.0}
	var hits := 0
	for pw in p:
		for iw in i:
			if pw == iw:
				hits += 1
				break
			# تسامح: كلمة ≥ 3 حروف وفرق ≤ 1
			if pw.length() >= 3 and absi(pw.length() - iw.length()) <= 1:
				if _levenshtein(pw, iw) <= 1:
					hits += 1
					break
	var min_hits: int = mini(2, p.size())
	if hits < min_hits:
		return {"ok": false, "score": 0.0}
	return {"ok": true, "score": float(hits) / float(p.size())}

static func best_knowledge(input: String, kb: Array) -> Dictionary:
	var best := {"score": 0.0, "item": {}}
	for item in kb:
		var m := _match(input, item.get("q", ""))
		if m["ok"] and m["score"] > best["score"]:
			best = {"score": m["score"], "item": item}
	return best

static func best_intent(input: String, intents: Array) -> Dictionary:
	var best := {"score": 0.0, "intent": {}}
	for it in intents:
		for p in it.get("patterns", []):
			var s := Tokenizer.overlap(p, input)
			if s > best["score"]:
				best = {"score": s, "intent": it}
	return best

static func best_emotion(input: String, emotions: Array) -> Dictionary:
	var best := {"score": 0.0, "emotion": {}}
	var n := Tokenizer.canonical(input)
	for em in emotions:
		var hits := 0
		var kws: Array = em.get("keywords", [])
		for kw in kws:
			if n.find(Tokenizer.canonical(kw)) != -1:
				hits += 1
		if hits > 0:
			var s := float(hits) / float(maxi(1, kws.size()))
			if s > best["score"]:
				best = {"score": s, "emotion": em}
	return best

static func find_fact(input: String, facts: Array) -> Dictionary:
	var best := {"score": 0.0, "item": {}}
	for f in facts:
		var m := _match(input, f.get("key", ""))
		if m["ok"] and m["score"] > best["score"]:
			best = {"score": m["score"], "item": f}
	return best
