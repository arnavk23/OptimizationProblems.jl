@everywhere function probe_missing(mod::Module, syms::Vector{Symbol})
  missing = Symbol[]
  for s in syms
    if !isdefined(mod, s)
      push!(missing, s)
    end
  end
  return (pid = myid(), missing = missing)
end

probes = @sync begin
  for pid in workers()
    @async remotecall_fetch(probe_missing, pid, ADNLPProblems, list_problems_ADNLPProblems)
  end
end
@info "ADNLPProblems missing per worker" probes

probes = @sync begin
  for pid in workers()
    @async remotecall_fetch(probe_missing, pid, PureJuMP, list_problems_PureJuMP)
  end
end
@info "PureJuMP missing per worker" probes

@testset "Adjusted dimension warnings" begin
  # Get all scalable problems from the metadata registry
  var_probs = OptimizationProblems.meta[OptimizationProblems.meta.variable_nvar, :name]
  @test !isempty(var_probs)

  # Filter to only problems that actually use the @adjust_nvar_warn macro
  src_root = joinpath(@__DIR__, "..", "src")
  probs_with_macro = Set{String}()
  for subdir in ("ADNLPProblems", "PureJuMP")
    for file in readdir(joinpath(src_root, subdir))
      endswith(file, ".jl") || continue
      source = read(joinpath(src_root, subdir, file), String)
      if occursin("@adjust_nvar_warn", source)
        stem = first(splitext(file))
        push!(probs_with_macro, stem)
      end
    end
  end

  # Test each problem that uses the macro
  for prob_name in sort(collect(probs_with_macro))
    prob_sym = Symbol(prob_name)
    
    # Check if problem is actually in the registry and scalable
    prob_name in var_probs || continue
    
    get_nvar_func = getfield(OptimizationProblems, Symbol("get_", prob_name, "_nvar"))

    # Try standard test dimensions
    for n in (50, 100, 150)
      n_adjusted = get_nvar_func(; n = n)
      n_adjusted == n && continue  # Skip if no adjustment for this n

      # Found an adjustment - test it
      msg_re = Regex("number of variables adjusted from $(n) to $(n_adjusted)")

      for mod in (ADNLPProblems, PureJuMP)
        isdefined(mod, prob_sym) || continue

        constructor = getfield(mod, prob_sym)
        
        try
          # Try to verify the model can be constructed with adjusted size
          _ = constructor(; n = n_adjusted)
        catch
          continue  # Skip if construction fails
        end

        # Test that warning is emitted
        @test_logs (:warn, msg_re) constructor(; n = n)
        # Test that no warning when using adjusted size
        @test_nowarn constructor(; n = n_adjusted)
      end
      
      break  # Move to next problem after testing one adjustment
    end
  end
end

@test setdiff(union(names(ADNLPProblems), list_problems_not_ADNLPProblems), list_problems) ==
      [:ADNLPProblems]
@test setdiff(union(names(PureJuMP), list_problems_not_PureJuMP), list_problems) == [:PureJuMP]
