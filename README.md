ProbabilisticModeling.jl
========================

# Introduction

This package will eventually offer a DSL for probabilistic modeling that's built around Julia. Inspired by probabilistic programming languages like BUGS, the DSL supported by this package will allow users to articulate mathematical models in a purely descriptive fashion. The macros provided by this package will parse the model and generate code for a simple sampler that returns a DataFrame in which rows correspond to independent samples and columns correspond to independent columns.

An example of a model that gets compiled into a sampler:

	include("utils.jl")

	@generate_sampler begin
	    mu ~ Normal(0, 100)
	    sigma ~ Gamma(10, 1 / 10)
	    for i in 1:3
	        x[i] ~ Normal(mu, sigma)
	    end
	end

	sampler(4)

# To Do

* Expand the sublanguage accepted by `@generate_sampler`
* Implement `@fit_mle` and `@fit_map`
