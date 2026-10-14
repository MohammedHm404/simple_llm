# Math.gd — عمليات المصفوفات
class_name Mat

static func zeros(r, c):
	var m = []
	for i in range(r):
		var row = []
		row.resize(c)
		row.fill(0.0)
		m.append(row)
	return m

static func randn(r, c, s = 0.02):
	var m = []
	for i in range(r):
		var row = []
		for j in range(c):
			var u1 = maxf(randf(), 1e-9)
			row.append(sqrt(-2.0 * log(u1)) * cos(TAU * randf()) * s)
		m.append(row)
	return m

static func matmul(A, B):
	var M = A.size()
	var K = A[0].size()
	var N = B[0].size()
	var C = zeros(M, N)
	for i in range(M):
		var Ai = A[i]
		var Ci = C[i]
		for k in range(K):
			var a = Ai[k]
			if a == 0.0: continue
			var Bk = B[k]
			for j in range(N):
				Ci[j] += a * Bk[j]
	return C

static func matmul_tn(A, B):
	var K = A.size()
	var M = A[0].size()
	var N = B[0].size()
	var C = zeros(M, N)
	for k in range(K):
		var Ak = A[k]
		var Bk = B[k]
		for i in range(M):
			var a = Ak[i]
			if a == 0.0: continue
			var Ci = C[i]
			for j in range(N):
				Ci[j] += a * Bk[j]
	return C

static func matmul_nt(A, B):
	var M = A.size()
	var K = A[0].size()
	var N = B.size()
	var C = zeros(M, N)
	for i in range(M):
		var Ai = A[i]
		var Ci = C[i]
		for j in range(N):
			var Bj = B[j]
			var s = 0.0
			for k in range(K):
				s += Ai[k] * Bj[k]
			Ci[j] = s
	return C

static func add(A, B):
	var M = A.size()
	var N = A[0].size()
	var C = zeros(M, N)
	for i in range(M):
		for j in range(N):
			C[i][j] = A[i][j] + B[i][j]
	return C

static func transpose(A):
	var M = A.size()
	var N = A[0].size()
	var B = zeros(N, M)
	for i in range(M):
		for j in range(N):
			B[j][i] = A[i][j]
	return B

static func softmax_rows(X):
	var M = X.size()
	var N = X[0].size()
	var Y = zeros(M, N)
	for i in range(M):
		var mx = X[i][0]
		for j in range(N):
			if X[i][j] > mx: mx = X[i][j]
		var s = 0.0
		for j in range(N):
			Y[i][j] = exp(X[i][j] - mx)
			s += Y[i][j]
		for j in range(N):
			Y[i][j] /= s
	return Y
