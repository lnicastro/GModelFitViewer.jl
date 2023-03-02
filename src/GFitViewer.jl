module GFitViewer

using Pkg, Pkg.Artifacts
using JSON

using DefaultApplication, StructC14N, GFit


struct Meta
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

export viewer



function prepare_dict(args;
                      meta::Union{Nothing, Meta, Vector{Meta}}=nothing,
                      kws...)

    function addmeta!(dict, meta)
        function isModelSnapshot(arg)
            if isa(arg, AbstractDict)
                if haskey(arg, "_structtype")
                    if arg["_structtype"] == "GFit.ModelSnapshot"
                        return true
                    end
                end
            end
            return false
        end

        function isVectorModelSnapshot(arg)
            if isa(arg, Vector)
                if all(isModelSnapshot.(arg))
                    return true
                end
            end
            return false
        end
        
        if isModelSnapshot(dict)
            @assert !isa(meta, Vector)
            dict["meta"] = meta
            return true
        elseif isVectorModelSnapshot(dict)
            if !isa(meta, Vector)
                for i in 1:length(dict)
                    dict[i]["meta"] = meta
                end
            else
                @assert length(dict) == length(meta)
                for i in 1:length(dict)
                    dict[i]["meta"] = meta[i]
                end
            end
        else
            if isa(dict, Vector)
                for i in 1:length(dict)
                    addmeta!(dict[i], meta)
                end
            end
        end
    end

    if isnothing(meta)
        meta = Meta(; kws...)
    end
    dict = GFit._serialize(args)
    addmeta!(dict, GFit._serialize_struct(meta))
    return dict
end


function save_html(args;
                   filename::Union{Nothing, AbstractString}=nothing,
                   offline=false,
                   kws...)

    dict = prepare_dict(args; kws...)
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
