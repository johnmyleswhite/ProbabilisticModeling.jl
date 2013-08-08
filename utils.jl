using DataFrames
using Distributions
using Graphs

type ConditionalSpecification
	dname::Symbol # Distribution name
	parameters::Vector # Parameters as constants or symbols
end

isblock(ex::Expr) = ex.head == :block
iscall(ex::Expr) = ex.head == :call
isforloop(ex::Expr) = ex.head == :for && ex.args[1].head == :(=)
isconditional(ex::Expr) = iscall(ex) && ex.args[1] != :(~)

function blocklines(ex::Expr)
	if !isblock(ex)
		error("Input is not a block")
	end
	return ex.args
end

function parse_conditional!(ex::Expr,
	                        vars::Vector,
	                        dependencies::Vector,
	                        nodes::Dict)
	if !isconditional(ex)
		error("Input is not a conditional")
	end

	varname, distspec = ex.args[2], ex.args[3]

	distname, params = distspec.args[1], distspec.args[2:end]

	# TODO: Remove this
	push!(vars, varname)

	for param in params
		if isa(param, Symbol)
			push!(dependencies, [varname, param])
		end
	end

	nodes[varname] = ConditionalSpecification(distname, params)

	return
end

function forloopbounds(ex::Expr)
	ex.args[2].args[1].args[2].args[1], ex.args[2].args[1].args[2].args[2]
end

function parse_forloop!(ex::Expr,
	                    vars::Vector,
	                    dependencies::Vector,
	                    nodes::Dict)

	if !isforloop(ex)
		error("Invalid for loop")
	end

	# Extract variable name and distribution from body of loop
	vname = ex.args[2].args[2].args[2].args[1]
	vdistspec = ex.args[2].args[2].args[3]
	dname = vdistspec.args[1]
	params = vdistspec.args[2:end]

	lower, upper = forloopbounds(ex)

	for index in lower:upper
		# Add variable
		new_vname = symbol(string(string(vname), index))
		push!(vars, new_vname)
		for param in params
			if isa(param, Symbol)
				push!(dependencies, [new_vname, param])
			end
		end
		nodes[new_vname] = ConditionalSpecification(dname, params)
	end

	return
end

function parse_model(ex::Expr)
	vars = Array(Symbol, 0) # TODO: Remove this?
	dependencies = Array(Vector{Symbol}, 0)
	nodes = Dict{Symbol, ConditionalSpecification}()

	if !isblock(ex)
		error("Invalid model specification")
	end

	# inner_ex => line
	for line in blocklines(ex)
		# Only process function calls and for loops
		if iscall(line)
			# TODO: Implement deterministic assignments
			if isconditional(line)
				parse_conditional!(line, vars, dependencies, nodes)
			else
				error("Invalid conditional distribution")
			end
		elseif isforloop(line)
			parse_forloop!(line, vars, dependencies, nodes)
		else
			continue
			# error("Invalid expression encountered")
		end
	end

	return vars, dependencies, nodes
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
	vars,
	dependencies,
	nodes = parse_model(model)

	index,
	inverse_index = build_indices(variables,
		                          dependencies)

    N = length(variables)

    codelines = Array(Expr, N)

    for i in 1:N
        vname = index[i]
        distr = nodes[vname]
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
