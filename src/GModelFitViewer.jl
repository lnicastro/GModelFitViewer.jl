module GModelFitViewer

using Pkg, Pkg.Artifacts
using JSON
using DefaultApplication, StructC14N, GModelFit

export viewer


mutable struct Meta
    title::String
    xlabel::String
    ylabel::String
    xrange::Union{Nothing, Vector{Float64}}
    yrange::Union{Nothing, Vector{Float64}}
    xscale::Float64
    yscale::Float64
    xunit::String
    yunit::String
    xlog::Bool
    ylog::Bool
    rebin::Int
    keep
    skip
end


function Meta(; kwargs...)
    template = (title=AbstractString,
                xlabel=AbstractString,
                ylabel=AbstractString,
                xrange=NTuple{2, Real},
                yrange=NTuple{2, Real},
                xscale=Real,
                yscale=Real,
                xunit=AbstractString,
                yunit=AbstractString,
                xlog=Bool,
                ylog=Bool,
                rebin=Int,
                keep=Any,
                skip=Any)
    kw = canonicalize(template; kwargs...)

    return Meta((ismissing(kw.title)   ?  ""       :  kw.title),
                (ismissing(kw.xlabel)  ?  ""       :  kw.xlabel),
                (ismissing(kw.ylabel)  ?  ""       :  kw.ylabel),
                (ismissing(kw.xrange)  ?  nothing  :  [kw.xrange...]),
                (ismissing(kw.yrange)  ?  nothing  :  [kw.yrange...]),
                (ismissing(kw.xscale)  ?  1        :  kw.xscale),
                (ismissing(kw.yscale)  ?  1        :  kw.yscale),
                (ismissing(kw.xunit)   ?  ""       :  kw.xunit),
                (ismissing(kw.yunit)   ?  ""       :  kw.yunit),
                (ismissing(kw.xlog)    ?  false    :  kw.xlog),
                (ismissing(kw.ylog)    ?  false    :  kw.ylog),
                (ismissing(kw.rebin)   ?  1        :  kw.rebin),
                (ismissing(kw.keep)    ?  nothing  :  kw.keep),
                (ismissing(kw.skip)    ?  nothing  :  kw.skip))
end



rebin(vv, nn) = rebin(vv, ones(eltype(vv), length(vv)), nn)[1]
function rebin(v, e, nn::Int)
    @assert length(v) == length(e)
    if length(v) == 1
        return (v, e)
    end
    @assert 1 <= nn <= length(v)
    (nn == 1)  &&  (return (v, e))
    nin = length(v)
    nout = div(nin, nn)
    val = zeros(eltype(v), nout)
    unc = zeros(eltype(e), nout)
    w = 1 ./ (e.^2)
    for i in 1:nout-1
        r = (i-1)*nn+1:i*nn
        val[i] = sum(w[r] .* v[r]) ./ sum(w[r])
        unc[i] = sqrt(1 / sum(w[r]))
    end
    r = (nout-1)*nn+1:nin
    val[nout] = sum(w[r] .* v[r]) ./ sum(w[r])
    unc[nout] = sqrt(1 / sum(w[r]))
    return (val, unc)
end


tobekept(name::String, pattern::String) = (name == pattern)
tobekept(name::String, pattern::Regex) = !isnothing(match(pattern, name))
tobekept(name::String, patterns::Vector) = any([tobekept(name, p) for p in patterns])

function tobekept(name::String, meta::Meta)
    keep = false
    if !isnothing(meta.keep)
        keep = tobekept(name, meta.keep)
    else
        keep = true
    end
    if keep  &&  !isnothing(meta.skip)
        keep = !tobekept(name, meta.skip)
    end
    return keep
end



function apply_meta!(dict::AbstractDict, meta::Meta)
    if haskey(dict, "_structtype")
        if dict["_structtype"] == "GModelFit.ModelSnapshot"
            @assert dict["domain"]["_structtype"] in ["Domain{1}", "GModelFit.Domain{1}"]
            vv = rebin(dict["domain"]["axis"][1], meta.rebin)
            empty!(dict["domain"]["axis"])
            push!( dict["domain"]["axis"], vv)
            for (kk, vv) in dict["buffers"]
                if tobekept(kk, meta)  ||  (("_TS_" * kk) == dict["maincomp"])
                    dict["buffers"][kk] = rebin(vv, meta.rebin)
                else
                    delete!(dict["buffers"], kk)
                end
            end
            meta.keep = nothing
            meta.skip = nothing
            dict["meta"] = GModelFit._serialize_struct(meta)
            haskey(dict["meta"], "keep")  &&  delete!(dict["meta"], "keep")
            haskey(dict["meta"], "skip")  &&  delete!(dict["meta"], "skip")
        end
        if dict["_structtype"] == "Measures{1}"
            vv = rebin(dict["domain"]["axis"][1], meta.rebin)
            empty!(dict["domain"]["axis"])
            push!( dict["domain"]["axis"], vv)
            vv, ee = rebin(dict["values"][1], dict["values"][2], meta.rebin)
            empty!(dict["values"])
            push!( dict["values"], vv)
            push!( dict["values"], ee)
        end
    end
