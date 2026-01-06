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
                        out[i][j]["meta"] = GModelFit._serialize_struct(meta[j])
                    else
                        out[i][j]["meta"] = GModelFit._serialize_struct(meta)
                    end
                end
            else
                if !isa(meta, Vector)
                    out[i]["meta"] = GModelFit._serialize_struct(meta)
                end
            end
        end
        return new(out)
    end
end


# Serialize to HTML
default_filename_html() = joinpath(tempdir(), "gmodelfitviewer.html")

function serialize_html(bestfit::GModelFit.ModelSnapshot,
                        fsumm::GModelFit.Solvers.FitSummary,
                        data::GModelFit.Measures{1};
                        filename=default_filename_html(),
                        kws...)
    ll = TypedJSON.lower([[bestfit], fsumm, [data]])
    
    io = IOBuffer()
    ctx = IOContext(io, :color => true)
    show(ctx, bestfit)
    ll.value[1].value[1].dict[:show] = TypedJSON.JSONString(String(take!(io)))
    ll.value[1].value[1].dict[:meta] = TypedJSON.lower(Meta(; kws...))

    io = IOBuffer()
    ctx = IOContext(io, :color => true)
    show(ctx, fsumm)
    ll.value[2].dict[:show] = TypedJSON.JSONString(String(take!(io)))

    if true # TODO
        io = open("/tmp/gmodelfitviewer.json", "w")
        TypedJSON.serialize(io, ll)
        close(io)
    end

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

    return filename
end
    
# Viewer
function viewer(args...; kws...)
    filename = serialize_html(args...; kws...)
    DefaultApplication.open(filename)
end

end
