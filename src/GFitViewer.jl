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
            vv = rebin(dict["values"][1], nn)
            ee = rebin(dict["values"][2], nn)
            empty!(dict["values"])
            push!( dict["values"], vv)
            push!( dict["values"], ee)
        end
    end
end




prepare_dict(model::Model; kws...) = prepare_dict(GFit.ModelSnapshot(model); kws...)
function prepare_dict(model::GFit.ModelSnapshot; kws...)
    meta = Meta(; kws...)
    out = GFit._serialize([model])
    rebin!(out[1], meta.rebin)
    out[1]["meta"] = meta
    return out
end

function prepare_dict(model::GFit.ModelSnapshot, fitstats::GFit.FitStats, data::GFit.AbstractMeasures; kws...)
    meta = Meta(; kws...)
    out = GFit._serialize([model, fitstats, data])
    rebin!(out[1], meta.rebin)
    rebin!(out[3], meta.rebin)
    out[1]["meta"] = meta
    return out
end

prepare_dict(multi::Vector{Model}             ; kws...) = prepare_dict(GFit.ModelSnapshot(model), fill(Meta(; kws...), length(multi)))
prepare_dict(multi::Vector{GFit.ModelSnapshot}; kws...) = prepare_dict(multi                    , fill(Meta(; kws...), length(multi)))
prepare_dict(multi::Vector{Model}, meta::Vector{Meta})  = prepare_dict(GFit.ModelSnapshot.(multi), meta)
function prepare_dict(multi::Vector{GFit.ModelSnapshot}, meta::Vector{Meta})
    @assert length(multi) == length(multi)
    out = GFit._serialize([multi])
    for i in 1:length(multi)
        rebin!(out[1][i], meta[i].rebin)
        out[1][i]["meta"] = meta[i]
    end
    return out
end

prepare_dict(multi::Vector{GFit.ModelSnapshot}, fitstats::GFit.FitStats, data::Vector{T}; kws...) where T <: GFit.AbstractMeasures =
    prepare_dict(multi, fitstats, data, fill(Meta(; kws...), length(multi)))
function prepare_dict(multi::Vector{GFit.ModelSnapshot}, fitstats::GFit.FitStats, data::Vector{T}, meta::Vector{Meta}) where T <: GFit.AbstractMeasures
    @assert length(multi) == length(multi)
    out = GFit._serialize([multi, fitstats, data])
    for i in 1:length(multi)
        rebin!(out[1][i], meta[i].rebin)
        rebin!(out[3][i], meta[i].rebin)
        out[1][i]["meta"] = meta[i]
    end
    return out
end



function save_json(args...;
                   filename::Union{Nothing, AbstractString}=nothing,
                   kws...)
    dict = prepare_dict(args...; kws...)
    isnothing(filename)  &&  (filename = joinpath(tempdir(), "gfitviewer.json"))
    io = open(filename, "w")
    JSON.print(io, dict)
    close(io)
    return filename
end

function save_html(args...;
                   filename::Union{Nothing, AbstractString}=nothing,
                   offline=false,
                   kws...)
    dict = prepare_dict(args...; kws...)
    isnothing(filename)  &&  (filename = joinpath(tempdir(), "gfitviewer.html"))
    io = open(filename, "w")
    if offline
        template = joinpath(artifact"GFitViewer_artifact", "vieweroffline.html")
    else
        template = joinpath(artifact"GFitViewer_artifact", "vieweronline.html")
    end
    input = open(template)
    write(io, readuntil(input, "JSON_DATA"))
    JSON.print(io, dict)
    while !eof(input)
        write(io, readavailable(input))
    end
    close(io)
    return filename
end


function viewer(args...; kws...)
    filename = save_html(args...; kws...)
    DefaultApplication.open(filename)
end

include("gnuplot.jl")

end
