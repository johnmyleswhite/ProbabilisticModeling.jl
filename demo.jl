include("utils.jl")

@generate_sampler begin
    mu ~ Normal(0, 100)
    sigma ~ Gamma(10, 1 / 10)
    for i in 1:3
        x[i] ~ Normal(mu, sigma)
    end
end

sampler(4)
