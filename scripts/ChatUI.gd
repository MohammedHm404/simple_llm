# ChatUI.gd — الواجهة الرئيسية
extends Control

@onready var chat_log: RichTextLabel = $VBoxContainer/ChatLog
@onready var input: LineEdit = $VBoxContainer/InputRow/Input
@onready var send_btn: Button = $VBoxContainer/InputRow/SendBtn
@onready var status: Label = $VBoxContainer/Status

var brain: Brain

func _ready():
	brain = Brain.new()
	add_child(brain)
	brain.replied.connect(_on_reply)

	send_btn.pressed.connect(_send)
	input.text_submitted.connect(func(_t): _send())
	input.grab_focus()

	var n: String = brain.store.user.get("name", "")
	var hello := "أهلا بيك! أنا عاقل." if n == "" else "أهلا " + n + "!"
	_append("عاقل", hello)
	status.text = "جاهز ✅"

func _send():
	var t := input.text.strip_edges()
	if t == "": return
	_append("أنت", t)
	input.text = ""
	status.text = "يفكر..."
	brain.respond(t)
	status.text = "جاهز ✅"

func _on_reply(text: String):
	_append("عاقل", text)

func _append(speaker: String, text: String):
	var color := "ffffff"
	if speaker == "أنت": color = "88ccff"
	elif speaker == "عاقل": color = "aaffaa"
	chat_log.append_text("\n[b][color=#%s]%s:[/color][/b] %s" % [color, speaker, text])
