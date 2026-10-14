# Main.gd — الواجهة
extends Control

@onready var log_view: RichTextLabel = $VBox/Log
@onready var input: LineEdit = $VBox/InputRow/Input
@onready var train_btn: Button = $VBox/InputRow/TrainBtn
@onready var gen_btn: Button = $VBox/InputRow/GenBtn
@onready var status: Label = $VBox/Status

var chars = []
var char_to_id = {}
var data = []
var model
var training = false
var step_count = 0
var last_loss = 0.0

const TRAIN_TEXT = """في قديم الزمان كان هناك ملك عادل يحكم مدينة جميلة على ضفاف النهر.
كان الملك يحب شعبه ويحكم بالعدل، وكان الناس يعيشون في سلام ورخاء.
وفي يوم من الأيام جاء رجل حكيم إلى المدينة وقال للملك: يا أيها الملك،
إن الحكمة كنز لا يفنى، والمعرفة نور يضيء طريق الحياة.
فقال الملك: صدقت أيها الحكيم، فالحكمة أفضل من الذهب والفضة.
ومنذ ذلك اليوم أصبح الملك يستشير الحكماء في كل أمر من أمور المملكة.
وعاشت المدينة في سلام ورخاء، وذاع صيت الملك العادل في كل البلدان.
وفي يوم آخر جاء تاجر غني إلى المدينة يحمل بضائع من كل مكان.
فقال التاجر: يا أيها الملك، جئتك من بلاد بعيدة لأرى بعيني عدلك وحكمتك.
فقال الملك: مرحباً بك، فالمدينة مفتوحة لكل من يريد الخير والسلام.
وعاش التاجر في المدينة وأصبح من أهلها، وتعلم من حكمة الملك الكثير.
وهكذا بقيت المدينة رمزاً للعدل والحكمة عبر السنين والأجيال.
"""

func _ready():
	_build_tokenizer()
	_build_data()
	_init_model()
	train_btn.pressed.connect(_toggle_train)
	gen_btn.pressed.connect(_generate)
	input.text_submitted.connect(func(_t): _generate())
	_append_log("📚 المفردات: " + str(chars.size()) + " حرف")
	_append_log("📊 البيانات: " + str(data.size()) + " رمز")
	_append_log("🧠 النموذج: dim=" + str(model.d_model) + ", heads=" + str(model.n_heads) + ", layers=" + str(model.n_layers) + ", seq=" + str(model.seq_len))
	_append_log("━━━━━━━━━━━━━━━━━━━━━━━━")
	_append_log("اكتب نصاً واضغط 'توليد'، أو ابدأ التدريب أولاً")
	status.text = "جاهز"

func _build_tokenizer():
	var seen = {}
	for c in TRAIN_TEXT:
		if not seen.has(c):
			seen[c] = true
			chars.append(c)
	chars.sort()
	for i in range(chars.size()):
		char_to_id[chars[i]] = i

func _build_data():
	for c in TRAIN_TEXT:
		data.append(char_to_id[c])

func _init_model():
	var vs = chars.size()
	model = MiniGPT.new(vs, 64, 4, 2, 32)

func _toggle_train():
	training = not training
	train_btn.text = "⏹ إيقاف" if training else "▶ تدريب"
	if training:
		status.text = "يتدرب..."
	else:
		status.text = "متوقف"

func _process(_dt):
	if not training: return
	var sl = model.seq_len
	if data.size() < sl + 1: return
	var max_start = data.size() - sl - 1
	var start = randi() % max_start
	var tokens = []
	var targets = []
	for i in range(sl):
		tokens.append(data[start + i])
		targets.append(data[start + i + 1])

	var lr = 0.001
	if step_count > 2000: lr = 0.0005
	if step_count > 5000: lr = 0.0001

	last_loss = model.train_step(tokens, targets, lr)
	step_count += 1

	if step_count % 25 == 0:
		_append_log("الخطوة " + str(step_count) + " | خسارة: " + "%.3f" % last_loss + " | lr: " + str(lr))
	status.text = "خطوة " + str(step_count) + " | خسارة " + "%.3f" % last_loss

func _generate():
	var prompt = input.text.strip_edges()
	if prompt == "":
		prompt = "في"
	var result = model.generate(chars, char_to_id, prompt, 200, 0.8)
	_append_log("━━━━━ توليد ━━━━━")
	_append_log(result)
	_append_log("━━━━━━━━━━━━━━━━━")

func _append_log(text: String):
	log_view.append_text("\n" + text)
	log_view.scroll_to_line(log_view.get_line_count())
