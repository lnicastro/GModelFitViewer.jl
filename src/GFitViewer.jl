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
                xlog=Bool,
                ylog=Bool,
                rebin=Int)
    kw = canonicalize(template; kwargs...)

    return Meta((ismissing(kw.title)   ?  ""      :  kw.title),
                (ismissing(kw.xlabel)  ?  ""      :  kw.xlabel),
                (ismissing(kw.ylabel)  ?  ""      :  kw.ylabel),
                (ismissing(kw.xrange)  ?  nothing :  [kw.xrange...]),
                (ismissing(kw.yrange)  ?  nothing :  [kw.yrange...]),
                (ismissing(kw.xlog)    ?  false   :  kw.xlog),
                (ismissing(kw.ylog)    ?  false   :  kw.ylog),
                (ismissing(kw.rebin)   ?  1       :  kw.rebin))
end



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



function apply_meta!(arg::AbstractDict, meta::Meta)
    if haskey(arg, "_structtype")
        if arg["_structtype"] == "GFit.ModelSnapshot"
            arg["meta"] = GFit._serialize_struct(meta)
            @assert arg["domain"]["_structtype"] == "Domain{1}"
            if meta.rebin > 1
                vv = rebin_data(meta.rebin, arg["domain"]["axis"][1])
                empty!(arg["domain"]["axis"])
                push!( arg["domain"]["axis"], vv)
                for (kk, vv) in arg["buffers"]
                    arg["buffers"][kk] = rebin_data(meta.rebin, vv)
                end
            end
            return 1
        end
        if arg["_structtype"] == "Measures{1}"
            vv = rebin_data(meta.rebin, arg["values"][1])
            ee = rebin_data(meta.rebin, arg["values"][2])
            empty!(arg["values"])
            push!( arg["values"], vv)
            push!( arg["values"], ee)
        end
    end
    return 0
end

function apply_meta!(arg::AbstractVector, meta::Meta)
    cc = 0
    for i in 1:length(arg)
        cc += apply_meta!(arg[i], meta)
    end
    return cc
end

apply_meta!(arg::AbstractDict, meta::Vector{Meta}) = 0

function apply_meta!(arg::AbstractVector, meta::Vector{Meta})
    cc = 0
    for i in 1:length(arg)
        if length(arg) == length(meta)
            @info "AAA"
            cc += apply_meta!(arg[i], meta[i])
        else
            @info "BBB"
            cc += apply_meta!(arg[i], meta)
        end
    end
    return cc
end

function prepare_dict(args, meta=Vector{Meta}(); kws...)
    if length(meta) == 0
        meta = Meta(; kws...)
    end
    dict = GFit._serialize(args)
    @assert apply_meta!(dict, meta) > 0 "No ModelSnapshot found in argument(s)"
    return dict
end

function save_json(args, meta=Vector{Meta}();
                   filename::Union{Nothing, AbstractString}=nothing,
                   kws...)
    dict = prepare_dict(args, meta; kws...)
    isnothing(filename)  &&  (filename = joinpath(tempdir(), "gfitviewer.json"))
    io = open(filename, "w")
    JSON.print(io, dict)
    close(io)
    return filename
end

function save_html(args, meta=Vector{Meta}();
                   filename::Union{Nothing, AbstractString}=nothing,
                   offline=false,
                   kws...)
    dict = prepare_dict(args, meta; kws...)
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
