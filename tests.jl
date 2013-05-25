include("utils.jl")

ex = quote
    mu ~ Normal(0, 100)
    sigma ~ Gamma(10, 1 / 10)
    for i in 1:10
        x[i] ~ Normal(mu, sigma)
    end
end

variables, dependencies, conditionals = parse_model(ex)

@assert contains(variables, :mu)
@assert contains(variables, :sigma)
@assert contains(variables, :x1)
@assert contains(variables, :x10)

@assert contains(dependencies, [:x1, :mu])
@assert contains(dependencies, [:x1, :sigma])
@assert contains(dependencies, [:x10, :mu])
@assert contains(dependencies, [:x10, :sigma])

@assert isequal(conditionals[:mu].dname, :Normal)
@assert isequal(conditionals[:mu].parameters[1], 0)
@assert isequal(conditionals[:mu].parameters[2], 100)

@assert isequal(conditionals[:sigma].dname, :Gamma)
@assert isequal(conditionals[:sigma].parameters[1], 10)
@assert isequal(eval(conditionals[:sigma].parameters[2]), 1 / 10)

@assert isequal(conditionals[:x1].dname, :Normal)
@assert isequal(conditionals[:x1].parameters[1], :mu)
@assert isequal(conditionals[:x1].parameters[2], :sigma)

index, inverse_index = build_indices(variables, dependencies)

@assert inverse_index[:mu] < inverse_index[:x1]
@assert inverse_index[:sigma] < inverse_index[:x1]
@assert inverse_index[:mu] < inverse_index[:x10]
@assert inverse_index[:sigma] < inverse_index[:x10]
