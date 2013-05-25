using DataFrames
using Distributions
using Graphs

type ConditionalSpecification
	dname::Symbol # Distribution name
	parameters::Vector # Parameters as constants or symbols
end

function parse_model(ex::Expr)
	variables = Array(Symbol, 0)
	dependencies = Array(Vector{Symbol}, 0)
	conditionals = Dict{Symbol, ConditionalSpecification}()

	if ex.head != :block
		error("Invalid model specification")
	end

	for inner_ex in ex.args
		if inner_ex.head != :call && inner_ex.head != :for
			continue
		end

		if inner_ex.head == :call
			if inner_ex.args[1] != :~
				error("Invalid conditional distribution")
			end

			vname = inner_ex.args[2]
			vdistspec = inner_ex.args[3]
			dname = vdistspec.args[1]
			params = vdistspec.args[2:end]

			push!(variables, vname)

			for param in params
				if isa(param, Symbol)
					push!(dependencies, [vname, param])
				end
			end

			conditionals[vname] =
			  ConditionalSpecification(dname, params)
		else
			if inner_ex.args[1].head != :(=)
				error("Invalid for loop")
			end

			# Extract variable name and distribution from body of loop
			vname = inner_ex.args[2].args[2].args[2].args[1]
			vdistspec = inner_ex.args[2].args[2].args[3]
			dname = vdistspec.args[1]
			params = vdistspec.args[2:end]

			for index in 1:inner_ex.args[1].args[2].args[2]
				# Add variable
				new_vname = symbol(string(string(vname), index))
				push!(variables, new_vname)
				for param in params
					if isa(param, Symbol)
						push!(dependencies, [new_vname, param])
					end
				end
				conditionals[new_vname] =
				  ConditionalSpecification(dname, params)
			end
		end
	end

	return variables, dependencies, conditionals
end

# (1) Integer => Variables
#   Get from sorting variables topologically
# (2) Variables => Integers
#   Get from dependencies
# (3) Conditionals
#

function build_indices(variables::Vector,
	                   dependencies::Vector)
	inverse_index = Dict{Symbol, Int}()

	for i in 1:length(variables)
		inverse_index[variables[i]] = i
	end

	g = simple_graph(length(variables))

	for dependency in dependencies
		add_edge!(g,
			      inverse_index[dependency[2]],
			      inverse_index[dependency[1]])
	end

	sorted_variables = topological_sort_by_dfs(g)

	index = variables[sorted_variables]

	for i in 1:length(index)
		inverse_index[index[i]] = i
	end

	return index, inverse_index
end

macro generate_sampler(model)
	variables,
	dependencies,
	conditionals = parse_model(model)

	index,
	inverse_index = build_indices(variables,
		                          dependencies)

    N = length(variables)

    codelines = Array(Expr, N)

    for i in 1:N
        vname = index[i]
        distr = conditionals[vname]
        params = Array(Any, length(distr.parameters))
        for j in 1:length(params)
            v = distr.parameters[j]
            if isa(v, Symbol)
                params[j] = Expr(:ref,
                                 :res,
                                 :s,
                                 inverse_index[v])
            else
                params[j] = v
            end
        end
        ex = Expr(:(=),
                  Expr(:ref, :res, :s, i),
                  Expr(:call,
                       :rand,
                       Expr(:call,
                            distr.dname,
                            params...)))
        codelines[i] = ex
    end

    inner_loop = Expr(:block, codelines...)

    ex = quote
    	function sampler(nsamples::Integer)
			res = Array(Float64, nsamples, $N)
			for s = 1:nsamples
				$inner_loop
			end
			return DataFrame(res, map(string, $index))
		end
	end

	# Why does this seem to be needed?
	eval(ex)
end
