module GModelFitViewer

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
                ylog=Bool)
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
                (ismissing(kw.ylog)    ?  false    :  kw.ylog))
end


function apply_meta!(dict::AbstractDict, meta::Meta)
    if haskey(dict, "_structtype")
        if dict["_structtype"] == "GModelFit.ModelSnapshot"
            @assert dict["domain"]["_structtype"] == "GModelFit.Domain"
            for (kk, vv) in dict["buffers"]
                dict["buffers"][kk] = vv
            end
            dict["meta"] = GModelFit._serialize_struct(meta)
        end
    end
end


# The following structure contains vector(s) of dicts as a result of
# serializarion with GModelFit._serialize().  Its constructor allows
# to apply meta information provided via keywords to each dict.
struct ViewerData
    data::Vector

    ViewerData(data::Vector) = new(data)

    function ViewerData(args...; meta=nothing, kws...)
        @assert any(isa.(args, GModelFit.ModelSnapshot)  .|  isa.(args, Vector{GModelFit.ModelSnapshot}))
        if isnothing(meta)
            meta = Meta(; kws...)
        end

        out = GModelFit._serialize(args...)
        if !isa(out, Vector)
            out = [out] # output must always be a vector to simplify JavaScript code
        elseif length(args) == 1
            # We have a vector with only one input arg: it means we are
            # in a multi-model case, hence we need to add a further vector
            # level
            out = [out]
        end

        # Apply meta to dicts
        for i in 1:length(out)
            if isa(out[i], Vector)
                for j in 1:length(out[i])
                    if isa(meta, Vector)
                        apply_meta!(out[i][j], meta[j])
                    else
                        apply_meta!(out[i][j], meta)
                    end
                end
            else
                if !isa(meta, Vector)
                    apply_meta!(out[i], meta)
                end
            end
        end
        return new(out)
    end
end


# Serialize to HTML
default_filename_html() = joinpath(tempdir(), "gmodelfitviewer.html")
serialize_html(args...;
               filename=default_filename_html(), json=false,
               kws...) =
                   serialize_html(ViewerData(args...; kws...),
                                  filename=filename, json=json)

function serialize_html(data::ViewerData;
                        filename=default_filename_html(), json=false)
    io = open(filename, "w")
    template = joinpath(dirname(pathof(@__MODULE__)), "vieweronline.html")
    input = open(template)
    write(io, readuntil(input, "JSON_DATA"))
    write(io, JSON.json(data.data, allownan=true))
    while !eof(input)
        write(io, readavailable(input))
    end
    close(io)
    close(input)

    if json
        io = open(joinpath(tempdir(), "gmodelfitviewer.json"), "w")
        write(io, JSON.json(data.data, allownan=true))
        close(io)
    end
    return filename
end


# Viewer
function viewer(args...; kws...)
    filename = serialize_html(args...; kws...)
    DefaultApplication.open(filename)
end

end
