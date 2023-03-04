module GFitViewer

using Pkg, Pkg.Artifacts
using JSON
using DefaultApplication, StructC14N, GFit

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
                rebin=Int)
    kw = canonicalize(template; kwargs...)

    return Meta((ismissing(kw.title)   ?  ""      :  kw.title),
                (ismissing(kw.xlabel)  ?  ""      :  kw.xlabel),
                (ismissing(kw.ylabel)  ?  ""      :  kw.ylabel),
                (ismissing(kw.xrange)  ?  nothing :  [kw.xrange...]),
                (ismissing(kw.yrange)  ?  nothing :  [kw.yrange...]),
                (ismissing(kw.xscale)  ?  1       :  kw.xscale),
                (ismissing(kw.yscale)  ?  1       :  kw.yscale),
                (ismissing(kw.xunit)   ?  ""      :  kw.xunit),
                (ismissing(kw.yunit)   ?  ""      :  kw.yunit),
                (ismissing(kw.xlog)    ?  false   :  kw.xlog),
                (ismissing(kw.ylog)    ?  false   :  kw.ylog),
                (ismissing(kw.rebin)   ?  1       :  kw.rebin))
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

function rebin!(dict::AbstractDict, nn::Int)
    (nn > 1)  ||  return
    if haskey(dict, "_structtype")
        if dict["_structtype"] == "GFit.ModelSnapshot"
            @assert dict["domain"]["_structtype"] == "Domain{1}"
            vv = rebin(dict["domain"]["axis"][1], nn)
            empty!(dict["domain"]["axis"])
            push!( dict["domain"]["axis"], vv)
            for (kk, vv) in dict["buffers"]
                dict["buffers"][kk] = rebin(vv, nn)
            end
        end
        if dict["_structtype"] == "Measures{1}"
            vv = rebin(dict["domain"]["axis"][1], nn)
            empty!(dict["domain"]["axis"])
            push!( dict["domain"]["axis"], vv)
            vv, ee = rebin(dict["values"][1], dict["values"][2], nn)
            empty!(dict["values"])
            push!( dict["values"], vv)
            push!( dict["values"], ee)
        end
    end
end



# Single model, using keywords for meta
allowed_serializable(model::Model; kws...) = allowed_serializable(GFit.ModelSnapshot(model); kws...)
function allowed_serializable(model::GFit.ModelSnapshot; kws...)
    meta = Meta(; kws...)
    out = [GFit.allowed_serializable(model)] # Output is always a vector to simplify JavaScript code
    rebin!(out[1], meta.rebin)
    out[1]["meta"] = meta
    return out
end

function allowed_serializable(model::GFit.ModelSnapshot, fitstats::GFit.FitStats; kws...)
    meta = Meta(; kws...)
    out = GFit.allowed_serializable(model, fitstats)
    rebin!(out[1], meta.rebin)
    out[1]["meta"] = meta
    return out
end

function allowed_serializable(model::GFit.ModelSnapshot, fitstats::GFit.FitStats, data::GFit.AbstractMeasures; kws...)
    meta = Meta(; kws...)
    out = GFit.allowed_serializable(model, fitstats, data)
    rebin!(out[1], meta.rebin)
    rebin!(out[3], meta.rebin)
    out[1]["meta"] = meta
    return out
end

# Multi model, using keywords for meta (to replicate for all models)
allowed_serializable(multi::Vector{Model}                                                       ; kws...)                                   = allowed_serializable(GFit.ModelSnapshot.(multi)               , fill(Meta(; kws...), length(multi)))
allowed_serializable(multi::Vector{GFit.ModelSnapshot}                                          ; kws...)                                   = allowed_serializable(multi                                    , fill(Meta(; kws...), length(multi)))
allowed_serializable(multi::Vector{GFit.ModelSnapshot}, fitstats::GFit.FitStats                 ; kws...)                                   = allowed_serializable(multi                     , fistats      , fill(Meta(; kws...), length(multi)))
allowed_serializable(multi::Vector{GFit.ModelSnapshot}, fitstats::GFit.FitStats, data::Vector{T}; kws...)  where T <: GFit.AbstractMeasures = allowed_serializable(multi                     , fistats, data, fill(Meta(; kws...), length(multi)))


# Multi model, using last argument for meta
function allowed_serializable(multi::Vector{Model},
                              meta::Vector{Meta})
    allowed_serializable(GFit.ModelSnapshot.(multi), meta)
end

function allowed_serializable(multi::Vector{GFit.ModelSnapshot}, meta::Vector{Meta})
    @assert length(multi) == length(meta)
    out = [GFit.allowed_serializable(multi)] # Output is always a vector to simplify JavaScript code
    for i in 1:length(multi)
        rebin!(out[1][i], meta[i].rebin)
        out[1][i]["meta"] = meta[i]
    end
    return out
end

function allowed_serializable(multi::Vector{GFit.ModelSnapshot}, fitstats::GFit.FitStats, meta::Vector{Meta})
    @assert length(multi) == length(meta)
    out = GFit.allowed_serializable(multi, fitstats)
    for i in 1:length(multi)
        rebin!(out[1][i], meta[i].rebin)
        out[1][i]["meta"] = meta[i]
    end
    return out
end

function allowed_serializable(multi::Vector{GFit.ModelSnapshot}, fitstats::GFit.FitStats, data::Vector{T}, meta::Vector{Meta}) where T <: GFit.AbstractMeasures
    @assert length(multi) == length(meta) == length(data)
    out = GFit.allowed_serializable(multi, fitstats, data)
    for i in 1:length(multi)
        rebin!(out[1][i], meta[i].rebin)
        rebin!(out[3][i], meta[i].rebin)
        out[1][i]["meta"] = meta[i]
    end
    return out
end

# Serialize to JSON
serialize_json(args...; kws...) =
    serialize_json(joinpath(tempdir(), "gfitviewer.json"), args...; kws...)

function serialize_json(filename::String, args...; kws...)
    data = allowed_serializable(args...; kws...)
    io = open(filename, "w")
    JSON.print(io, data)
    close(io)
    return filename
end

# Serialize to HTML
serialize_html(args...; kws...) =
    serialize_json(joinpath(tempdir(), "gfitviewer.html"), args...; kws...)

function serialize_html(filename::String, args...; offline=false, kws...)
    dict = allowed_serializable(args...; kws...)
    io = open(filename, "w")
    if offline
        template = joinpath(artifact"GFitViewer_artifact", "vieweroffline.html")
    else
        template = joinpath(artifact"GFitViewer_artifact", "vieweronline.html")
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

include("gnuplot.jl")

end