end



# Single model, using keywords for meta
serialize_with_meta(model::Model; kws...) = serialize_with_meta(GModelFit.ModelSnapshot(model); kws...)
function serialize_with_meta(model::GModelFit.ModelSnapshot; kws...)
    meta = Meta(; kws...)
    out = [GModelFit._serialize(model)] # Output is always a vector to simplify JavaScript code
    apply_meta!(out[1], meta)
    return out
end

function serialize_with_meta(model::GModelFit.ModelSnapshot, fitstats::GModelFit.FitStats; kws...)
    meta = Meta(; kws...)
    out = GModelFit._serialize(model, fitstats)
    apply_meta!(out[1], meta)
    return out
end

function serialize_with_meta(model::GModelFit.ModelSnapshot, fitstats::GModelFit.FitStats, data::GModelFit.AbstractMeasures; kws...)
    meta = Meta(; kws...)
    out = GModelFit._serialize(model, fitstats, data)
    apply_meta!(out[1], meta)
    apply_meta!(out[3], meta)
    return out
end

# Multi model, using keywords for meta (to replicate for all models)
serialize_with_meta(multi::Vector{Model}                                                                 ; kws...)                                        = serialize_with_meta(GModelFit.ModelSnapshot.(multi)                , fill(Meta(; kws...), length(multi)))
serialize_with_meta(multi::Vector{GModelFit.ModelSnapshot}                                               ; kws...)                                        = serialize_with_meta(multi                                          , fill(Meta(; kws...), length(multi)))
serialize_with_meta(multi::Vector{GModelFit.ModelSnapshot}, fitstats::GModelFit.FitStats                 ; kws...)                                        = serialize_with_meta(multi                          , fitstats      , fill(Meta(; kws...), length(multi)))
serialize_with_meta(multi::Vector{GModelFit.ModelSnapshot}, fitstats::GModelFit.FitStats, data::Vector{T}; kws...)  where T <: GModelFit.AbstractMeasures = serialize_with_meta(multi                          , fitstats, data, fill(Meta(; kws...), length(multi)))


# Multi model, using last argument for meta
function serialize_with_meta(multi::Vector{Model},
                              meta::Vector{Meta})
    serialize_with_meta(GModelFit.ModelSnapshot.(multi), meta)
end

function serialize_with_meta(multi::Vector{GModelFit.ModelSnapshot}, meta::Vector{Meta})
    @assert length(multi) == length(meta)
    out = [GModelFit._serialize(multi)] # Output is always a vector to simplify JavaScript code
    for i in 1:length(multi)
        apply_meta!(out[1][i], meta[i])
    end
    return out
end

function serialize_with_meta(multi::Vector{GModelFit.ModelSnapshot}, fitstats::GModelFit.FitStats, meta::Vector{Meta})
    @assert length(multi) == length(meta)
    out = GModelFit._serialize(multi, fitstats)
    for i in 1:length(multi)
        apply_meta!(out[1][i], meta[i])
    end
    return out
end

function serialize_with_meta(multi::Vector{GModelFit.ModelSnapshot}, fitstats::GModelFit.FitStats, data::Vector{T}, meta::Vector{Meta}) where T <: GModelFit.AbstractMeasures
    @assert length(multi) == length(meta) == length(data)
    out = GModelFit._serialize(multi, fitstats, data)
    for i in 1:length(multi)
        apply_meta!(out[1][i], meta[i])
        apply_meta!(out[3][i], meta[i])
    end
    return out
end


# Serialize to JSON
serialize_json(args...; kws...) =
    serialize_json(joinpath(tempdir(), "gmodelfitviewer.json"), args...; kws...)

function serialize_json(filename::String, args...; kws...)
    data = serialize_with_meta(args...; kws...)
    io = open(filename, "w")
    JSON.print(io, data)
    close(io)
    return filename
end

# Serialize to HTML
serialize_html(args...; kws...) =
    serialize_html(joinpath(tempdir(), "gmodelfitviewer.html"), args...; kws...)

function serialize_html(filename::String, args...; offline=false, kws...)
    data = serialize_with_meta(args...; kws...)
    io = open(filename, "w")
    if offline
        template = joinpath(artifact"GModelFitViewer_artifact", "vieweroffline.html")
    else
        template = joinpath(artifact"GModelFitViewer_artifact", "vieweronline.html")
    end
    input = open(template)
    write(io, readuntil(input, "JSON_DATA"))
    JSON.print(io, data)
    while !eof(input)
        write(io, readavailable(input))
    end
    close(io)
    return filename
end



function viewer(args...; kws...)
    filename = serialize_html(args...; kws...)
    DefaultApplication.open(filename)
end

function viewer(file_json::String; kws...)
    vv = GModelFit.deserialize(file_json)
    filename = serialize_html(vv...; kws...)
    DefaultApplication.open(filename)
end

function viewer(dest::String, file_json::String; kws...)
    vv = GModelFit.deserialize(file_json)
    filename = serialize_html(dest, vv...; kws...)
    DefaultApplication.open(filename)
end

end
