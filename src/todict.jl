const MDict = OrderedDict{Symbol, Any}

const todict_opt = MDict(
    :rebin => 1,
    :include => true
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
    out[:uncert] = param.unc
    out[:actual] = param.actual
    out[:patch] = ""
    isa(param.patch, Symbol)       &&  (out[:patch] = string(param.patch))
    isa(param.patch, GFit.λFunct)  &&  (out[:patch] = param.patch.display)
    isa(param.mpatch,GFit.λFunct)  &&  (out[:patch] = param.mpatch.display)
    out[:low] = param.low
    out[:high] = param.high
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
    for (pname, param) in GFit.getparams(comp)
        out[:params][pname] = todict(param)
    end

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
    out[:y] = rebin_data(todict_opt[:rebin], y)

    out[:meta] = MDict()
    out[:meta][:label] = string(name)
    out[:meta][:color] = "auto"
    out[:meta][:default_visible] = false
    out[:meta][:use_in_plot] = true

    return out
end

function todict(id, model::GFit.Model)
    out = MDict()
    out[:x] = rebin_data(todict_opt[:rebin], coords(model.domain))
    out[:components] = MDict()
    out[:compevals]  = MDict()
    for (cname, ceval) in model.cevals
        out[:components][cname] = todict(cname, ceval.comp)
        out[:components][cname][:fixed] = (ceval.cfixed >= 1)
        out[:compevals][cname] = todict(cname, ceval)
        if  (isa(todict_opt[:include], Bool)            &&  !(todict_opt[:include]))                               ||
            (isa(todict_opt[:include], Vector{Symbol})  &&  !(cname in todict_opt[:include]))                      ||
            (isa(todict_opt[:include], Function)        &&  !(todict_opt[:include](cname, typeof(ceval.comp))))
            out[:compevals][cname][:y] = []  # to avoid producing unnecessary large dictionaries
            out[:compevals][cname][:meta][:use_in_plot] = false
        end
    end
    out[:selected_reducer] = GFit.find_maincomp(model)

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
    m      = rebin_data(todict_opt[:rebin], model())
    x      = rebin_data(todict_opt[:rebin], coords(data.domain))
    y, err = rebin_data(todict_opt[:rebin], values(data), uncerts(data))
    out[:meta] = MDict()
    out[:x] = x
    out[:y] = y
    out[:err] = err
    out[:model] = m
    out[:residuals] = (y .- m) ./ err

    out[:meta] = MDict()
    out[:meta][:label] = "Empirical data"
    out[:meta][:color] = "auto"
    out[:meta][:default_visible] = true
    out[:meta][:use_in_plot] = true

    return out
end

function todict(fitres::GFit.FitResult)
    out = MDict()
    out[:ndata] = fitres.ndata
    out[:dof] = fitres.dof
    out[:cost] = fitres.fitstat
    out[:status] = split(string(typeof(fitres.status)), "MinimizerStatus")[2]
    out[:log10testprob] = NaN
    out[:elapsed] = fitres.elapsed
    return out
end
