# NN.gd — الطبقات العصبية مع AdamW
class_name NN

# ================= Linear (AdamW) =================
class Linear:
	var W
	var b
	var dW
	var db
	var mW
	var vW
	var mb
	var vb
	var tW = 0
	var tb = 0
	var _x = []
	
	const B1 = 0.9
	const B2 = 0.999
	const EPS = 1e-8
	const WD = 0.01
	
	func _init(in_d, out_d):
		W = Mat.randn(in_d, out_d)
		b = []
		b.resize(out_d)
		b.fill(0.0)
		dW = Mat.zeros(in_d, out_d)
		db = []
		db.resize(out_d)
		db.fill(0.0)
		mW = Mat.zeros(in_d, out_d)
		vW = Mat.zeros(in_d, out_d)
		mb = []
		mb.resize(out_d)
		mb.fill(0.0)
		vb = []
		vb.resize(out_d)
		vb.fill(0.0)
	
	func forward(x):
		_x = x
		var y = Mat.matmul(x, W)
		for i in range(y.size()):
			for j in range(y[0].size()):
				y[i][j] += b[j]
		return y
	
	func backward(dy):
		dW = Mat.matmul_tn(_x, dy)
		for j in range(db.size()):
			var s = 0.0
			for i in range(dy.size()):
				s += dy[i][j]
			db[j] = s
		return Mat.matmul_nt(dy, W)
	
	func step(lr):
		tW += 1
		tb += 1
		var bc1W = 1.0 - pow(B1, tW)
		var bc2W = 1.0 - pow(B2, tW)
		var bc1b = 1.0 - pow(B1, tb)
		var bc2b = 1.0 - pow(B2, tb)
		for i in range(W.size()):
			for j in range(W[0].size()):
				var g = dW[i][j]
				mW[i][j] = B1 * mW[i][j] + (1.0 - B1) * g
				vW[i][j] = B2 * vW[i][j] + (1.0 - B2) * g * g
				var mh = mW[i][j] / bc1W
				var vh = vW[i][j] / bc2W
				W[i][j] -= lr * (mh / (sqrt(vh) + EPS) + WD * W[i][j])
		for j in range(b.size()):
			var g = db[j]
			mb[j] = B1 * mb[j] + (1.0 - B1) * g
			vb[j] = B2 * vb[j] + (1.0 - B2) * g * g
			var mh = mb[j] / bc1b
			var vh = vb[j] / bc2b
			b[j] -= lr * (mh / (sqrt(vh) + EPS) + WD * b[j])


