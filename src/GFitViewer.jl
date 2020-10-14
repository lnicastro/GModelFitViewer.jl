module GFitViewer

using DataStructures, JSON, DefaultApplication, GFit

export viewer

function add_default_meta!(model::Model)
    for i in 1:length(model.preds)
        meta = metadict(model, i)
        haskey(meta, :label)   ||  (meta[:label] = "Prediction $i")
        haskey(meta, :label_x) ||  (meta[:label_x] = "")
        haskey(meta, :scale_x) ||  (meta[:scale_x] =  1)
        haskey(meta, :unit_x ) ||  (meta[:unit_x]  = "")
        haskey(meta, :label_y) ||  (meta[:label_y] = "")
        haskey(meta, :scale_y) ||  (meta[:scale_y] =  1)
        haskey(meta, :unit_y ) ||  (meta[:unit_y]  = "")

        for (cname, comp) in model.comps
            meta = metadict(model, cname)
            haskey(meta, :label)    ||  (meta[:label] = string(cname))
            haskey(meta, :visible)  ||  (meta[:visible] = false)
            haskey(meta, :color)    ||  (meta[:color] = "auto")
            for (pname, param) in GFit.getparams(comp)
                meta = param.meta
                haskey(meta, :scale)   ||  (meta[:unit] =  1)
                haskey(meta, :unit )   ||  (meta[:unit] = "")
                haskey(meta, :note )   ||  (meta[:note] = "")
            end            
        end

        for pred in model.preds
            for (rname, reval) in pred.revals
                meta = metadict(model, rname)
                haskey(meta, :label)    ||  (meta[:label] = string(rname))
                haskey(meta, :visible)  ||  (meta[:visible] = true)
                haskey(meta, :color)    ||  (meta[:color] = "auto")
            end
        end
    end
end

function add_default_meta!(data::GFit.Measures_1D)
    haskey(data.meta, :label)    ||  (data.meta[:label] = "Empirical data")
    haskey(data.meta, :visible)  ||  (data.meta[:visible] = true)
    haskey(data.meta, :color)    ||  (data.meta[:color] = "auto")
end


viewer(model::Model, data::GFit.Measures_1D) = viewer(model, [data])
viewer(model::Model, data::GFit.Measures_1D, bestfit::GFit.BestFitResult) = viewer(model, [data], bestfit)


function save_html(path::AbstractString,
                   model::Model,
                   data::Union{Nothing, Vector{GFit.Measures_1D}}=nothing,
                   bestfit::Union{Nothing, GFit.BestFitResult}=nothing;
                   rebin=1)

    add_default_meta!(model)
    if !isnothing(data)
        for d in data
            add_default_meta!(d)
        end
    end

    if isnothing(data)
        d = GFit.todict(model, rebin=rebin)
    elseif isnothing(bestfit)
        d = GFit.todict(model, data, rebin=rebin)
    else
        d = GFit.todict(model, data, bestfit, rebin=rebin)
    end

    io = open(path, "w")

    template = dirname(@__DIR__) * "/src/viewer.html"
    input = open(template)
    write(io, readuntil(input, "JSON_DATA"))
    JSON.print(io, d)
    while !eof(input)
        write(io, readavailable(input))
    end
    close(io)

    # io = IOBuffer()
    # JSON.print(io, d)
    # return String(take!(io))

    return path
end

function viewer(args...; kw...)
    path = tempdir() * "/gfitviewer.html"
    save_html(path, args...; kw...)
    DefaultApplication.open(path)
end


end
