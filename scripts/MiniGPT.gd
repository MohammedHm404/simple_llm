# MiniGPT.gd — النموذج الكامل مع AdamW
class_name MiniGPT
extends RefCounted

var vocab_size
var d_model
var n_heads
var n_layers
var seq_len
var d_ff
var tok_emb
var pos_emb
var blocks
var ln_f
var head

var d_tok_emb
var d_pos_emb
var mtok
var vtok
var mpos
var vpos
var t_tok = 0
var t_pos = 0

const B1 = 0.9
const B2 = 0.999
const EPS = 1e-8
const WD = 0.01

var _tokens = []

func _init(vs, dm, nh, nl, sl):
	vocab_size = vs
	d_model = dm
	n_heads = nh
	n_layers = nl
	seq_len = sl
	d_ff = 4 * dm

	tok_emb = Mat.randn(vs, dm)
	pos_emb = Mat.randn(sl, dm)
	d_tok_emb = Mat.zeros(vs, dm)
	d_pos_emb = Mat.zeros(sl, dm)
	mtok = Mat.zeros(vs, dm)
	vtok = Mat.zeros(vs, dm)
	mpos = Mat.zeros(sl, dm)
	vpos = Mat.zeros(sl, dm)

	blocks = []
	for i in range(nl):
		blocks.append(NN.Block.new(dm, nh, d_ff))
	ln_f = NN.LayerNorm.new(dm)
	head = NN.Linear.new(dm, vs)

func forward(tokens):
	var n = tokens.size()
	var x = Mat.zeros(n, d_model)
	for i in range(n):
		var t = tokens[i]
		for j in range(d_model):
			x[i][j] = tok_emb[t][j] + pos_emb[i][j]
	var h = x
	for b in blocks:
		h = b.forward(h)
	h = ln_f.forward(h)
	var logits = head.forward(h)
	_tokens = tokens
	return logits

func backward(dlogits):
	var tokens = _tokens
	var dh = head.backward(dlogits)
	dh = ln_f.backward(dh)
	for i in range(blocks.size() - 1, -1, -1):
		dh = blocks[i].backward(dh)

	for i in range(vocab_size):
		for j in range(d_model):
			d_tok_emb[i][j] = 0.0
	for i in range(seq_len):
		for j in range(d_model):
			d_pos_emb[i][j] = 0.0
	for i in range(tokens.size()):
		var t = tokens[i]
		for j in range(d_model):
			d_tok_emb[t][j] += dh[i][j]
			d_pos_emb[i][j] += dh[i][j]

func step(lr):
	t_tok += 1
	t_pos += 1
	var bc1t = 1.0 - pow(B1, t_tok)
	var bc2t = 1.0 - pow(B2, t_tok)
	var bc1p = 1.0 - pow(B1, t_pos)
	var bc2p = 1.0 - pow(B2, t_pos)

	for i in range(vocab_size):
		for j in range(d_model):
			var g = d_tok_emb[i][j]
			mtok[i][j] = B1 * mtok[i][j] + (1.0 - B1) * g
			vtok[i][j] = B2 * vtok[i][j] + (1.0 - B2) * g * g
			var mh = mtok[i][j] / bc1t
			var vh = vtok[i][j] / bc2t
			tok_emb[i][j] -= lr * (mh / (sqrt(vh) + EPS) + WD * tok_emb[i][j])

	for i in range(seq_len):
		for j in range(d_model):
			var g = d_pos_emb[i][j]
			mpos[i][j] = B1 * mpos[i][j] + (1.0 - B1) * g
			vpos[i][j] = B2 * vpos[i][j] + (1.0 - B2) * g * g
			var mh = mpos[i][j] / bc1p
			var vh = vpos[i][j] / bc2p
			pos_emb[i][j] -= lr * (mh / (sqrt(vh) + EPS) + WD * pos_emb[i][j])

	for b in blocks:
		b.step(lr)
	ln_f.step(lr)
	head.step(lr)

func train_step(tokens, targets, lr):
	var logits = forward(tokens)
	var n = logits.size()
	var V = logits[0].size()
	var probs = Mat.softmax_rows(logits)
	var loss = 0.0
	var dlogits = Mat.zeros(n, V)
	for i in range(n):
		var t = targets[i]
		loss -= log(probs[i][t] + 1e-9)
		for j in range(V):
			dlogits[i][j] = probs[i][j] / n
		dlogits[i][t] -= 1.0 / n
	backward(dlogits)
	step(lr)
	return loss / n

func generate(chars, char_to_id, prompt, length, temperature = 0.8):
	var ids = []
	for c in prompt:
		if char_to_id.has(c):
			ids.append(char_to_id[c])
	if ids.size() == 0:
		ids = [0]
	if ids.size() > seq_len:
		ids = ids.slice(ids.size() - seq_len)
	var result = prompt
	for i in range(length):
		var ctx = ids.duplicate()
		if ctx.size() > seq_len:
			ctx = ctx.slice(ctx.size() - seq_len)
		var logits = forward(ctx)
		var last = logits[logits.size() - 1]
		var scaled = []
		scaled.resize(last.size())
		for j in range(last.size()):
			scaled[j] = last[j] / temperature
		var probs = Mat.softmax_rows([scaled])[0]
		var r = randf()
		var cum = 0.0
		var idx = 0
		for j in range(probs.size()):
			cum += probs[j]
			if cum > r:
				idx = j
				break
		ids.append(idx)
		if ids.size() > seq_len:
			ids = ids.slice(ids.size() - seq_len)
		result += chars[idx]
	return result