# ================= LayerNorm (AdamW) =================
class LayerNorm:
	var g
	var be
	var dg
	var dbe
	var mg
	var vg
	var mbe
	var vbe
	var tg = 0
	var tbe = 0
	var _xhat = []
	var _std = []
	const EPS = 1e-5
	const B1 = 0.9
	const B2 = 0.999
	const A_EPS = 1e-8
	const WD = 0.01
	
	func _init(d):
		g = []
		g.resize(d)
		g.fill(1.0)
		be = []
		be.resize(d)
		be.fill(0.0)
		dg = []
		dg.resize(d)
		dg.fill(0.0)
		dbe = []
		dbe.resize(d)
		dbe.fill(0.0)
		mg = []
		mg.resize(d)
		mg.fill(0.0)
		vg = []
		vg.resize(d)
		vg.fill(0.0)
		mbe = []
		mbe.resize(d)
		mbe.fill(0.0)
		vbe = []
		vbe.resize(d)
		vbe.fill(0.0)
	
	func forward(x):
		var n = x.size()
		var d = x[0].size()
		var out = Mat.zeros(n, d)
		_xhat = Mat.zeros(n, d)
		_std = []
		_std.resize(n)
		for i in range(n):
			var mean = 0.0
			for j in range(d):
				mean += x[i][j]
			mean /= d
			var v = 0.0
			for j in range(d):
				var dv = x[i][j] - mean
				v += dv * dv
			v /= d
			var std = sqrt(v + EPS)
			_std[i] = std
			for j in range(d):
				_xhat[i][j] = (x[i][j] - mean) / std
				out[i][j] = _xhat[i][j] * g[j] + be[j]
		return out
	
	func backward(dy):
		var n = dy.size()
		var d = dy[0].size()
		for j in range(d):
			var sg = 0.0
			var sb = 0.0
			for i in range(n):
				sg += dy[i][j] * _xhat[i][j]
				sb += dy[i][j]
			dg[j] = sg
			dbe[j] = sb
		var dx = Mat.zeros(n, d)
		for i in range(n):
			var dxhat = []
			dxhat.resize(d)
			for j in range(d):
				dxhat[j] = dy[i][j] * g[j]
			var s1 = 0.0
			var s2 = 0.0
			for j in range(d):
				s1 += dxhat[j]
				s2 += dxhat[j] * _xhat[i][j]
			for j in range(d):
				dx[i][j] = (1.0 / _std[i]) * (dxhat[j] - s1 / d - _xhat[i][j] * s2 / d)
		return dx
	
	func step(lr):
		tg += 1
		tbe += 1
		var bc1g = 1.0 - pow(B1, tg)
		var bc2g = 1.0 - pow(B2, tg)
		var bc1b = 1.0 - pow(B1, tbe)
		var bc2b = 1.0 - pow(B2, tbe)
		for j in range(g.size()):
			var gr = dg[j]
			mg[j] = B1 * mg[j] + (1.0 - B1) * gr
			vg[j] = B2 * vg[j] + (1.0 - B2) * gr * gr
			var mh = mg[j] / bc1g
			var vh = vg[j] / bc2g
			g[j] -= lr * (mh / (sqrt(vh) + A_EPS) + WD * g[j])
			var gr2 = dbe[j]
			mbe[j] = B1 * mbe[j] + (1.0 - B1) * gr2
			vbe[j] = B2 * vbe[j] + (1.0 - B2) * gr2 * gr2
			var mh2 = mbe[j] / bc1b
			var vh2 = vbe[j] / bc2b
			be[j] -= lr * (mh2 / (sqrt(vh2) + A_EPS) + WD * be[j])


# ================= Multi-Head Attention =================
class Attention:
	var d_model
	var n_heads
	var d_head
	var Wq
	var Wk
	var Wv
	var Wo
	var _c = {}
	
	func _init(dm, nh):
		d_model = dm
		n_heads = nh
		d_head = dm / nh
		Wq = Linear.new(dm, dm)
		Wk = Linear.new(dm, dm)
		Wv = Linear.new(dm, dm)
		Wo = Linear.new(dm, dm)
	
	func forward(x):
		var n = x.size()
		var Q = Wq.forward(x)
		var K = Wk.forward(x)
		var V = Wv.forward(x)
		var attn_out = Mat.zeros(n, d_model)
		var all = []
		var scale = 1.0 / sqrt(d_head)
		for h in range(n_heads):
			var Qh = Mat.zeros(n, d_head)
			var Kh = Mat.zeros(n, d_head)
			var Vh = Mat.zeros(n, d_head)
			for i in range(n):
				for j in range(d_head):
					Qh[i][j] = Q[i][h * d_head + j]
					Kh[i][j] = K[i][h * d_head + j]
					Vh[i][j] = V[i][h * d_head + j]
			var sc = Mat.matmul_nt(Qh, Kh)
			for i in range(n):
				for j in range(n):
					sc[i][j] *= scale
					if j > i:
						sc[i][j] = -1e9
			var attn = Mat.softmax_rows(sc)
			var oh = Mat.matmul(attn, Vh)
			for i in range(n):
				for j in range(d_head):
					attn_out[i][h * d_head + j] = oh[i][j]
			all.append({"attn": attn, "Vh": Vh, "Qh": Qh, "Kh": Kh})
		var out = Wo.forward(attn_out)
		_c = {"Q": Q, "K": K, "V": V, "all": all, "n": n, "attn_out": attn_out, "scale": scale}
		return out
	
	func backward(dy):
		var n = _c["n"]
		var all = _c["all"]
		var scale = _c["scale"]
		var d_attn_out = Wo.backward(dy)
		var dQ = Mat.zeros(n, d_model)
		var dK = Mat.zeros(n, d_model)
		var dV = Mat.zeros(n, d_model)
		for h in range(n_heads):
			var ch = all[h]
			var attn = ch["attn"]
			var Vh = ch["Vh"]
			var Qh = ch["Qh"]
			var Kh = ch["Kh"]
			var doh = Mat.zeros(n, d_head)
			for i in range(n):
				for j in range(d_head):
					doh[i][j] = d_attn_out[i][h * d_head + j]
			var dVh = Mat.matmul(Mat.transpose(attn), doh)
			var d_attn = Mat.matmul_nt(doh, Vh)
			var d_sc = Mat.zeros(n, n)
			for i in range(n):
				var s = 0.0
				for j in range(n):
					s += d_attn[i][j] * attn[i][j]
				for j in range(n):
					d_sc[i][j] = attn[i][j] * (d_attn[i][j] - s) * scale
			var dQh = Mat.matmul(d_sc, Kh)
			var dKh = Mat.matmul(Mat.transpose(d_sc), Qh)
			for i in range(n):
				for j in range(d_head):
					dQ[i][h * d_head + j] = dQh[i][j]
					dK[i][h * d_head + j] = dKh[i][j]
					dV[i][h * d_head + j] = dVh[i][j]
		var dx_q = Wq.backward(dQ)
		var dx_k = Wk.backward(dK)
		var dx_v = Wv.backward(dV)
		var dx = Mat.zeros(n, d_model)
		for i in range(n):
			for j in range(d_model):
				dx[i][j] = dx_q[i][j] + dx_k[i][j] + dx_v[i][j]
		return dx
	
	func step(lr):
		Wq.step(lr)
		Wk.step(lr)
		Wv.step(lr)
		Wo.step(lr)


