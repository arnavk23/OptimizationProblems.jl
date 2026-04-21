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

function _check_adjusted_warning(ctor::Function, expected_msg::AbstractString, expected_nvar::Integer)
  nlp = @test_logs (:warn, expected_msg) ctor()
  @test nlp.meta.nvar == expected_nvar
end

function _check_adjusted_warning(expected_msg::AbstractString, expected_nvar::Integer, ctor::Function)
  _check_adjusted_warning(ctor, expected_msg, expected_nvar)
end

@testset "Adjusted dimension warnings" begin
  warning_cases = [
    (; msg = "NZF1: number of variables adjusted from 1 to 26", nvar = 26, ctor = () -> ADNLPProblems.NZF1(n = 1)),
    (; msg = "NZF1: number of variables adjusted from 1 to 26", nvar = 26, ctor = () -> MathOptNLPModel(PureJuMP.NZF1(n = 1))),
    (; msg = "spmsrtls: number of variables adjusted from 99 to 100", nvar = 100, ctor = () -> ADNLPProblems.spmsrtls(n = 99)),
    (; msg = "spmsrtls: number of variables adjusted from 99 to 100", nvar = 100, ctor = () -> MathOptNLPModel(PureJuMP.spmsrtls(n = 99))),
    (; msg = "chainwoo: number of variables adjusted from 1 to 4", nvar = 4, ctor = () -> ADNLPProblems.chainwoo(n = 1)),
    (; msg = "chainwoo: number of variables adjusted from 1 to 4", nvar = 4, ctor = () -> MathOptNLPModel(PureJuMP.chainwoo(n = 1))),
    (; msg = "catenary: number of variables adjusted from 10 to 9", nvar = 9, ctor = () -> ADNLPProblems.catenary(n = 10)),
    (; msg = "catenary: number of variables adjusted from 10 to 9", nvar = 9, ctor = () -> MathOptNLPModel(PureJuMP.catenary(n = 10))),
    (; msg = "clplatea: number of variables adjusted from 5 to 9", nvar = 9, ctor = () -> ADNLPProblems.clplatea(n = 5)),
    (; msg = "clplatea: number of variables adjusted from 5 to 4", nvar = 4, ctor = () -> MathOptNLPModel(PureJuMP.clplatea(n = 5))),
    (; msg = "clplateb: number of variables adjusted from 5 to 9", nvar = 9, ctor = () -> ADNLPProblems.clplateb(n = 5)),
    (; msg = "clplateb: number of variables adjusted from 5 to 4", nvar = 4, ctor = () -> MathOptNLPModel(PureJuMP.clplateb(n = 5))),
    (; msg = "clplatec: number of variables adjusted from 5 to 9", nvar = 9, ctor = () -> ADNLPProblems.clplatec(n = 5)),
    (; msg = "clplatec: number of variables adjusted from 5 to 4", nvar = 4, ctor = () -> MathOptNLPModel(PureJuMP.clplatec(n = 5))),
    (; msg = "fminsrf2: number of variables adjusted from 1 to 4", nvar = 4, ctor = () -> ADNLPProblems.fminsrf2(n = 1)),
    (; msg = "fminsrf2: number of variables adjusted from 1 to 4", nvar = 4, ctor = () -> MathOptNLPModel(PureJuMP.fminsrf2(n = 1))),
    (; msg = "powellsg: number of variables adjusted from 1 to 4", nvar = 4, ctor = () -> ADNLPProblems.powellsg(n = 1)),
    (; msg = "powellsg: number of variables adjusted from 1 to 4", nvar = 4, ctor = () -> ADNLPProblems.powellsg(use_nls = true, n = 1)),
    (; msg = "powellsg: number of variables adjusted from 1 to 4", nvar = 4, ctor = () -> MathOptNLPModel(PureJuMP.powellsg(n = 1))),
    (; msg = "powellsg: number of variables adjusted from 1 to 4", nvar = 4, ctor = () -> MathOptNLPModel(PureJuMP.powellsg(use_nls = true, n = 1))),
    (; msg = "srosenbr: number of variables adjusted from 1 to 2", nvar = 2, ctor = () -> ADNLPProblems.srosenbr(n = 1)),
    (; msg = "srosenbr: number of variables adjusted from 1 to 2", nvar = 2, ctor = () -> MathOptNLPModel(PureJuMP.srosenbr(n = 1))),
    (; msg = "watson: number of variables adjusted from 1 to 2", nvar = 2, ctor = () -> ADNLPProblems.watson(n = 1)),
    (; msg = "watson: number of variables adjusted from 1 to 2", nvar = 2, ctor = () -> ADNLPProblems.watson(use_nls = true, n = 1)),
    (; msg = "watson: number of variables adjusted from 1 to 2", nvar = 2, ctor = () -> MathOptNLPModel(PureJuMP.watson(n = 1))),
    (; msg = "woods: number of variables adjusted from 1 to 4", nvar = 4, ctor = () -> ADNLPProblems.woods(n = 1)),
    (; msg = "woods: number of variables adjusted from 1 to 4", nvar = 4, ctor = () -> MathOptNLPModel(PureJuMP.woods(n = 1))),
    (; msg = "bearing: number of variables adjusted from 1 to 9", nvar = 9, ctor = () -> ADNLPProblems.bearing(n = 1)),
    (; msg = "bearing: number of variables adjusted from 1 to 9", nvar = 9, ctor = () -> MathOptNLPModel(PureJuMP.bearing(n = 1))),
    (; msg = "broydn7d: number of variables adjusted from 5 to 4", nvar = 4, ctor = () -> ADNLPProblems.broydn7d(n = 5)),
    (; msg = "broydn7d: number of variables adjusted from 5 to 4", nvar = 4, ctor = () -> MathOptNLPModel(PureJuMP.broydn7d(n = 5))),
    (; msg = "dixmaan: number of variables adjusted from 1 to 3", nvar = 3, ctor = () -> ADNLPProblems.dixmaane(n = 1)),
    (; msg = "dixmaan: number of variables adjusted from 1 to 3", nvar = 3, ctor = () -> MathOptNLPModel(PureJuMP.dixmaane(n = 1))),
    (; msg = "dixmaan: number of variables adjusted from 1 to 3", nvar = 3, ctor = () -> ADNLPProblems.dixmaani(n = 1)),
    (; msg = "dixmaan: number of variables adjusted from 1 to 3", nvar = 3, ctor = () -> MathOptNLPModel(PureJuMP.dixmaani(n = 1))),
    (; msg = "dixmaan: number of variables adjusted from 1 to 3", nvar = 3, ctor = () -> ADNLPProblems.dixmaanm(n = 1)),
    (; msg = "dixmaan: number of variables adjusted from 1 to 3", nvar = 3, ctor = () -> MathOptNLPModel(PureJuMP.dixmaanm(n = 1))),
    (; msg = "spmsrtls: number of variables adjusted from 99 to 100", nvar = 100, ctor = () -> ADNLPProblems.spmsrtls(use_nls = true, n = 99)),
    (; msg = "NZF1: number of variables adjusted from 1 to 26", nvar = 26, ctor = () -> ADNLPProblems.NZF1(use_nls = true, n = 1)),
  ]

  for case in warning_cases
    _check_adjusted_warning(case.ctor, case.msg, case.nvar)
  end
end

@test setdiff(union(names(ADNLPProblems), list_problems_not_ADNLPProblems), list_problems) ==
      [:ADNLPProblems]
@test setdiff(union(names(PureJuMP), list_problems_not_PureJuMP), list_problems) == [:PureJuMP]
