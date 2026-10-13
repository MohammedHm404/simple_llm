# Tokenizer.gd — تطبيع النص ومقارنة الكلمات
extends Node
class_name Tokenizer

# كلمات زايدة (ما تأثر في المعنى)
const STOPWORDS := ["هي", "هو", "بل", "لكن", "فقط", "بس", "إن", "ان", "أن"]

# مرادفات: نطبّعها لصيغة واحدة
const SYNONYMS := {
	"وين": "اين", "فين": "اين", "أين": "اين",
	"شنو": "ما", "شني": "ما", "ايش": "ما", "وش": "ما", "ماذا": "ما",
	"ازيك": "كيف حالك", "شلونك": "كيف حالك", "كيفك": "كيف حالك",
	"لاباس": "كيف حالك", "كي داير": "كيف حالك",
	"دلوقتي": "الان", "هلق": "الان", "دابا": "الان", "توا": "الان",
	"بزاف": "كثير", "كتير": "كثير", "وايد": "كثير",
	"هكي": "هكذا", "هيك": "هكذا", "كده": "هكذا", "چذي": "هكذا"
}

# تطبيع: تشكيل + ترقيم + توحيد حروف
static func normalize(text: String) -> String:
	text = text.to_lower()
	for d in ["َ","ً","ُ","ٌ","ِ","ٍ","ْ","ّ"]:
		text = text.replace(d, "")
	text = text.replace("أ","ا").replace("إ","ا").replace("آ","ا")
	text = text.replace("ى","ي").replace("ئ","ي").replace("ؤ","و")
	text = text.replace("ة","ه")
	for p in ["!","?",".",",",";",":","،","؛","؟","\"","'","(",")","[","]","-","_","/","\\"]:
		text = text.replace(p, " ")
	while text.find("  ") != -1:
		text = text.replace("  ", " ")
	return text.strip_edges()

# التطبيع الكامل: normalize + مرادفات + حذف كلمات زايدة
static func canonical(text: String) -> String:
	var parts := Array(normalize(text).split(" ", false))
	var out: Array = []
	for w in parts:
		# استبدل المرادفات
		var nw: String = w
		if SYNONYMS.has(w):
			nw = SYNONYMS[w]
		# تجاهل الكلمات الزايدة
		if nw in STOPWORDS:
			continue
		out.append(nw)
	return " ".join(out)

# كلمات عادية (بدون تطبيع كامل)
static func tokens(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for w in normalize(text).split(" ", false):
		if w.length() > 0:
			out.append(w)
	return out

# كلمات مطبّعة (مع مرادفات وحذف)
static func tokens_canonical(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for w in canonical(text).split(" ", false):
		if w.length() > 0:
			out.append(w)
	return out

# نسبة تطابق canonical
static func overlap(pattern: String, input: String) -> float:
	var p := tokens_canonical(pattern)
	if p.size() == 0:
		return 0.0
	var set_i := {}
	for w in tokens_canonical(input):
		set_i[w] = true
	var hits := 0
	for w in p:
		if set_i.has(w):
			hits += 1
	return float(hits) / float(p.size())