# ================= Feed-Forward =================
class FFN:
	var fc1
	var fc2
	var _h = []
	
	func _init(dm, dff):
		fc1 = Linear.new(dm, dff)
		fc2 = Linear.new(dff, dm)
	
	func _gelu(x):
		return 0.5 * x * (1.0 + tanh(0.7978845608 * (x + 0.044715 * x * x * x)))
	
	func _gelu_grad(x):
		var c = 0.7978845608
		var t = tanh(c * (x + 0.044715 * x * x * x))
		return 0.5 * (1.0 + t) + 0.5 * x * (1.0 - t * t) * c * (1.0 + 3.0 * 0.044715 * x * x)
	
	func forward(x):
		var h = fc1.forward(x)
		var a = Mat.zeros(h.size(), h[0].size())
		for i in range(h.size()):
			for j in range(h[0].size()):
				a[i][j] = _gelu(h[i][j])
		_h = h
		return fc2.forward(a)
	
	func backward(dy):
		var da = fc2.backward(dy)
		var dh = Mat.zeros(da.size(), da[0].size())
		for i in range(da.size()):
			for j in range(da[0].size()):
				dh[i][j] = da[i][j] * _gelu_grad(_h[i][j])
		return fc1.backward(dh)
	
	func step(lr):
		fc1.step(lr)
		fc2.step(lr)


# ================= Transformer Block =================
class Block:
	var ln1
	var attn
	var ln2
	var ffn
	
	func _init(dm, nh, dff):
		ln1 = LayerNorm.new(dm)
		attn = Attention.new(dm, nh)
		ln2 = LayerNorm.new(dm)
		ffn = FFN.new(dm, dff)
	
	func forward(x):
		var h1 = ln1.forward(x)
		var a = attn.forward(h1)
		var r1 = Mat.add(x, a)
		var h2 = ln2.forward(r1)
		var f = ffn.forward(h2)
		return Mat.add(r1, f)
	
	func backward(dy):
		var dh2 = ffn.backward(dy)
		var dr1_from_ln2 = ln2.backward(dh2)
		var dr1 = Mat.add(dy, dr1_from_ln2)
		var dh1 = attn.backward(dr1)
		var dx_from_attn = ln1.backward(dh1)
		return Mat.add(dr1, dx_from_attn)
	
	func step(lr):
		ln1.step(lr)
		attn.step(lr)
		ln2.step(lr)
		ffn.step(lr)
