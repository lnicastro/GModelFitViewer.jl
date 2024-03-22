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


tobekept(name::String, bool::Bool) = bool
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


# The following structure contains vector(s) of dicts as a result of
# serializarion with GModelFit._serialize().  Its constructor allows
# to apply meta information provided via keywords to each dict.
struct ViewerData
    data::Vector

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


# Serialize to JSON
default_filename_json() = joinpath(tempdir(), "gmodelfitviewer.json")
serialize_json(args...;
               filename=default_filename_json(),
               kws...) =
                   serialize_json(ViewerData(args...; kws...),
                                  filename=filename)

function serialize_json(data::ViewerData;
                        filename=default_filename_json())
    io = open(filename, "w")
    JSON.print(io, data.data)
    close(io)
    return filename
end


# Serialize to HTML
default_filename_html() = joinpath(tempdir(), "gmodelfitviewer.html")
serialize_html(args...;
               filename=default_filename_html(),
               kws...) =
                   serialize_html(ViewerData(args...; kws...),
                                  filename=filename)

function serialize_html(data::ViewerData;
                        filename=default_filename_html())
    io = open(filename, "w")
    template = joinpath(dirname(pathof(@__MODULE__)), "vieweronline.html")
    input = open(template)
    write(io, readuntil(input, "JSON_DATA"))
    JSON.print(io, data.data)
    while !eof(input)
        write(io, readavailable(input))
    end
    close(io)
    return filename
end


# Viewer
function viewer(args...; kws...)
    filename = serialize_html(args...; kws...)
    DefaultApplication.open(filename)
end

function viewer(d::ViewerData)
    filename = serialize_html(d)
    DefaultApplication.open(filename)
end

function viewer(file_json_input::String; kws...)
    vv = GModelFit.deserialize(file_json_input)
    filename = serialize_html(vv...; kws...)
    DefaultApplication.open(filename)
end

end
