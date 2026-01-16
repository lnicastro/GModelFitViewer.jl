module GModelFitViewer

using JSON
using DefaultApplication, StructC14N, GModelFit, TypedJSON

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


import TypedJSON: lower
lower(v::TypedJSON.JSONType) = v  # Should this be implemented in TypedJSON?

function gmfv_lower(input::GModelFit.ModelSnapshot, meta::Meta)
    out = TypedJSON.lower(input)
    io = IOBuffer()
    ctx = IOContext(io, :color => true)
    show(ctx, input)
    out.dict[:show] = TypedJSON.JSONString(String(take!(io)))
    out.dict[:meta] = TypedJSON.JSONDict(meta)
    return out
end

function gmfv_lower(input::GModelFit.Solvers.FitSummary)
    out = TypedJSON.lower(input)
    io = IOBuffer()
    ctx = IOContext(io, :color => true)
    show(ctx, input)
    out.dict[:show] = TypedJSON.JSONString(String(take!(io)))
    return out
end

function gmfv_lower(bestfit::Vector{GModelFit.ModelSnapshot},
                    fsumm::GModelFit.Solvers.FitSummary,
                    data::Vector{D},
                    meta::Vector{Meta}) where {D <: GModelFit.Measures}
    @assert length(bestfit) == length(data) == length(meta)
    return TypedJSON.lower(Dict(:nepochs => length(bestfit),
                                :models => [gmfv_lower(bestfit[i], meta[i]) for i in 1:length(bestfit)],
                                :fitsummary => gmfv_lower(fsumm),
                                :data => data))
end

gmfv_lower(bestfit::GModelFit.ModelSnapshot,
           fsumm::GModelFit.Solvers.FitSummary,
           data::GModelFit.Measures{1},
           meta::Meta) =
               gmfv_lower([bestfit], fsumm, [data], [meta])

gmfv_lower(bestfit::GModelFit.ModelSnapshot,
           fsumm::GModelFit.Solvers.FitSummary,
           data::GModelFit.Measures{1};
           kws...) =
               gmfv_lower([bestfit], fsumm, [data], [Meta(; kws...)])



function serialize_html(filename::String, args...; kws...)
    ll = gmfv_lower(args...; kws...)

    input_html = open(joinpath(dirname(pathof(@__MODULE__)), "vieweronline.html"))
    input_js   = open(joinpath(dirname(pathof(@__MODULE__)), "vieweronline.js"))
    output     = open(filename, "w")
    write(output, readuntil(input_html, "JSON_DATA"))
    TypedJSON.serialize(output, ll)
    write(output, readuntil(input_html, "JS_CODE"))
    write(output, "var _version = '")
    write(output, string(pkgversion(GModelFitViewer)))
    write(output, "';\n")
    while !eof(input_js)
        write(output, readavailable(input_js))
    end
    while !eof(input_html)
        write(output, readavailable(input_html))
    end
    close(output)
          close(input_html)
    close(input_js)

    # TODO: comment the following lines
    output = open(replace(filename, ".html" => ".json"), "w")
    TypedJSON.serialize(output, ll)
    close(output)

    return filename
end


function viewer(args...; filename=joinpath(tempdir(), "gmodelfitviewer.html"), kws...)
    filename = serialize_html(filename, args...; kws...)
    DefaultApplication.open(filename)
end

end
