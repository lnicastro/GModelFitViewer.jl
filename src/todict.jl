const MDict = OrderedDict{Symbol, Any}

const todict_opt = Dict(
    :rebin => 1,
    :showallcomps => false,
    :showcomps => Vector{Symbol}()
)

rebin_data(rebin, v) = rebin_data(rebin, v, ones(eltype(v), length(v)))[1]
function rebin_data(rebin::Int, v, e)
    @assert length(v) == length(e)
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


function todict(id, pred::GFit.Prediction)
    out = MDict()
    out[:x] = rebin_data(todict_opt[:rebin], pred.domain[:])
    out[:components] = MDict()
    out[:compevals]  = MDict()
    for (cname, ceval) in pred.cevals
        out[:components][cname] = todict(cname, ceval.comp)
        out[:components][cname][:fixed] = (ceval.cfixed >= 1)
        out[:compevals][ cname] = todict(cname, ceval)
    end
    out[:reducers] = MDict()
    for (rname, reval) in pred.revals
        out[:reducers][rname] = todict(rname, reval)
        out[:reducers][rname][:default_visible] = (rname != pred.rsel)
    end
    out[:main_reducer] = pred.rsel
    out[:folded_model] = rebin_data(todict_opt[:rebin], pred.folded)

    out[:meta] = MDict()
    out[:meta][:rebin] = todict_opt[:rebin]
    out[:meta][:label] = "Prediction $id"
    out[:meta][:color] = "auto"
    out[:meta][:label_x] = ""
    out[:meta][:scale_x] =  1
    out[:meta][:unit_x]  = ""
    out[:meta][:label_y] = ""
    out[:meta][:scale_y] =  1
    out[:meta][:unit_y]  = ""

    return out
end


function todict(pred::GFit.Prediction, data::GFit.Measures{1})
    out = MDict()
    p = rebin_data(todict_opt[:rebin], GFit.geteval(pred))
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


function todict(param::GFit.BestFitPar)
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

function todict(res::GFit.BestFitResult)
    out = MDict()
    preds = [MDict(:components => MDict()) for id in 1:length(res.preds)]
    for id in 1:length(res.preds)
        for (cname, comp) in res.preds[id]
            preds[id][:components][cname] = todict(comp)
        end
    end
    out[:predictions] = preds
    out[:ndata] = res.ndata
    out[:dof] = res.dof
    out[:cost] = res.cost
    out[:status] = res.status
    out[:log10testprob] = res.log10testprob
    out[:elapsed] = res.elapsed
    return out
end

#=
function recursive_copy!(from::MDict, to::MDict)
    for (key, value) in from
        if haskey(to, key)
            @assert isa(value,   MDict)
            @assert isa(to[key], MDict)
            recursive_copy!(value, to[key])
        else
            haskey(to, :meta)  ||  (to[:meta] = MDict())
            to[:meta][key] = value
        end
    end
end
=#

todict(model::Model, data::T; kw...) where T <: GFit.AbstractData = todict(model, [data]; kw...)
todict(model::Model, data::T, bestfit::GFit.BestFitResult; kw...) where T <: GFit.AbstractData = todict(model, [data], bestfit; kw...)
function todict(model::Model,
                data::Union{Nothing, Vector{T}}=nothing,
                bestfit::Union{Nothing, GFit.BestFitResult}=nothing;
                rebin::Int=1, showcomps::Union{Bool, Vector{Symbol}}=false) where T <: GFit.AbstractData

    todict_opt[:rebin] = rebin
    todict_opt[:showallcomps] = (isa(showcomps, Bool)  &&  showcomps)
    todict_opt[:showcomps] = Vector{Symbol}()
    if !isa(showcomps, Bool)
        todict_opt[:showcomps] = showcomps
    end

    out = MDict()

    out[:predictions] = Vector{MDict}()
    for id in 1:length(model.preds)
        push!(out[:predictions], todict(id, model.preds[id]))
    end

    if !isnothing(data)
        out[:data] = Vector{MDict}()
        @assert length(model.preds) == length(data)
        for id in 1:length(data)
            push!(out[:data], todict(model.preds[id], data[id]))
        end
    end

    if !isnothing(bestfit)
        out[:bestfit] = todict(bestfit)
    end

    return out
end
