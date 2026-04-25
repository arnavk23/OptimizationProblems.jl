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

function _warning_problems()
  probs = Set{Symbol}()
  src_root = joinpath(@__DIR__, "..", "src")

  for subdir in ("ADNLPProblems", "PureJuMP")
    for file in readdir(joinpath(src_root, subdir))
      endswith(file, ".jl") || continue
      source = read(joinpath(src_root, subdir, file), String)
      occursin("@adjust_nvar_warn", source) || continue

      stem = Symbol(first(splitext(file)))
      if stem in list_problems
        push!(probs, stem)
      elseif startswith(String(stem), "dixmaan_")
        union!(probs, filter(prob -> startswith(String(prob), "dixmaan"), list_problems))
      end
    end
  end

  return sort!(collect(probs))
end

function _check_adjusted_warning(prob::Symbol, backend::Symbol)
  make_model(n) = let
    mod = backend === :ad ? ADNLPProblems :
          backend === :jump ? PureJuMP :
          error("Unknown backend $(backend) for $(prob)")
    model = getfield(mod, prob)(; n = n)
    backend === :jump ? MathOptNLPModel(model) : model
  end

  for n in (1, 2, 3, 4, 5, 9, 10, 26, 99, 100)
    nlp_probe = try
      make_model(n)
    catch
      continue
    end

    n_adj = nlp_probe.meta.nvar

    n_adj == n && continue

    msg_re = Regex("number of variables adjusted from $(n) to $(n_adj)")
    @test_logs (:warn, msg_re) make_model(n)
    @test_nowarn make_model(n_adj)
    return
  end

  @test false
end

@testset "Adjusted dimension warnings" begin
  probs = _warning_problems()
  @test !isempty(probs)

  for prob in probs
    isdefined(ADNLPProblems, prob) && _check_adjusted_warning(prob, :ad)
    isdefined(PureJuMP, prob) && _check_adjusted_warning(prob, :jump)
  end
end

@test setdiff(union(names(ADNLPProblems), list_problems_not_ADNLPProblems), list_problems) ==
      [:ADNLPProblems]
@test setdiff(union(names(PureJuMP), list_problems_not_PureJuMP), list_problems) == [:PureJuMP]
