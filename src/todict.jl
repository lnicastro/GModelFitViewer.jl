const MDict = OrderedDict{Symbol, Any}

const todict_opt = Dict(
    :rebin => 1,
    :showallcomps => false,
    :showcomps => Vector{Symbol}()
)

rebin_data(rebin, v) = rebin_data(rebin, v, ones(eltype(v), length(v)))[1]
function rebin_data(rebin::Int, v, e)
    @assert length(v) == length(e)
    if length(v) == 1
        return (v, e)
    end
    @assert 1 <= rebin <= length(v)
    (rebin == 1)  &&  (return (v, e))
    nin = length(v)
    nout = div(nin, rebin)
    val = zeros(eltype(v), nout)
    unc = zeros(eltype(e), nout)
    w = 1 ./ (e.^2)
    for i in 1:nout-1
        r = (i-1)*rebin+1:i*rebin
        val[i] = sum(w[r] .* v[r]) ./ sum(w[r])
        unc[i] = sqrt(1 / sum(w[r]))
    end
    r = (nout-1)*rebin+1:nin
    val[nout] = sum(w[r] .* v[r]) ./ sum(w[r])
    unc[nout] = sqrt(1 / sum(w[r]))
    return (val, unc)
end

function todict(param::GFit.Parameter)
    out = MDict()
    out[:fixed] = param.fixed
    out[:value] = param.val
    out[:low] = param.low
    out[:high] = param.high
    out[:error] = !(param.low <= param.val <= param.high)
    out[:meta] = MDict()
    out[:meta][:unit] = 1
    out[:meta][:note] = ""
    return out
end

function todict(name::Symbol, comp::GFit.AbstractComponent)
    out = MDict()

    ctype = split(string(typeof(comp)), ".")
    (ctype[1] == "GFit")  &&   (ctype = ctype[2:end])
    ctype = join(ctype, ".")
    out[:type] = ctype

    out[:params] = MDict()
    for (pid, param) in GFit.getparams(comp)
        parname = pid.name
        if pid.index >= 1
            parname = Symbol(parname, "[", pid.index, "]")
        end
        out[:params][parname] = todict(param)
    end

    out[:meta] = MDict()
    out[:meta][:label] = string(name)
    out[:meta][:color] = "auto"
    out[:meta][:default_visible] = false
    out[:meta][:use_in_plot] = todict_opt[:showallcomps]  ||  (name in todict_opt[:showcomps])

    return out
end

function todict(name::Symbol, ceval::GFit.CompEval)
    y = ceval.buffer
    i = findall(isfinite.(y))

    out = MDict()
    out[:counter] = ceval.counter
    out[:min] = minimum(y[i])
    out[:max] = maximum(y[i])
    out[:mean] = mean(y[i])
    out[:error] = (length(i) == length(y))
    if todict_opt[:showallcomps]  ||  (name in todict_opt[:showcomps])
        out[:y] = rebin_data(todict_opt[:rebin], y)
    else
        out[:y] = Vector{Float64}()
    end
    return out
end

function todict(name::Symbol, reval::GFit.ReducerEval)
    y = reval.buffer
    i = findall(isfinite.(y))

    out = MDict()
    out[:counter] = reval.counter
    out[:min] = minimum(y[i])
    out[:max] = maximum(y[i])
    out[:mean] = mean(y[i])
    out[:error] = (length(i) == length(y))
    out[:y] = rebin_data(todict_opt[:rebin], y)

    out[:meta] = MDict()
    out[:meta][:label] = string(name)
    out[:meta][:color] = "auto"
    out[:meta][:default_visible] = true
    out[:meta][:use_in_plot] = true

    return out
end

function todict(id, model::GFit.Model)
    out = MDict()
    out[:x] = rebin_data(todict_opt[:rebin], model.domain[:])
    out[:components] = MDict()
    out[:compevals]  = MDict()
    for (cname, ceval) in model.cevals
        out[:components][cname] = todict(cname, ceval.comp)
        out[:components][cname][:fixed] = (ceval.cfixed >= 1)
        out[:compevals][ cname] = todict(cname, ceval)
    end
    out[:reducers] = MDict()
    for (rname, reval) in model.revals
        out[:reducers][rname] = todict(rname, reval)
        out[:reducers][rname][:meta][:default_visible] = (rname != model.rsel)
    end
    out[:main_reducer] = model.rsel
    out[:folded_model] = rebin_data(todict_opt[:rebin], model())

    out[:meta] = MDict()
    out[:meta][:rebin] = todict_opt[:rebin]
    out[:meta][:label] = "Model $id"
    out[:meta][:color] = "auto"
    out[:meta][:label_x] = ""
    out[:meta][:log10scale_x] = 0
    out[:meta][:unit_x]  = ""
    out[:meta][:label_y] = ""
    out[:meta][:log10scale_y] = 0
    out[:meta][:unit_y]  = ""

    return out
end

function todict(model::GFit.Model, data::GFit.Measures{1})
    out = MDict()
    p = rebin_data(todict_opt[:rebin], GFit.geteval(model))
    y, err = rebin_data(todict_opt[:rebin], data.val, data.unc)
    out[:meta] = MDict()
    out[:y] = y
    out[:err] = err
    out[:residuals] = (y .- p) ./ err

    out[:meta] = MDict()
    out[:meta][:label] = "Empirical data"
    out[:meta][:color] = "auto"
    out[:meta][:default_visible] = true
    out[:meta][:use_in_plot] = true

    return out
end

function todict(param::GFit.BestFitParam)
    out = MDict()
    out[:val] = param.val
    out[:unc] = param.unc
    out[:fixed] = param.fixed
    out[:patched] = param.patched
    return out
end

function todict(comp::GFit.BestFitComp)
    out = MDict()
    for (pname, params) in comp
        if isa(params, AbstractArray)
            for i in 1:length(params)
                out[Symbol(pname, "[", i, "]")] = todict(params[i])
            end
        else
            out[pname] = todict(params)
        end
    end
    return out
end

function todict(res::GFit.BestFitMultiResult)
    out = MDict()
    models = [MDict(:components => MDict()) for id in 1:length(res.models)]
    for id in 1:length(res.models)
        for (cname, comp) in res.models[id]
            models[id][:components][cname] = todict(comp)
        end
    end
    out[:models] = models
    out[:ndata] = res.mdc.ndata
    out[:dof] = res.mdc.dof
    out[:cost] = res.mdc.fitstat
    out[:status] = split(string(typeof(res.mzer)), "MinimizerStatus")[2]
    out[:log10testprob] = res.mdc.log10testprob
    out[:elapsed] = res.elapsed
    return out
end
