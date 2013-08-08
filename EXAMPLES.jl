@model begin
	mu ~ Normal(0, 1)
	sigma ~ Gamma(1, 1)
	for i in 1:N
		x[i] ~ Normal(mu, sigma)
	end
end

@model begin
	a ~ Normal(0, 1)
	b ~ Normal(0, 1)
	sigma ~ Gamma(1, 1)
	for i in 1:N
		y[i] ~ Normal(a + b * x[i], sigma)
	end
end

@model begin
	for d in 1:K
		for i in 1:N_U
			U[d, i] ~ Normal(0, 1)
		end
	end
	for d in 1:K
		for j in 1:N_P
			P[d, j] ~ Normal(0, 1)
		end
	end
	for i in 1:N_U
		for j in 1:N_P
			R[i, j] ~ Normal(dot(U[:, i], P[:, j]))
		end
	end
end

@model begin
	for i in 1:M
		theta[:, i] ~ Dirichlet(alpha)
		for j in 1:N
			z[i, j] ~ Categorical(theta[:, i])
			w[i, j] ~ Categorical(phi[:, z[i, j]])
		end
	end
	for k in 1:K
		phi[:, k] ~ Dirichlet(beta)
	end
end
